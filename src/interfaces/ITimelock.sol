// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ITimelock
/// @notice Interface for interacting with a Timelock used by the BaseReceiver contract
/// @dev This code is sourced from
/// https://github.com/compound-finance/comet/blob/edca9128e526bbcbf36b71ccbb2e2e1d1d12de69/contracts/ITimelock.sol
/// Changes made:
///  - SPDX-License-Identifier updated from BUSL-1.1 to MIT
///  - Solidity version updated to 0.8.15 to 0.8.30
interface ITimelock {
  /// @notice Event emitted when a pending admin accepts admin position
  event NewAdmin(address indexed newAdmin);

  /// @notice Event emitted when new pending admin is set by the timelock
  event NewPendingAdmin(address indexed newPendingAdmin);

  /// @notice Event emitted when Timelock sets new delay value
  event NewDelay(uint256 indexed newDelay);

  /// @notice Event emitted when admin cancels an enqueued transaction
  event CancelTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );

  /// @notice Event emitted when admin executes an enqueued transaction
  event ExecuteTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );

  /// @notice Event emitted when admin enqueues a transaction
  event QueueTransaction(
    bytes32 indexed txHash,
    address indexed target,
    uint256 value,
    string signature,
    bytes data,
    uint256 eta
  );

  /// @notice The length of time, once the delay has passed, in which a transaction can be executed
  /// before it becomes stale
  function GRACE_PERIOD() external view virtual returns (uint256);

  /// @notice The minimum value that the `delay` variable can be set to
  function MINIMUM_DELAY() external view virtual returns (uint256);

  /// @notice The maximum value that the `delay` variable can be set to
  function MAXIMUM_DELAY() external view virtual returns (uint256);

  /// @notice Address that has admin privileges
  function admin() external view virtual returns (address);

  /// @notice The address that may become the new admin by calling `acceptAdmin()`
  function pendingAdmin() external view virtual returns (address);

  /**
   * @notice Set the pending admin
   * @param _pendingAdmin New pending admin address
   */
  function setPendingAdmin(address _pendingAdmin) external virtual;

  /**
   * @notice Accept the position of admin (if caller is the current pendingAdmin)
   */
  function acceptAdmin() external virtual;

  /// @notice Duration that a transaction must be queued before it can be executed
  function delay() external view virtual returns (uint256);

  /**
   * @notice Set the delay value
   * @param _delay New delay value
   */
  function setDelay(uint256 _delay) external virtual;

  /// @notice Mapping of transaction hashes to whether that transaction is currently enqueued
  /// @param _txHash The hash of the transaction
  function queuedTransactions(bytes32 _txHash) external virtual returns (bool);

  /**
   * @notice Enque a transaction
   * @param _target Address that the transaction is targeted at
   * @param _value Value to send to target address
   * @param _signature Function signature to call on target address
   * @param _data Calldata for function called on target address
   * @param _eta Timestamp of when the transaction can be executed
   * @return txHash of the enqueued transaction
   */
  function queueTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external virtual returns (bytes32);

  /**
   * @notice Cancel an enqueued transaction
   * @param _target Address that the transaction is targeted at
   * @param _value Value of the transaction to cancel
   * @param _signature Function signature of the transaction to cancel
   * @param _data Calldata for the transaction to cancel
   * @param _eta Timestamp of the transaction to cancel
   */
  function cancelTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external virtual;

  /**
   * @notice Execute an enqueued transaction
   * @param _target Target address of the transaction to execute
   * @param _value Value of the transaction to execute
   * @param _signature Function signature of the transaction to execute
   * @param _data Calldata for the transaction to execute
   * @param _eta Timestamp of the transaction to execute
   * @return bytes returned from executing transaction
   */
  function executeTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external payable virtual returns (bytes memory);
}
