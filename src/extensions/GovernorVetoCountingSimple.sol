// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Dependencies
import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";

/// @title GovernorVetoCountingSimple
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension of {Governor} that implements a simple "veto only" counting mode.
/// @dev Only veto votes are counted towards vetoThreshold. Other vote types will revert. Sourced
/// from OpenZeppelin's {GovernorCountingSimple} (last updated v5.4.0)
/// (contracts/governance/extensions/GovernorCountingSimple.sol) with behavior adapted for
/// veto-counting.
abstract contract GovernorVetoCountingSimple is Governor {
  /// @notice A struct to store the vote counts for a proposal
  struct ProposalVote {
    /// @notice The number of veto votes for the proposal
    uint256 vetoVotes;
    /// @notice Per-voter record whether they have cast a vote for this proposal.
    mapping(address voter => bool) hasVoted;
  }

  /// @notice Mapping of `proposalId` to its associated vote data (veto count and voter records).
  mapping(uint256 proposalId => ProposalVote) private proposalVoteData;

  /// @inheritdoc IGovernor
  /// @dev This extension uses a simple counting mode where only veto votes are counted towards
  /// veto threshold.
  /// solhint-disable-next-line func-name-mixedcase
  function COUNTING_MODE() public pure virtual override returns (string memory) {
    return "support=veto&quorum=veto";
  }

  /// @inheritdoc IGovernor
  /// @dev Reports whether `account` has already vetoed the `proposalId`
  function hasVoted(uint256 _proposalId, address _account)
    public
    view
    virtual
    override
    returns (bool)
  {
    return proposalVoteData[_proposalId].hasVoted[_account];
  }

  /// @notice Returns the number of veto votes for a given `proposalId`
  /// @param _proposalId The ID of the proposal to get the vote counts for
  /// @return vetoVotes The number of veto votes for the proposal
  function proposalVotes(uint256 _proposalId) public view virtual returns (uint256) {
    return proposalVoteData[_proposalId].vetoVotes;
  }

  /// @notice Returns the veto threshold for a given timepoint.
  /// @dev Must be implemented by inheriting contracts to define the veto threshold calculation.
  /// @param timepoint The timepoint at which to calculate the threshold (usually proposal
  /// snapshot). @return The number of veto votes required to defeat a proposal.
  function vetoThreshold(uint256 timepoint) public view virtual returns (uint256);

  /// @notice Returns 0 because optimistic proposals do not use quorum.
  /// @dev In veto counting, proposals succeed by default unless vetoed. The concept of quorum
  /// (minimum participation) does not apply. This override ensures OpenZeppelin's quorum checks
  /// always pass.
  function quorum(uint256) public view virtual override returns (uint256) {
    return 0;
  }

  /// @inheritdoc Governor
  /// @dev For optimistic proposals, this function treats proposals as being in quorum by
  /// default.
  function _quorumReached(
    uint256 /* _proposalId */
  )
    internal
    view
    virtual
    override
    returns (bool)
  {
    return true;
  }

  /// @dev Checks whether a proposal has been vetoed.
  /// @param _proposalId The id of the proposal to check.
  /// @return bool True if the proposal's `vetoVotes` >= vetoThreshold at the proposal snapshot.
  function _isVetoed(uint256 _proposalId) internal view returns (bool) {
    return (proposalVoteData[_proposalId].vetoVotes >= vetoThreshold(proposalSnapshot(_proposalId)));
  }

  /// @inheritdoc Governor
  function _voteSucceeded(uint256 _proposalId) internal view virtual override returns (bool) {
    return !(_isVetoed(_proposalId));
  }

  /// @inheritdoc Governor
  /// @dev This extension uses a simple counting mode where only veto votes are counted.
  function _countVote(
    uint256 _proposalId,
    address _account,
    uint8 _support,
    uint256 _totalWeight,
    bytes memory // params
  ) internal virtual override returns (uint256) {
    ProposalVote storage proposalVote = proposalVoteData[_proposalId];

    if (proposalVote.hasVoted[_account]) revert GovernorAlreadyCastVote(_account);
    proposalVote.hasVoted[_account] = true;

    if (_support == 0) proposalVote.vetoVotes += _totalWeight;
    else revert GovernorInvalidVoteType();

    return _totalWeight;
  }
}
