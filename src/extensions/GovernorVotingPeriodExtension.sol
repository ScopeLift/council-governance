// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

/// External Dependencies
import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title GovernorVotingPeriodExtension
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension of {Governor} that extends a proposal's voting period when a threshold of
/// votes is reached late in the window, giving token holders more time to participate.
abstract contract GovernorVotingPeriodExtension is Governor {
  uint256 public constant BPS_DENOMINATOR = 10_000;

  /// @notice Emitted when a proposal deadline is pushed back due to reaching quorum late in its
  /// voting period.
  event ProposalExtended(uint256 indexed proposalId, uint64 extendedDeadline);

  /// @notice Emitted when the {_votingPeriodExtension} parameter is changed.
  event VotingPeriodExtensionSet(uint64 oldVotingPeriodExtension, uint64 newVotingPeriodExtension);

  /// @notice Emitted when the {_votingPeriodExtensionThreshold} parameter is changed.
  event VotingPeriodExtensionThresholdSet(
    uint16 oldVotingPeriodExtensionThreshold, uint16 newVotingPeriodExtensionThreshold
  );

  /// @notice Reverts when a voting period extension threshold exceeds the BPS denominator.
  /// @param votingPeriodExtensionThreshold The invalid threshold supplied, in basis points.
  error GovernorVotingPeriodExtension_InvalidThreshold(uint16 votingPeriodExtensionThreshold);

  uint48 private _votingPeriodExtension;
  uint16 private _votingPeriodExtensionThreshold;

  mapping(uint256 proposalId => uint48) private _extendedDeadlines;

  /// @notice Initializes the vote extension parameter: the extra time (seconds or blocks, depending
  /// on the governor clock mode) added when the extension threshold is met near the end of voting.
  /// @param _initialVoteExtension Duration to extend when triggered.
  /// @param _initialVotingPeriodExtensionThreshold Threshold in bps of quorum required to trigger.
  constructor(uint48 _initialVoteExtension, uint16 _initialVotingPeriodExtensionThreshold) {
    _setVotingPeriodExtension(_initialVoteExtension);
    _setVotingPeriodExtensionThreshold(_initialVotingPeriodExtensionThreshold);
  }

  /// @inheritdoc IGovernor
  function proposalDeadline(uint256 _proposalId) public view virtual override returns (uint256) {
    return Math.max(super.proposalDeadline(_proposalId), _extendedDeadlines[_proposalId]);
  }

  /// @notice Returns the current vote extension duration applied when the threshold is triggered.
  function votingPeriodExtension() public view virtual returns (uint48) {
    return _votingPeriodExtension;
  }

  /// @notice Returns the threshold expressed in basis points of quorum that must be reached to
  /// extend the voting period.
  function votingPeriodExtensionThreshold() public view virtual returns (uint16) {
    return _votingPeriodExtensionThreshold;
  }

  function proposalVotes(uint256 _proposalId) public view virtual returns (uint256 _againstVotes);

  /// @notice Updates the voting period extension duration. Callable only by governance. Emits a
  /// {VotingPeriodExtensionSet} event.
  /// @param _newVoteExtensionFraction Duration to extend when the threshold is triggered.
  function setVotingPeriodExtension(uint48 _newVoteExtensionFraction)
    public
    virtual
    onlyGovernance
  {
    _setVotingPeriodExtension(_newVoteExtensionFraction);
  }

  /// @notice Updates the vote threshold (in basis points of quorum) that triggers an extension.
  /// Callable only by governance. Emits a {VotingPeriodExtensionThresholdSet} event.
  /// @param _newVotingPeriodExtensionThreshold Threshold in bps of quorum. Must be less than or
  /// equal to BPS_DENOMINATOR.
  function setVotingPeriodExtensionThreshold(uint16 _newVotingPeriodExtensionThreshold)
    public
    virtual
    onlyGovernance
  {
    _setVotingPeriodExtensionThreshold(_newVotingPeriodExtensionThreshold);
  }

  /// @notice Returns true when the current votes meet or exceed the extension threshold.
  /// @param _proposalId The ID of the proposal to check if voting period extension threshold is
  /// triggered.
  function _votingPeriodExtensionThresholdTriggered(uint256 _proposalId)
    internal
    view
    virtual
    returns (bool)
  {
    if (_votingPeriodExtensionThreshold == 0) return false;

    uint256 _juniorThreshold = Math.mulDiv(
      quorum(proposalSnapshot(_proposalId)), _votingPeriodExtensionThreshold, BPS_DENOMINATOR
    );
    return proposalVotes(_proposalId) >= _juniorThreshold;
  }

  /// @notice Vote tally updated and detects if it caused quorum to be reached, potentially
  /// extending the voting period. Emits a {ProposalExtended} event when the extended deadline is
  /// greater than the original proposal deadline.
  /// @param _proposalId The ID of the proposal to check if voting period extension threshold is
  /// triggered.
  function _tallyUpdated(uint256 _proposalId) internal virtual override {
    super._tallyUpdated(_proposalId);
    if (
      _extendedDeadlines[_proposalId] == 0 && _votingPeriodExtensionThresholdTriggered(_proposalId)
    ) {
      // Lock in the first extension decision even if it does not lengthen the deadline so later
      // tallies cannot attempt to extend the same proposal again.
      uint48 extendedDeadline = clock() + votingPeriodExtension();

      if (extendedDeadline > proposalDeadline(_proposalId)) {
        emit ProposalExtended(_proposalId, extendedDeadline);
      }

      _extendedDeadlines[_proposalId] = extendedDeadline;
    }
  }

  /// @notice Internal setter for {_votingPeriodExtension}. Emits a {VotingPeriodExtensionSet}
  /// event.
  /// @param _newVotingPeriodExtension Duration to extend when triggered.
  function _setVotingPeriodExtension(uint48 _newVotingPeriodExtension) internal virtual {
    emit VotingPeriodExtensionSet(_votingPeriodExtension, _newVotingPeriodExtension);

    _votingPeriodExtension = _newVotingPeriodExtension;
  }

  /// @notice Internal setter for {_votingPeriodExtensionThreshold}. Emits a
  /// {VotingPeriodExtensionThresholdSet} event.
  /// @dev Setting this value to 0 effectively turns off the extension module.
  /// @param _newVotingPeriodExtensionThreshold Threshold in bps of quorum. Must be less than or
  /// equal to BPS_DENOMINATOR.
  function _setVotingPeriodExtensionThreshold(uint16 _newVotingPeriodExtensionThreshold)
    internal
    virtual
  {
    if (_newVotingPeriodExtensionThreshold > 10_000) {
      revert GovernorVotingPeriodExtension_InvalidThreshold(_newVotingPeriodExtensionThreshold);
    }
    emit VotingPeriodExtensionThresholdSet(
      _votingPeriodExtensionThreshold, _newVotingPeriodExtensionThreshold
    );
    _votingPeriodExtensionThreshold = _newVotingPeriodExtensionThreshold;
  }
}
