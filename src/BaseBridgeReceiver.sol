// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Interfaces
import {ITimelock} from "src/interfaces/ITimelock.sol";
// External Libraries
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title BaseBridgeReceiver
/// @author [ScopeLift](https://scopelift.co)
/// @dev Code sourced from
/// https://github.com/compound-finance/comet/blob/edca9128e526bbcbf36b71ccbb2e2e1d1d12de69/contracts/bridges/BaseBridgeReceiver.sol
/// Changes made:
///  - SPDX-License-Identifier updated from BUSL-1.1 to MIT
///  - Solidity version updated to 0.8.15 to 0.8.30
///  - Update natspec comments + implement best practices (run with scopelint check)
///  - Remove redundant else statements `function state()`
///  - Support multiple govTimelocks with per-governor target/function restrictions
///  - Add unrestricted mode for trusted govTimelocks (bypasses whitelist checks)
///  - Initialize function now accepts separate arrays for unrestricted and restricted govTimelocks
///  - New Storage variables:
///    - unrestrictedGovTimelocks mapping(address => bool) public unrestrictedGovTimelocks;
///    - restrictedGovTimelocks mapping(address => bool) public restrictedGovTimelocks;
///    - allowedTargets mapping(address => mapping(address => bool)) public allowedTargets;
///    - allowedFunctions mapping(address => mapping(address => mapping(bytes4 => bool))) public allowedFunctions;
///  - New functions: 
///    - authorizeGovTimelock()
///    - unauthorizeGovTimelock()
///    - allowTarget()
///    - disallowTarget()
///    - allowFunction()
///    - disallowFunction()
///    - setUnrestricted()
///    - setRestricted()
///    for managing unrestricted and restricted govTimelocks
///  - New events: 
///    - GovTimelockAuthorized()
///    - GovTimelockUnauthorized()
///    - FunctionAllowed()
///    - FunctionDisallowed()
///    - TargetAllowed()
///    - TargetDisallowed()
///    - GovTimelockUnrestricted()
///    - GovTimelockRestricted()
///  - Updated event: 
///    - Initialized() now includes separate arrays for unrestricted and restricted govTimelocks
contract BaseBridgeReceiver is Ownable {
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

  /// @notice Error emitted when a govTimelock is not authorized
  error GovTimelockNotAuthorized();

  /// @notice Error emitted when a function is not allowed for a govTimelock on a specific target
  error FunctionNotAllowed(address govTimelock, address target, bytes4 selector);

  /// @notice Error emitted when a target is not allowed for a govTimelock
  error TargetNotAllowed(address govTimelock, address target);

  /*///////////////////////////////////////////////////////////////
                          Events
  //////////////////////////////////////////////////////////////*/

  /// @notice Event emitted when the contract is initialized
  /// @param unrestrictedGovTimelocks Addresses of the unrestricted governing contracts that this
  /// contract will receive messages from (likely on another chain)
  /// @param restrictedGovTimelocks Addresses of the restricted governing contracts that this
  /// contract will receive messages from (likely on another chain)
  /// @param localTimelock Address of the timelock contract that this contract
  /// will send messages to
  event Initialized(
    address[] unrestrictedGovTimelocks,
    address[] restrictedGovTimelocks,
    address indexed localTimelock
  );

  /// @notice Event emitted when a govTimelock is authorized
  event GovTimelockAuthorized(address indexed govTimelock);

  /// @notice Event emitted when a govTimelock is unauthorized
  event GovTimelockUnauthorized(address indexed govTimelock);

  /// @notice Event emitted when a function is allowed for a govTimelock on a specific target
  event FunctionAllowed(
    address indexed govTimelock, address indexed target, bytes4 indexed selector
  );

  /// @notice Event emitted when a function is disallowed for a govTimelock on a specific target
  event FunctionDisallowed(
    address indexed govTimelock, address indexed target, bytes4 indexed selector
  );

  /// @notice Event emitted when a target is allowed for a govTimelock
  event TargetAllowed(address indexed govTimelock, address indexed target);

  /// @notice Event emitted when a target is disallowed for a govTimelock
  event TargetDisallowed(address indexed govTimelock, address indexed target);

  /// @notice Event emitted when a govTimelock is set to unrestricted mode
  event GovTimelockUnrestricted(address indexed govTimelock);

  /// @notice Event emitted when a govTimelock is set to restricted mode
  event GovTimelockRestricted(address indexed govTimelock);

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

  /// @notice Mapping of authorized governing contracts that this bridge receiver expects to
  ///  receive messages from; likely addresses from another chain (e.g. mainnet)
  mapping(address => bool) public authorizedGovTimelocks;

  /// @notice Mapping of allowed target addresses per govTimelock
  /// @dev If a target is whitelisted, all functions on that target are allowed
  /// @dev govTimelock => target address => allowed
  mapping(address => mapping(address => bool)) public allowedTargets;

  /// @notice Mapping of allowed function selectors per govTimelock and target
  /// @dev If a function is whitelisted for a target, it can be called even if the target itself is
  /// not whitelisted @dev govTimelock => target address => function selector => allowed
  mapping(address => mapping(address => mapping(bytes4 => bool))) public allowedFunctions;

  /// @notice Mapping of unrestricted govTimelocks that can call any target/function
  /// @dev If unrestricted, bypasses all whitelist checks (target and function restrictions)
  /// @dev govTimelock => unrestricted
  mapping(address => bool) public unrestrictedGovTimelocks;

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
                          Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Constructs the BaseBridgeReceiver contract
  /// @param _owner Address of the contract owner (can manage permissions)
  constructor(address _owner) Ownable(_owner) {}

  /*///////////////////////////////////////////////////////////////
                          External Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Initialize the contract
  /// @param _unrestrictedGovTimelocks Addresses of the unrestricted governing contracts that this
  /// contract will receive messages from (likely on another chain)
  /// @param _restrictedGovTimelocks Addresses of the restricted governing contracts that this
  /// contract will receive messages from (likely on another chain)
  /// @param _localTimelock Address of the timelock contract that this contract
  /// will send messages to
  function initialize(
    address[] memory _unrestrictedGovTimelocks,
    address[] memory _restrictedGovTimelocks,
    address _localTimelock
  ) external onlyOwner {
    if (initialized) revert AlreadyInitialized();
    if (_unrestrictedGovTimelocks.length == 0 && _restrictedGovTimelocks.length == 0) {
      revert BadData();
    }
    if (ITimelock(_localTimelock).admin() != address(this)) revert InvalidTimelockAdmin();

    // Authorize and set unrestricted mode for all provided unrestricted govTimelocks
    for (uint256 _i = 0; _i < _unrestrictedGovTimelocks.length; _i++) {
      address _govTimelock = _unrestrictedGovTimelocks[_i];
      authorizedGovTimelocks[_govTimelock] = true;
      unrestrictedGovTimelocks[_govTimelock] = true;
      emit GovTimelockAuthorized(_govTimelock);
      emit GovTimelockUnrestricted(_govTimelock);
    }

    // Authorize all provided restricted govTimelocks
    for (uint256 _i = 0; _i < _restrictedGovTimelocks.length; _i++) {
      authorizedGovTimelocks[_restrictedGovTimelocks[_i]] = true;
      emit GovTimelockAuthorized(_restrictedGovTimelocks[_i]);
    }

    localTimelock = _localTimelock;
    initialized = true;
    emit Initialized(_unrestrictedGovTimelocks, _restrictedGovTimelocks, _localTimelock);
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

  /// @notice Authorize a new govTimelock address
  /// @param _govTimelock Address of the governing contract to authorize
  function authorizeGovTimelock(address _govTimelock) external onlyOwner {
    if (_govTimelock == address(0)) revert BadData();
    authorizedGovTimelocks[_govTimelock] = true;
    emit GovTimelockAuthorized(_govTimelock);
  }

  /// @notice Unauthorize a govTimelock address
  /// @param _govTimelock Address of the governing contract to unauthorize
  function unauthorizeGovTimelock(address _govTimelock) external onlyOwner {
    if (!authorizedGovTimelocks[_govTimelock]) revert GovTimelockNotAuthorized();
    authorizedGovTimelocks[_govTimelock] = false;
    emit GovTimelockUnauthorized(_govTimelock);
  }

  /// @notice Allow a target address for a specific govTimelock (allows all functions on that
  /// target) @param _govTimelock Address of the governing contract
  /// @param _target Target address to allow
  function allowTarget(address _govTimelock, address _target) external onlyOwner {
    if (!authorizedGovTimelocks[_govTimelock]) revert GovTimelockNotAuthorized();
    if (_target == address(0)) revert BadData();
    allowedTargets[_govTimelock][_target] = true;
    emit TargetAllowed(_govTimelock, _target);
  }

  /// @notice Disallow a target address for a specific govTimelock
  /// @param _govTimelock Address of the governing contract
  /// @param _target Target address to disallow
  function disallowTarget(address _govTimelock, address _target) external onlyOwner {
    if (!authorizedGovTimelocks[_govTimelock]) revert GovTimelockNotAuthorized();
    allowedTargets[_govTimelock][_target] = false;
    emit TargetDisallowed(_govTimelock, _target);
  }

  /// @notice Allow a function selector for a specific govTimelock on a specific target
  /// @param _govTimelock Address of the governing contract
  /// @param _target Target address where the function can be called
  /// @param _selector Function selector (bytes4) to allow
  /// @dev If target is whitelisted, all functions are allowed. This allows specific functions on
  /// non-whitelisted targets.
  function allowFunction(address _govTimelock, address _target, bytes4 _selector)
    external
    onlyOwner
  {
    if (!authorizedGovTimelocks[_govTimelock]) revert GovTimelockNotAuthorized();
    if (_target == address(0)) revert BadData();
    allowedFunctions[_govTimelock][_target][_selector] = true;
    emit FunctionAllowed(_govTimelock, _target, _selector);
  }

  /// @notice Disallow a function selector for a specific govTimelock on a specific target
  /// @param _govTimelock Address of the governing contract
  /// @param _target Target address where the function can be called
  /// @param _selector Function selector (bytes4) to disallow
  function disallowFunction(address _govTimelock, address _target, bytes4 _selector)
    external
    onlyOwner
  {
    if (!authorizedGovTimelocks[_govTimelock]) revert GovTimelockNotAuthorized();
    allowedFunctions[_govTimelock][_target][_selector] = false;
    emit FunctionDisallowed(_govTimelock, _target, _selector);
  }

  /// @notice Set a govTimelock to unrestricted mode (can call any target/function)
  /// @param _govTimelock Address of the governing contract to set as unrestricted
  /// @dev When unrestricted, the govTimelock bypasses all whitelist checks
  function setUnrestricted(address _govTimelock) external onlyOwner {
    if (!authorizedGovTimelocks[_govTimelock]) revert GovTimelockNotAuthorized();
    unrestrictedGovTimelocks[_govTimelock] = true;
    emit GovTimelockUnrestricted(_govTimelock);
  }

  /// @notice Set a govTimelock to restricted mode (subject to whitelist checks)
  /// @param _govTimelock Address of the governing contract to set as restricted
  /// @dev When restricted, the govTimelock must have targets/functions whitelisted
  function setRestricted(address _govTimelock) external onlyOwner {
    if (!authorizedGovTimelocks[_govTimelock]) revert GovTimelockNotAuthorized();
    unrestrictedGovTimelocks[_govTimelock] = false;
    emit GovTimelockRestricted(_govTimelock);
  }

  /*///////////////////////////////////////////////////////////////
                          Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Process a message sent from the governing timelock (across a bridge)
  /// @param _rootMessageSender Address of the contract that sent the bridged message
  /// @param _data ABI-encoded bytes containing the transactions to be queued on the local timelock
  function processMessage(address _rootMessageSender, bytes calldata _data) internal {
    if (!authorizedGovTimelocks[_rootMessageSender]) revert Unauthorized();

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

    // Validate each transaction against restrictions
    // If govTimelock is unrestricted, skip all whitelist checks
    bool _isUnrestricted = unrestrictedGovTimelocks[_rootMessageSender];

    for (uint256 _i = 0; _i < _targets.length; _i++) {
      address _target = _targets[_i];

      // If unrestricted, skip whitelist validation
      if (!_isUnrestricted) {
        // Extract function selector from calldata (first 4 bytes)
        bytes4 _selector = bytes4(_calldatas[_i]);

        // Check if target is whitelisted (allows all functions) OR
        // if this specific function on this target is whitelisted
        bool _targetAllowed = allowedTargets[_rootMessageSender][_target];
        bool _functionAllowed = allowedFunctions[_rootMessageSender][_target][_selector];

        if (!_targetAllowed && !_functionAllowed) {
          // If target is not whitelisted and function is not whitelisted, reject
          revert TargetNotAllowed(_rootMessageSender, _target);
        }
      }

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
