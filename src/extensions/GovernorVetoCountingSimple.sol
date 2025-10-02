// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.4.0) (governance/extensions/GovernorCountingSimple.sol)

pragma solidity ^0.8.30;

import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";

/**
 * @dev Extension of {Governor} for simple 1 vote option counting.
 */
abstract contract GovernorVetoCountingSimple is Governor {
  struct ProposalVote {
    uint256 vetoVotes;
    mapping(address voter => bool) hasVoted;
  }

  mapping(uint256 proposalId => ProposalVote) private _proposalVotes;

  /// @inheritdoc IGovernor
  // solhint-disable-next-line func-name-mixedcase
  function COUNTING_MODE() public pure virtual override returns (string memory) {
    return "support=veto&quorum=veto";
  }

  /// @inheritdoc IGovernor
  function hasVoted(uint256 proposalId, address account)
    public
    view
    virtual
    override
    returns (bool)
  {
    return _proposalVotes[proposalId].hasVoted[account];
  }

  /**
   * @dev Accessor to the internal vote counts.
   */
  function proposalVotes(uint256 proposalId) public view virtual returns (uint256 vetoVotes) {
    ProposalVote storage proposalVote = _proposalVotes[proposalId];
    return (proposalVote.vetoVotes);
  }

  /// @inheritdoc Governor
  function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    ProposalVote storage proposalVote = _proposalVotes[proposalId];

    // Inverse quorum
    // If veto votes are greater than or equal to the quorum, quorum is not reached
    return !(proposalVote.vetoVotes >= quorum(proposalSnapshot(proposalId)));
  }

  /**
   * @dev See {Governor-_voteSucceeded}. In this module, the forVotes must be strictly over the
   * againstVotes.
   */
  function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    return _quorumReached(proposalId);
  }

  /**
   * @dev See {Governor-_countVote}. In this module, the support follows the `VoteType` enum (from
   * Governor Bravo).
   */
  function _countVote(
    uint256 proposalId,
    address account,
    uint8 support,
    uint256 totalWeight,
    bytes memory // params
  ) internal virtual override returns (uint256) {
    ProposalVote storage proposalVote = _proposalVotes[proposalId];

    if (proposalVote.hasVoted[account]) revert GovernorAlreadyCastVote(account);
    proposalVote.hasVoted[account] = true;

    if (support == 0) proposalVote.vetoVotes += totalWeight;
    else revert GovernorInvalidVoteType();

    return totalWeight;
  }
}
