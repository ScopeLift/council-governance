// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Interfaces
import {ITimelock} from "src/interfaces/ITimelock.sol";

/// @title BaseBridgeReceiver
/// @author [ScopeLift](https://scopelift.co)
/// @dev Code sourced from
/// https://github.com/compound-finance/comet/blob/edca9128e526bbcbf36b71ccbb2e2e1d1d12de69/contracts/bridges/BaseBridgeReceiver.sol
/// Changes made:
///  - SPDX-License-Identifier updated from BUSL-1.1 to MIT
///  - Solidity version updated to 0.8.15 to 0.8.30
///  - Update natspec comments + implement best practices (run with scopelint check)
///  - Remove redundant else statements `function state()`
contract BaseBridgeReceiver {
  /*///////////////////////////////////////////////////////////////
                          Enums
  //////////////////////////////////////////////////////////////*/

  /// @notice Enum representing the state of a proposal
  enum ProposalState {
    Queued,
    Expired,
    Executed
  }

  /// @notice Struct representing a proposal
  struct Proposal {
    uint256 id;
    address[] targets;
    uint256[] values;
    string[] signatures;
    bytes[] calldatas;
    uint256 eta;
    bool executed;
  }

  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Error emitted when the contract is already initialized
  error AlreadyInitialized();

  /// @notice Error emitted when the data is bad
  error BadData();

  /// @notice Error emitted when the proposal id is invalid
  error InvalidProposalId();

  /// @notice Error emitted when the timelock admin is invalid
  error InvalidTimelockAdmin();

  /// @notice Error emitted when the proposal is not executable
  error ProposalNotExecutable();

  /// @notice Error emitted when the transaction is already queued
  error TransactionAlreadyQueued();

  /// @notice Error emitted when the caller is unauthorized
  error Unauthorized();

  /*///////////////////////////////////////////////////////////////
                          Events
  //////////////////////////////////////////////////////////////*/

  /// @notice Event emitted when the contract is initialized
  /// @param govTimelock Address of the governing contract that this contract
  /// will receive messages from (likely on another chain)
  /// @param localTimelock Address of the timelock contract that this contract
  /// will send messages to
  event Initialized(address indexed govTimelock, address indexed localTimelock);

  /// @notice Event emitted when a proposal is created
  /// @param rootMessageSender Address of the contract that sent the bridged message
  /// @param id Id of the proposal
  /// @param targets Targets of the proposal
  /// @param values Values of the proposal
  /// @param signatures Signatures of the proposal
  /// @param calldatas Calldatas of the proposal
  /// @param eta Eta of the proposal
  event ProposalCreated(
    address indexed rootMessageSender,
    uint256 id,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 eta
  );

  /// @notice Event emitted when a proposal is executed
  event ProposalExecuted(uint256 indexed id);

  /*///////////////////////////////////////////////////////////////
                          State Variables
  //////////////////////////////////////////////////////////////*/

  /// @notice Address of the governing contract that this bridge receiver expects to
  ///  receive messages from; likely an address from another chain (e.g. mainnet)
  address public govTimelock;

  /// @notice Address of the timelock on this chain that the bridge receiver
  /// will send messages to
  address public localTimelock;

  /// @notice Whether contract has been initialized
  bool public initialized;

  /// @notice Total count of proposals generated
  uint256 public proposalCount;

  /// @notice Mapping of proposal ids to their full proposal data
  mapping(uint256 => Proposal) public proposals;

  /*///////////////////////////////////////////////////////////////
                          External Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Initialize the contract
  /// @param _govTimelock Address of the governing contract that this contract
  /// will receive messages from (likely on another chain)
  /// @param _localTimelock Address of the timelock contract that this contract
  /// will send messages to
  function initialize(address _govTimelock, address _localTimelock) external {
    if (initialized) revert AlreadyInitialized();
    if (ITimelock(_localTimelock).admin() != address(this)) revert InvalidTimelockAdmin();
    govTimelock = _govTimelock;
    localTimelock = _localTimelock;
    initialized = true;
    emit Initialized(_govTimelock, _localTimelock);
  }

  /// @notice Execute a queued proposal
  /// @param _proposalId The id of the proposal to execute
  function executeProposal(uint256 _proposalId) external {
    if (state(_proposalId) != ProposalState.Queued) revert ProposalNotExecutable();
    Proposal storage proposal = proposals[_proposalId];
    proposal.executed = true;
    for (uint256 _i = 0; _i < proposal.targets.length; _i++) {
      ITimelock(localTimelock)
        .executeTransaction(
          proposal.targets[_i],
          proposal.values[_i],
          proposal.signatures[_i],
          proposal.calldatas[_i],
          proposal.eta
        );
    }
    emit ProposalExecuted(_proposalId);
  }

  /*///////////////////////////////////////////////////////////////
                          Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Process a message sent from the governing timelock (across a bridge)
  /// @param _rootMessageSender Address of the contract that sent the bridged message
  /// @param _data ABI-encoded bytes containing the transactions to be queued on the local timelock
  function processMessage(address _rootMessageSender, bytes calldata _data) internal {
    if (_rootMessageSender != govTimelock) revert Unauthorized();

    address[] memory _targets;
    uint256[] memory _values;
    string[] memory _signatures;
    bytes[] memory _calldatas;

    (_targets, _values, _signatures, _calldatas) =
      abi.decode(_data, (address[], uint256[], string[], bytes[]));

    if (_values.length != _targets.length) revert BadData();
    if (_signatures.length != _targets.length) revert BadData();
    if (_calldatas.length != _targets.length) revert BadData();

    uint256 _delay = ITimelock(localTimelock).delay();
    uint256 _eta = block.timestamp + _delay;

    for (uint256 _i = 0; _i < _targets.length; _i++) {
      bytes32 _txHash =
        keccak256(abi.encode(_targets[_i], _values[_i], _signatures[_i], _calldatas[_i], _eta));
      if (ITimelock(localTimelock).queuedTransactions(_txHash)) {
        revert TransactionAlreadyQueued();
      }

      ITimelock(localTimelock)
        .queueTransaction(_targets[_i], _values[_i], _signatures[_i], _calldatas[_i], _eta);
    }

    proposalCount++;
    Proposal memory _proposal = Proposal({
      id: proposalCount,
      targets: _targets,
      values: _values,
      signatures: _signatures,
      calldatas: _calldatas,
      eta: _eta,
      executed: false
    });

    proposals[_proposal.id] = _proposal;
    emit ProposalCreated(
      _rootMessageSender, _proposal.id, _targets, _values, _signatures, _calldatas, _eta
    );
  }

  /*///////////////////////////////////////////////////////////////
                          Public Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Get the state of a proposal
  /// @param _proposalId Id of the proposal
  /// @return The state of the given proposal (queued, expired or executed)
  function state(uint256 _proposalId) public view returns (ProposalState) {
    if (_proposalId > proposalCount || _proposalId == 0) revert InvalidProposalId();
    Proposal memory _proposal = proposals[_proposalId];

    if (_proposal.executed) return ProposalState.Executed;

    if (block.timestamp > (_proposal.eta + ITimelock(localTimelock).GRACE_PERIOD())) {
      return ProposalState.Expired;
    }

    return ProposalState.Queued;
  }
}
