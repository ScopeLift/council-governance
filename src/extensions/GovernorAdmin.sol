// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {Ownable} from "@openzeppelin/contracts/Access/Ownable.sol";

/**
 * @title GovernorAdmin
 * @notice Extension of {Governor} that restricts privileged governance actions to a desginated
 * admin.
 * @dev Overrides `Governor-_checkGovernance` so that only the admin can perform
 * governance-restricted operations. This allows an external main DAO to control critical governance
 * parameters while preventing the council from manipulating these settings.
 */
abstract contract GovernorAdmin is Governor, Ownable {

  constructor(address _governorAdmin) Ownable(_governorAdmin) {}

  /// @dev Ensures the caller is the degisnated admin before executing governance-retricted logic.
  function _checkGovernance() internal virtual override {
    _checkOwner();
  }
}
