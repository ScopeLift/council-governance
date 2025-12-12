// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IBridgePermissionChecker
/// @notice Interface for bridge permission checking logic
/// @dev Used by BaseBridgeReceiver for cross-chain messages and other contracts for same-chain
/// operations
interface IBridgePermissionChecker {
  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Error emitted when the data is bad
  error BadData();

  /// @notice Error emitted when a govTimelock is not authorized
  error GovTimelockNotAuthorized();

  /// @notice Error emitted when a function is not allowed for a govTimelock on a specific target
  error FunctionNotAllowed(address govTimelock, address target, bytes4 selector);

  /// @notice Error emitted when a target is not allowed for a govTimelock
  error TargetNotAllowed(address govTimelock, address target);

  /// @notice Error emitted when the caller is unauthorized
  error Unauthorized();

  /*///////////////////////////////////////////////////////////////
                          Events
  //////////////////////////////////////////////////////////////*/

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

  /*///////////////////////////////////////////////////////////////
                          Core Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Check if a sender is allowed to call a specific target/function
  /// @param _sender Address of the sender (govTimelock or msg.sender)
  /// @param _target Target address to check
  /// @param _selector Function selector (bytes4) to check
  /// @return true if allowed, reverts with specific error if not allowed
  /// @dev Checks authorization, unrestricted mode, and target/function whitelist
  function isAllowed(address _sender, address _target, bytes4 _selector)
    external
    view
    returns (bool);
}

