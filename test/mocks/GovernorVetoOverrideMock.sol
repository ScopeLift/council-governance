// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

import {GovernorVetoOverride} from "src/extensions/GovernorVetoOverride.sol";

/**
 * @title GovernorVetoOverrideMock
 * @dev Mock implementation of GovernorVetoOverride for testing purposes.
 */
contract GovernorVetoOverrideMock is GovernorVetoOverride, GovernorVotes, GovernorCountingSimple {
  constructor(IERC5805 _daoToken, address _vetoOverrideRole, uint48 _vetoOverrideDuration)
    Governor("GovernorVetoOverrideMock")
    GovernorVotes(_daoToken)
    GovernorVetoOverride(_vetoOverrideRole, _vetoOverrideDuration)
  {}

  function votingDelay() public pure override returns (uint256) {
    return 1 hours;
  }

  function votingPeriod() public pure override returns (uint256) {
    return 1 days;
  }

  function quorum(uint256 /*timepoint*/ ) public pure override returns (uint256) {
    return 10_000e18;
  }

  function exposed_SetOverrideRole(address vetoOverrideRole) public {
    _setVetoOverrideRole(vetoOverrideRole);
  }

  function exposed_SetOverrideDuration(uint48 vetoOverrideDuration) public {
    _setVetoOverrideDuration(vetoOverrideDuration);
  }

  function state(uint256 proposalId)
    public
    view
    override(Governor, GovernorVetoOverride)
    returns (ProposalState)
  {
    return GovernorVetoOverride.state(proposalId);
  }
}
