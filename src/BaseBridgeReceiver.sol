// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "src/interfaces/ITimelock.sol";
import "src/interfaces/IBridgePermissionChecker.sol";

contract BaseBridgeReceiver {
  /**
   *
   */
  error AlreadyInitialized();
  error BadData();
  error InvalidProposalId();
  error InvalidTimelockAdmin();
  error ProposalNotExecutable();
  error TransactionAlreadyQueued();
  error Unauthorized();

  /**
   *
   */
  event Initialized(address indexed localTimelock, address indexed permissionChecker);
  event ProposalCreated(
    address indexed rootMessageSender,
    uint256 id,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 eta
  );
  event ProposalExecuted(uint256 indexed id);

  /**
   *
   */

  /// @notice Address of the timelock on this chain that the bridge receiver
  /// will send messages to
  address public localTimelock;

  /// @notice BridgePermissionChecker contract which is used to check if the caller has permission
  /// to process messages The permission checker handles authorization, unrestricted mode, and
  /// target/function whitelisting
  IBridgePermissionChecker public permissionChecker;

  /// @notice Whether contract has been initialized
  bool public initialized;

  /// @notice Total count of proposals generated
  uint256 public proposalCount;

  struct Proposal {
    uint256 id;
    address[] targets;
    uint256[] values;
    string[] signatures;
    bytes[] calldatas;
    uint256 eta;
    bool executed;
  }

  /// @notice Mapping of proposal ids to their full proposal data
  mapping(uint256 => Proposal) public proposals;

  enum ProposalState {
    Queued,
    Expired,
    Executed
  }

  /**
   * @notice Initialize the contract
   * @param _localTimelock Address of the timelock contract that this contract
   * will send messages to
   * @param _permissionChecker Address of the BridgePermissionChecker contract
   */
  function initialize(address _localTimelock, IBridgePermissionChecker _permissionChecker) external {
    if (initialized) revert AlreadyInitialized();
    if (ITimelock(_localTimelock).admin() != address(this)) revert InvalidTimelockAdmin();
    if (address(_permissionChecker) == address(0)) revert BadData();
    localTimelock = _localTimelock;
    permissionChecker = _permissionChecker;
    initialized = true;
    emit Initialized(_localTimelock, address(_permissionChecker));
  }

  /**
   * @notice Process a message sent from the governing timelock (across a bridge)
   * @param rootMessageSender Address of the contract that sent the bridged message
   * @param data ABI-encoded bytes containing the transactions to be queued on the local timelock
   */
  function processMessage(address rootMessageSender, bytes calldata data) internal {

    address[] memory targets;
    uint256[] memory values;
    string[] memory signatures;
    bytes[] memory calldatas;

    (targets, values, signatures, calldatas) =
      abi.decode(data, (address[], uint256[], string[], bytes[]));

    if (values.length != targets.length) revert BadData();
    if (signatures.length != targets.length) revert BadData();
    if (calldatas.length != targets.length) revert BadData();

    uint256 delay = ITimelock(localTimelock).delay();
    uint256 eta = block.timestamp + delay;

    for (uint256 i = 0; i < targets.length; i++) {
      // Check permissions via permission checker (handles authorization, unrestricted mode, and target/function whitelisting)
      bytes4 selector = bytes4(calldatas[i]);
      permissionChecker.isAllowed(rootMessageSender, targets[i], selector);

      if (ITimelock(localTimelock)
          .queuedTransactions(
            keccak256(abi.encode(targets[i], values[i], signatures[i], calldatas[i], eta))
          )) revert TransactionAlreadyQueued();
      ITimelock(localTimelock)
        .queueTransaction(targets[i], values[i], signatures[i], calldatas[i], eta);
    }

    proposalCount++;
    Proposal memory proposal = Proposal({
      id: proposalCount,
      targets: targets,
      values: values,
      signatures: signatures,
      calldatas: calldatas,
      eta: eta,
      executed: false
    });

    proposals[proposal.id] = proposal;
    emit ProposalCreated(
      rootMessageSender, proposal.id, targets, values, signatures, calldatas, eta
    );
  }

  /**
   * @notice Execute a queued proposal
   * @param proposalId The id of the proposal to execute
   */
  function executeProposal(uint256 proposalId) external {
    if (state(proposalId) != ProposalState.Queued) revert ProposalNotExecutable();
    Proposal storage proposal = proposals[proposalId];
    proposal.executed = true;
    for (uint256 i = 0; i < proposal.targets.length; i++) {
      ITimelock(localTimelock)
        .executeTransaction(
          proposal.targets[i],
          proposal.values[i],
          proposal.signatures[i],
          proposal.calldatas[i],
          proposal.eta
        );
    }
    emit ProposalExecuted(proposalId);
  }

  /**
   * @notice Get the state of a proposal
   * @param proposalId Id of the proposal
   * @return The state of the given proposal (queued, expired or executed)
   */
  function state(uint256 proposalId) public view returns (ProposalState) {
    if (proposalId > proposalCount || proposalId == 0) revert InvalidProposalId();
    Proposal memory proposal = proposals[proposalId];
    if (proposal.executed) {
      return ProposalState.Executed;
    } else if (block.timestamp > (proposal.eta + ITimelock(localTimelock).GRACE_PERIOD())) {
      return ProposalState.Expired;
    } else {
      return ProposalState.Queued;
    }
  }
}
