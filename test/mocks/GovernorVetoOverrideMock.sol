// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// External imports
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {
  GovernorCountingSimple
} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";

/// Internal imports
import {GovernorVetoOverride} from "src/extensions/GovernorVetoOverride.sol";

/// Test imports
import {MockERC20Votes} from "test/helpers/MockERC20Votes.sol";

/// @title GovernorVetoOverrideMock
/// @dev Mock implementation of GovernorVetoOverride for testing purposes.
contract GovernorVetoOverrideMock is GovernorVetoOverride, GovernorVotes {
  MockERC20Votes public daoToken;
  mapping(uint256 => bool) internal _defeated;

  constructor(address _vetoOverrideRole, uint48 _vetoOverrideDuration)
    Governor("GovernorVetoOverrideMock")
    GovernorVotes(daoToken = new MockERC20Votes())
    GovernorVetoOverride(_vetoOverrideRole, _vetoOverrideDuration)
  {}

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
    override
    returns (uint256)
  {
    return 10_000e18;
  }

  function COUNTING_MODE() external pure returns (string memory) {
    return "support=veto&quorum=veto";
  }

  function hasVoted(
    uint256, //proposalId
    address //account
  )
    public
    view
    virtual
    override
    returns (bool)
  {
    return false;
  }

  function _countVote(
    uint256, // proposalId
    address, // account
    uint8, // support
    uint256, // totalWeight
    bytes memory // params
  )
    internal
    virtual
    override
    returns (uint256)
  {
    return 0;
  }

  function setDefeated(uint256 proposalId, bool defeated) public {
    _defeated[proposalId] = defeated;
  }

  function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    return !_defeated[proposalId];
  }

  function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    return !_defeated[proposalId];
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
