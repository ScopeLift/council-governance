// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Dependencies
import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title GovernorExtendVetoPeriod
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension of {Governor} that extends a proposal's voting period when a minor threshold
/// of veto votes is reached, giving token holders more time to participate.
/// @dev Heavily borrowed from OpenZeppelin's {GovernorPreventLateQuorum} (last updated v5.4.0)
/// (contracts/governance/extensions/GovernorPreventLateQuorum.sol) with behavior adapted for
/// veto-counting.
abstract contract GovernorExtendVetoPeriod is Governor {
  /// @notice Emitted when a proposal deadline is pushed back due to reaching its minor veto
  /// threshold.
  event ProposalExtended(uint256 indexed proposalId, uint64 extendedDeadline);

  /// @notice Emitted when the {_votingPeriodExtension} parameter is changed.
  event VotingPeriodExtensionSet(uint64 oldVotingPeriodExtension, uint64 newVotingPeriodExtension);

  /// @notice Emitted when the {_votingPeriodExtensionThresholdPct} parameter is changed.
  event MinorVetoExtensionThresholdPctSet(
    uint16 oldVotingPeriodExtensionThresholdPct, uint16 newVotingPeriodExtensionThresholdPct
  );

  /// @dev Reverts when a minor veto extension threshold exceeds the percent denominator.
  /// @param minorVetoExtensionThresholdPct The invalid threshold supplied, as percentage points.
  error GovernorExtendVetoPeriod_InvalidThreshold(uint16 minorVetoExtensionThresholdPct);

  /// @dev The extra time (seconds or blocks, depending on the governor clock mode) that may be
  /// added when the minor veto threshold is met.
  uint48 private _votingPeriodExtension;

  /// @dev The minor threshold in percentage points of veto threshold required to trigger an
  /// extension.
  uint16 private _minorVetoExtensionThresholdPct;

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

  /// @notice Returns the current voting period extension duration applied when the minor veto
  /// threshold is triggered.
  function votingPeriodExtension() public view virtual returns (uint48) {
    return _votingPeriodExtension;
  }

  /// @notice Returns the minor veto threshold expressed in percentage points of the real veto
  /// threshold that must be reached to extend the voting period.
  function minorVetoExtensionThresholdPct() public view virtual returns (uint16) {
    return _minorVetoExtensionThresholdPct;
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
    if (_minorVetoExtensionThresholdPct == 0) return false;

    uint256 _minorThreshold = Math.mulDiv(
      vetoThreshold(proposalSnapshot(_proposalId)),
      _minorVetoExtensionThresholdPct,
      minorVetoExtensionThresholdDenominator()
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
      uint48 extendedDeadline = clock() + votingPeriodExtension();

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
    emit VotingPeriodExtensionSet(_votingPeriodExtension, _newVotingPeriodExtension);

    _votingPeriodExtension = _newVotingPeriodExtension;
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
    emit MinorVetoExtensionThresholdPctSet(
      _minorVetoExtensionThresholdPct, _newMinorVetoExtensionThresholdPct
    );
    _minorVetoExtensionThresholdPct = _newMinorVetoExtensionThresholdPct;
  }
}
