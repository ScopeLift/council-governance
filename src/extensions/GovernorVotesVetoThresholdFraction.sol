// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";

/// @title GovernorVetoOverride
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension for {Governor} that allows overriding vetoed proposals.
/// @dev Extension of {Governor} for voting weight extraction from an {ERC20Votes} token and a veto
/// threshold expressed as a fraction of the total supply.
/// Heavily borrowed from OpenZeppelin's GovernorVotesQuorumFraction (v5.4.0)
/// (governance/extensions/GovernorVotesQuorumFraction.sol)
abstract contract GovernorVotesVetoThresholdFraction is GovernorVotes {
  using Checkpoints for Checkpoints.Trace208;

  Checkpoints.Trace208 private _vetoThresholdNumeratorHistory;

  event VetoThresholdNumeratorUpdated(
    uint256 oldVetoThresholdNumerator, uint256 newVetoThresholdNumerator
  );

  /**
   * @dev The vetoThreshold set is not a valid fraction.
   */
  error GovernorInvalidVetoThresholdFraction(
    uint256 vetoThresholdNumerator, uint256 vetoThresholdDenominator
  );

  /**
   * @dev Initialize vetoThreshold as a fraction of the token's total supply.
   *
   * The fraction is specified as `numerator / denominator`. By default the denominator is 100, so
   * vetoThreshold is
   * specified as a percent: a numerator of 10 corresponds to vetoThreshold being 10% of total
   * supply. The denominator can be
   * customized by overriding {vetoThresholdDenominator}.
   */
  constructor(uint256 vetoThresholdNumeratorValue) {
    _updateVetoThresholdNumerator(vetoThresholdNumeratorValue);
  }

  /**
   * @dev Returns the current vetoThreshold numerator. See {vetoThresholdDenominator}.
   */
  function vetoThresholdNumerator() public view virtual returns (uint256) {
    return _vetoThresholdNumeratorHistory.latest();
  }

  /**
   * @dev Returns the vetoThreshold numerator at a specific timepoint. See
   * {vetoThresholdDenominator}.
   */
  function vetoThresholdNumerator(uint256 timepoint) public view virtual returns (uint256) {
    return _optimisticUpperLookupRecent(_vetoThresholdNumeratorHistory, timepoint);
  }

  /**
   * @dev Returns the vetoThreshold denominator. Defaults to 100, but may be overridden.
   */
  function vetoThresholdDenominator() public view virtual returns (uint256) {
    return 100;
  }

  /**
   * @dev Returns the vetoThreshold for a timepoint, in terms of number of votes: `supply *
   * numerator / denominator`.
   */
  function vetoThreshold(uint256 timepoint) public view virtual returns (uint256) {
    return Math.mulDiv(
      token().getPastTotalSupply(timepoint),
      vetoThresholdNumerator(timepoint),
      vetoThresholdDenominator()
    );
  }

  /**
   * @dev Changes the vetoThreshold numerator.
   *
   * Emits a {VetoThresholdNumeratorUpdated} event.
   *
   * Requirements:
   *
   * - Must be called through a governance proposal.
   * - New numerator must be smaller or equal to the denominator.
   */
  function updateVetoThresholdNumerator(uint256 newVetoThresholdNumerator)
    external
    virtual
    onlyGovernance
  {
    _updateVetoThresholdNumerator(newVetoThresholdNumerator);
  }

  /**
   * @dev Changes the vetoThreshold numerator.
   *
   * Emits a {VetoThresholdNumeratorUpdated} event.
   *
   * Requirements:
   *
   * - New numerator must be smaller or equal to the denominator.
   */
  function _updateVetoThresholdNumerator(uint256 newVetoThresholdNumerator) internal virtual {
    uint256 denominator = vetoThresholdDenominator();
    if (newVetoThresholdNumerator > denominator) {
      revert GovernorInvalidVetoThresholdFraction(newVetoThresholdNumerator, denominator);
    }

    uint256 oldVetoThresholdNumerator = vetoThresholdNumerator();
    _vetoThresholdNumeratorHistory.push(clock(), SafeCast.toUint208(newVetoThresholdNumerator));

    emit VetoThresholdNumeratorUpdated(oldVetoThresholdNumerator, newVetoThresholdNumerator);
  }

  /**
   * @dev Returns the numerator at a specific timepoint.
   */
  function _optimisticUpperLookupRecent(Checkpoints.Trace208 storage ckpts, uint256 timepoint)
    internal
    view
    returns (uint256)
  {
    // If trace is empty, key and value are both equal to 0.
    // In that case `key <= timepoint` is true, and it is ok to return 0.
    (, uint48 key, uint208 value) = ckpts.latestCheckpoint();
    return key <= timepoint ? value : ckpts.upperLookupRecent(SafeCast.toUint48(timepoint));
  }
}
