// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// External Dependencies
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";

/// Internal Dependencies
import {GovernorVetoOverride} from "src/extensions/GovernorVetoOverride.sol";

/// Test Dependencies
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

  /// @notice Test utility function that sets a given proposal to defeated.
  function setDefeated(uint256 proposalId, bool defeated) public {
    _defeated[proposalId] = defeated;
  }

  function exposed_setOverrideRole(address vetoOverrideRole) public {
    _setVetoOverrideRole(vetoOverrideRole);
  }

  function exposed_setOverrideDuration(uint48 vetoOverrideDuration) public {
    _setVetoOverrideDuration(vetoOverrideDuration);
  }

  function COUNTING_MODE() external pure returns (string memory) {
    return "support=veto&quorum=veto";
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
    override
    returns (uint256)
  {
    return 10_000e18;
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

  function state(uint256 proposalId)
    public
    view
    override(Governor, GovernorVetoOverride)
    returns (ProposalState)
  {
    return GovernorVetoOverride.state(proposalId);
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

  function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    return !_defeated[proposalId];
  }

  function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    return !_defeated[proposalId];
  }
}
