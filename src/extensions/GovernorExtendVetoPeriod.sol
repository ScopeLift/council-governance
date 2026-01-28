// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Dependencies
import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

/// @title GovernorExtendVetoPeriod
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension of {Governor} that extends a proposal's voting period when a minor threshold
/// of veto votes is reached, giving token holders more time to participate.
/// @dev Heavily borrowed from OpenZeppelin's {GovernorPreventLateQuorum} (last updated v5.4.0)
/// (contracts/governance/extensions/GovernorPreventLateQuorum.sol) with behavior adapted for
/// veto-counting.
abstract contract GovernorExtendVetoPeriod is Governor {
  using Checkpoints for Checkpoints.Trace208;

  /// @notice Emitted when a proposal deadline is pushed back due to reaching its minor veto
  /// threshold.
  event ProposalExtended(uint256 indexed proposalId, uint256 extendedDeadline);

  /// @notice Emitted when the {_votingPeriodExtension} parameter is changed.
  event VotingPeriodExtensionSet(
    uint256 oldVotingPeriodExtension, uint256 newVotingPeriodExtension
  );

  /// @notice Emitted when the {_votingPeriodExtensionThresholdPct} parameter is changed.
  event MinorVetoExtensionThresholdPctSet(
    uint256 oldVotingPeriodExtensionThresholdPct, uint256 newVotingPeriodExtensionThresholdPct
  );

  /// @dev Reverts when a minor veto extension threshold exceeds the percent denominator.
  /// @param minorVetoExtensionThresholdPct The invalid threshold supplied, as percentage points.
  error GovernorExtendVetoPeriod_InvalidThreshold(uint16 minorVetoExtensionThresholdPct);

  /// @dev The extra time (seconds or blocks, depending on the governor clock mode) that may be
  /// added when the minor veto threshold is met.
  Checkpoints.Trace208 private _votingPeriodExtension;

  /// @dev The minor threshold in percentage points of veto threshold required to trigger an
  /// extension.
  Checkpoints.Trace208 private _minorVetoExtensionThresholdPct;

  /// @dev Mapping of proposal ID to extended deadline.
  mapping(uint256 proposalId => uint48) private _extendedDeadlines;

  /// @dev Initializes the voting period extension parameters.
  /// @param _initialVoteExtension Minimum time (seconds or blocks, depending on clock mode) from
  /// threshold trigger until the proposal deadline. The deadline is extended only if this exceeds
  /// the original deadline.
  /// @param _initialVotingPeriodExtensionThresholdPct Threshold in percentage points of the veto
  /// threshold required to trigger an extension.
  constructor(uint48 _initialVoteExtension, uint16 _initialVotingPeriodExtensionThresholdPct) {
    _setVotingPeriodExtension(_initialVoteExtension);
    _setMinorVetoExtensionThresholdPct(_initialVotingPeriodExtensionThresholdPct);
  }

  /// @inheritdoc IGovernor
  function proposalDeadline(uint256 _proposalId) public view virtual override returns (uint256) {
    return Math.max(super.proposalDeadline(_proposalId), _extendedDeadlines[_proposalId]);
  }

  /// @notice Returns the latest voting period extension duration.
  function votingPeriodExtension() public view virtual returns (uint256) {
    return _votingPeriodExtension.latest();
  }

  /// @notice Returns the voting period extension duration at a specific timepoint.
  /// @dev Use {proposalSnapshot} for snapshot-based semantics.
  function votingPeriodExtension(uint256 _timepoint) public view virtual returns (uint256) {
    return _optimisticUpperLookupRecent(_votingPeriodExtension, _timepoint);
  }

  /// @notice Returns the latest minor veto threshold percentage.
  function minorVetoExtensionThresholdPct() public view virtual returns (uint256) {
    return _minorVetoExtensionThresholdPct.latest();
  }

  /// @notice Returns the minor veto threshold percentage at a specific timepoint.
  /// @dev Use {proposalSnapshot} for snapshot-based semantics.
  function minorVetoExtensionThresholdPct(uint256 _timepoint)
    public
    view
    virtual
    returns (uint256)
  {
    return _optimisticUpperLookupRecent(_minorVetoExtensionThresholdPct, _timepoint);
  }

  /// @dev Returns the minor veto extension threshold denominator. Defaults to 100, but may be
  /// overridden.
  function minorVetoExtensionThresholdDenominator() public view virtual returns (uint256) {
    return 100;
  }

  /// @notice Returns the veto votes against a proposal.
  function proposalVotes(uint256 _proposalId) public view virtual returns (uint256 _againstVotes);

  /// @notice Returns the veto threshold for a proposal.
  function vetoThreshold(uint256 _proposalId) public view virtual returns (uint256 _vetoThreshold);

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

  /// @notice Updates the minor veto threshold (in percentage points of veto threshold) that
  /// triggers an extension. Callable only by governance. Emits a
  /// {MinorVetoExtensionThresholdPctSet} event.
  /// @param _newMinorVetoExtensionThresholdPct Threshold in percentage points of veto threshold.
  /// Must be less than or equal to `minorVetoExtensionThresholdDenominator`.
  function setMinorVetoExtensionThresholdPct(uint16 _newMinorVetoExtensionThresholdPct)
    public
    virtual
    onlyGovernance
  {
    _setMinorVetoExtensionThresholdPct(_newMinorVetoExtensionThresholdPct);
  }

  /// @dev Returns true when the current votes meet or exceed the extension threshold.
  /// @param _proposalId The ID of the proposal to check if voting period extension threshold is
  /// triggered.
  function _votingPeriodExtensionThresholdTriggered(uint256 _proposalId)
    internal
    view
    virtual
    returns (bool)
  {
    uint256 _proposalSnapshot = proposalSnapshot(_proposalId);

    uint16 _minorThresholdPct = SafeCast.toUint16(minorVetoExtensionThresholdPct(_proposalSnapshot));
    if (_minorThresholdPct == 0) return false;
    uint256 _minorThreshold = Math.mulDiv(
      vetoThreshold(_proposalSnapshot), _minorThresholdPct, minorVetoExtensionThresholdDenominator()
    );

    return proposalVotes(_proposalId) >= _minorThreshold;
  }

  /// @dev Vote tally updated and detects if it caused the minor veto threshold to be reached,
  /// potentially extending the voting period. Emits a {ProposalExtended} event when the extended
  /// deadline is greater than the original proposal deadline.
  /// @param _proposalId The ID of the proposal to check if voting period extension threshold is
  /// triggered.
  function _tallyUpdated(uint256 _proposalId) internal virtual override {
    super._tallyUpdated(_proposalId);
    if (
      _extendedDeadlines[_proposalId] == 0 && _votingPeriodExtensionThresholdTriggered(_proposalId)
    ) {
      // Lock in the first extension decision even if it does not lengthen the deadline so later
      // tallies cannot attempt to extend the same proposal again.
      uint48 extendedDeadline =
        clock() + SafeCast.toUint48(votingPeriodExtension(proposalSnapshot(_proposalId)));

      if (extendedDeadline > proposalDeadline(_proposalId)) {
        emit ProposalExtended(_proposalId, extendedDeadline);
      }

      _extendedDeadlines[_proposalId] = extendedDeadline;
    }
  }

  /// @dev Internal setter for {_votingPeriodExtension}. Emits a {VotingPeriodExtensionSet}
  /// event.
  /// @param _newVotingPeriodExtension Duration to extend when triggered.
  function _setVotingPeriodExtension(uint48 _newVotingPeriodExtension) internal virtual {
    (uint208 oldValue, uint208 newValue) =
      _votingPeriodExtension.push(clock(), SafeCast.toUint208(_newVotingPeriodExtension));
    emit VotingPeriodExtensionSet(oldValue, newValue);
  }

  /// @dev Internal setter for {_minorVetoExtensionThresholdPct}. Emits a
  /// {MinorVetoExtensionThresholdPctSet} event. Setting this value to 0 effectively turns off the
  /// extension module.
  /// @param _newMinorVetoExtensionThresholdPct Threshold in percentage points of
  /// veto threshold. Must be less than or equal to `minorVetoExtensionThresholdDenominator`.
  function _setMinorVetoExtensionThresholdPct(uint16 _newMinorVetoExtensionThresholdPct)
    internal
    virtual
  {
    if (_newMinorVetoExtensionThresholdPct > minorVetoExtensionThresholdDenominator()) {
      revert GovernorExtendVetoPeriod_InvalidThreshold(_newMinorVetoExtensionThresholdPct);
    }
    (uint208 oldValue, uint208 newValue) = _minorVetoExtensionThresholdPct.push(
      clock(), SafeCast.toUint208(_newMinorVetoExtensionThresholdPct)
    );
    emit MinorVetoExtensionThresholdPctSet(oldValue, newValue);
  }

  /**
   * @dev Returns the numerator at a specific timepoint.
   */
  function _optimisticUpperLookupRecent(Checkpoints.Trace208 storage ckpts, uint256 timepoint)
    internal
    view
    virtual
    returns (uint256)
  {
    // If trace is empty, key and value are both equal to 0.
    // In that case `key <= timepoint` is true, and it is ok to return 0.
    (, uint48 key, uint208 value) = ckpts.latestCheckpoint();
    return key <= timepoint ? value : ckpts.upperLookupRecent(SafeCast.toUint48(timepoint));
  }
}
