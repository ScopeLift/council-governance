// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Interfaces
import {IBridgePermissionChecker} from "src/interfaces/IBridgePermissionChecker.sol";
// External Libraries
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title BridgePermissionChecker
/// @author [ScopeLift](https://scopelift.co)
/// @notice Reusable permission checker for bridge operations and same-chain contracts
/// @dev Handles authorization, unrestricted mode, and target/function whitelisting
/// @dev Can be used by BaseBridgeReceiver (cross-chain) or other contracts (same-chain)
contract BridgePermissionChecker is IBridgePermissionChecker, Ownable {
  /*///////////////////////////////////////////////////////////////
                          State Variables
  //////////////////////////////////////////////////////////////*/

  /// @notice Mapping of authorized governing contracts
  /// @dev govTimelock => authorized
  mapping(address => bool) public authorizedGovTimelocks;

  /// @notice Mapping of unrestricted govTimelocks that can call any target/function
  /// @dev If unrestricted, bypasses all whitelist checks (target and function restrictions)
  /// @dev govTimelock => unrestricted
  mapping(address => bool) public unrestrictedGovTimelocks;

  /// @notice Mapping of allowed target addresses per govTimelock
  /// @dev If a target is whitelisted, all functions on that target are allowed
  /// @dev govTimelock => target address => allowed
  mapping(address => mapping(address => bool)) public allowedTargets;

  /// @notice Mapping of allowed function selectors per govTimelock and target
  /// @dev If a function is whitelisted for a target, it can be called even if the target itself is
  /// not whitelisted
  /// @dev govTimelock => target address => function selector => allowed
  mapping(address => mapping(address => mapping(bytes4 => bool))) public allowedFunctions;

  /*///////////////////////////////////////////////////////////////
                          Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Constructs the BridgePermissionChecker contract
  /// @param _admin Address of the admin (can manage permissions)
  constructor(address _admin) Ownable(_admin) {}

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
    override
    returns (bool)
  {
    // First check if sender is authorized
    if (!authorizedGovTimelocks[_sender]) revert Unauthorized();

    // If unrestricted, allow all targets/functions (early return for gas efficiency)
    if (unrestrictedGovTimelocks[_sender]) return true;

    // Check if target is whitelisted (allows all functions) OR
    // if this specific function on this target is whitelisted
    bool _targetAllowed = allowedTargets[_sender][_target];
    bool _functionAllowed = allowedFunctions[_sender][_target][_selector];

    if (!_targetAllowed && !_functionAllowed) revert TargetNotAllowed(_sender, _target);

    return true;
  }

  /*///////////////////////////////////////////////////////////////
                          Admin Functions
  //////////////////////////////////////////////////////////////*/

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
  /// target)
  /// @param _govTimelock Address of the governing contract
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
}

