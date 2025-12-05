// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @dev Interface for interacting with MarketAdminPermissionChecker
 * @dev Sourced from Compound Finance Comet protocol
 */
interface MarketAdminPermissionCheckerInterface {
  /// @notice Error which represents that the caller passed is not market admin
  error Unauthorized();

  /// @notice Error which represents that the caller passed is market admin, but market admin is
  /// paused and can't perform market updates
  error MarketAdminIsPaused();

  /**
   * @notice Checks if the caller can perform market updates or not.
   * Throws an error if the callerAddress is not same as market admin, or if the market admin is
   * paused
   * @param callerAddress The address of the caller
   */
  function checkUpdatePermission(address callerAddress) external view;
}

