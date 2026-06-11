// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// External Dependencies
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {
  GovernorCountingSimple
} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

/// Internal Dependencies
import {
  GovernorVetoCountingSimple,
  GovernorVetoOverride
} from "src/extensions/GovernorVetoOverride.sol";

/// Test Dependencies
import {MockERC20Votes} from "test/helpers/MockERC20Votes.sol";

/// @title GovernorVetoOverrideMock
/// @dev Mock implementation of GovernorVetoOverride for testing purposes.
contract GovernorVetoOverrideMock is GovernorVetoOverride, GovernorVotes {
  MockERC20Votes public daoToken;
  mapping(uint256 => uint256) internal _proposalEtas;

  constructor(address _vetoOverrideRole, uint48 _vetoOverrideDuration)
    Governor("GovernorVetoOverrideMock")
    GovernorVotes(daoToken = new MockERC20Votes())
    GovernorVetoOverride(_vetoOverrideRole, _vetoOverrideDuration)
  {}

  function exposed_setOverrideRole(address vetoOverrideRole) public {
    _setVetoOverrideRole(vetoOverrideRole);
  }

  function exposed_setOverrideDuration(uint48 vetoOverrideDuration) public {
    _setVetoOverrideDuration(vetoOverrideDuration);
  }

  function votingDelay() public pure override returns (uint256) {
    return 1 hours;
  }

  function votingPeriod() public pure override returns (uint256) {
    return 1 days;
  }

  function quorum(
    uint256 /*timepoint*/
  )
    public
    pure
    override(Governor, GovernorVetoCountingSimple)
    returns (uint256)
  {
    return 0;
  }

  function state(uint256 proposalId)
    public
    view
    override(Governor, GovernorVetoOverride)
    returns (ProposalState)
  {
    return GovernorVetoOverride.state(proposalId);
  }

  function _queueOperations(
    uint256 proposalId, /*proposalId*/
    address[] memory, /*targets*/
    uint256[] memory, /*values*/
    bytes[] memory, /*calldatas*/
    bytes32 /*descriptionHash*/
  ) internal virtual override returns (uint48 eta) {
    eta = uint48(block.timestamp);
    _proposalEtas[proposalId] = eta;
    return eta;
  }

  function proposalEta(uint256 proposalId) public view override returns (uint256) {
    return _proposalEtas[proposalId];
  }

  function vetoThreshold(uint256) public view virtual override returns (uint256) {
    return 10_000e18;
  }
}
