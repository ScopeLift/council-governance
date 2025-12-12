// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";

/// @title GovernorVetoCountingSimple
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension of {Governor} that implements a simple "veto only" counting mode.
/// @dev Only veto votes are counted towards quorum. Other vote types are ignored. Sourced from
/// OpenZeppelin's {GovernorCountingSimple} (last updated v5.4.0)
/// (contracts/governance/extensions/GovernorCountingSimple.sol) with behavior adapted for
/// veto-counting.
abstract contract GovernorVetoCountingSimple is Governor {
  /*///////////////////////////////////////////////////////////////
                          Structs
  //////////////////////////////////////////////////////////////*/

  /// @notice A struct to store the vote counts for a proposal
  struct ProposalVote {
    /// @notice The number of veto votes for the proposal
    uint256 vetoVotes;
    /// @notice Per-voter record whether they have cast a vote for this proposal.
    mapping(address voter => bool) hasVoted;
  }

  /*///////////////////////////////////////////////////////////////
                          State Variables
  //////////////////////////////////////////////////////////////*/

  /// @notice Mapping of `proposalId` to its associated vote data (veto count and voter records).
  mapping(uint256 proposalId => ProposalVote) private proposalVoteData;

  /*///////////////////////////////////////////////////////////////
                        External / Public Functions
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc IGovernor
  /// @dev This extension uses a simple counting mode where only veto votes are counted towards
  /// quorum.
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

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc Governor
  /// @dev For council-sourced proposals this function treats proposals as being in quorum by
  /// default. If the veto threshold is reached, quorum is considered not reached.
  function _quorumReached(uint256 _proposalId) internal view virtual override returns (bool) {
    return true;
  }

  /// @notice Checks whether a proposal has been vetoed.
  /// @param _proposalId The id of the proposal to check.
  /// @return bool True if the proposal's `vetoVotes` >= quorum at the proposal snapshot.
  /// @dev `quorum(proposalSnapshot(proposalId))` uses the same quorum rule as the parent Governor.
  function _isVetoed(uint256 _proposalId) internal view returns (bool) {
    return (proposalVoteData[_proposalId].vetoVotes >= quorum(proposalSnapshot(_proposalId)));
  }

  /// @inheritdoc Governor
  function _voteSucceeded(uint256 _proposalId) internal view virtual override returns (bool) {
    return !(_isVetoed(_proposalId));
  }

  /// @inheritdoc Governor
  /// @dev This extension uses a simple counting mode where only veto votes are counted towards
  /// quorum.
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
