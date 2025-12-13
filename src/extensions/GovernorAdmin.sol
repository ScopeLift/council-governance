// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

// External Dependencies
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title GovernorAdmin
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension of {Governor} that relocates privileged governance actions from this governor
/// to an external admin.
/// @dev Overrides `Governor-_checkGovernance` to enable admin control while restricting governor
/// power. This is used in council governance to pass critical governance parameter control from the
/// council governors to some external admin (e.g. DAO timelock).
abstract contract GovernorAdmin is Governor, Ownable {
  constructor(address _governorAdmin) Ownable(_governorAdmin) {}

  /// @dev Ensures the caller is the designated admin before executing governance-restricted logic.
  function _checkGovernance() internal virtual override {
    _checkOwner();
  }
}
