// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.30;

// External Dependencies
import {GovernorVetoCountingSimple} from "src/extensions/GovernorVetoCountingSimple.sol";

/// @title GovernorVetoOverride
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension for {Governor} that allows overriding vetoed proposals.
/// @dev This contract enables an authorized role to override defeated proposals and temporarily
/// change their state to Succeeded. The override is only valid within a specified duration after
/// the proposal's voting deadline. Intended to be used with {GovernorVetoCountingSimple} or similar
/// veto mechanisms.
abstract contract GovernorVetoOverride is GovernorVetoCountingSimple {
  /// @notice Emitted when a proposal's veto is overridden.
  /// @param proposalId The ID of the proposal whose veto was overridden.
  event VetoOverridden(uint256 proposalId);

  /// @notice Emitted when the veto override duration is updated.
  /// @param oldVetoOverrideDuration The previous override duration.
  /// @param newVetoOverrideDuration The new override duration.
  event VetoOverrideDurationSet(uint48 oldVetoOverrideDuration, uint48 newVetoOverrideDuration);

  /// @notice Emitted when the veto override role is updated.
  /// @param oldVetoOverrideRole The previous override role address.
  /// @param newVetoOverrideRole The new override role address.
  event VetoOverrideRoleSet(
    address indexed oldVetoOverrideRole, address indexed newVetoOverrideRole
  );

  /// @notice Thrown when an unauthorized caller attempts to override a veto.
  /// @param caller The address that attempted the call.
  error VetoOverrideUnauthorizedAccount(address caller);

  /// @notice Thrown when attempting to override a proposal that is not in the Defeated state.
  /// @param proposalId The ID of the proposal that was attempted to be overridden.
  /// @param currentState The state of the proposal at the time of the attempted override.
  error VetoOverrideUnexpectedState(uint256 proposalId, ProposalState currentState);

  /// @notice Thrown when attempting to override a proposal outside the allowed time window.
  /// @param proposalId The ID of the proposal that was attempted to be overridden.
  /// @param currentTimepoint The current clock value (block number or timestamp depending on clock
  /// mode).
  error VetoOverrideOutsideWindow(uint256 proposalId, uint48 currentTimepoint);

  /// @notice Tracks whether a proposal's veto has been overridden.
  /// @dev Maps proposal ID to override status. Once set to true, cannot be reverted.
  mapping(uint256 proposalId => bool) public isVetoOverridden;

  /// @notice Duration after proposal deadline during which veto override can be applied.
  /// @dev Prevents the retroactive override of historically defeated proposals, ensuring override
  /// decisions are made within a relevant timeframe.
  uint48 public vetoOverrideDuration;

  /// @notice Address authorized to override proposal vetoes.
  /// @dev Only this address can call `overrideVeto()`.
  address public vetoOverrideRole;

  /// @notice Restricts function access to the veto override role.
  /// @dev Reverts if caller is not the designated veto override role.
  modifier onlyVetoOverrideRole() {
    if (_msgSender() != vetoOverrideRole) revert VetoOverrideUnauthorizedAccount(_msgSender());

    _;
  }

  /// @notice Initializes the veto override extension.
  /// @param _vetoOverrideRole Address authorized to override vetoes.
  /// @param _vetoOverrideDuration Time window allotted for overrides after proposal deadline.
  constructor(address _vetoOverrideRole, uint48 _vetoOverrideDuration) {
    vetoOverrideRole = _vetoOverrideRole;
    vetoOverrideDuration = _vetoOverrideDuration;
  }

  /// @notice Returns the current state of a proposal, accounting for veto overrides.
  /// @dev If a proposal is already queued, its state is preserved to prevent queued proposals from
  /// becoming unexecutable.
  /// @param _proposalId The ID of the proposal to check.
  /// @return ProposalState The current state of the proposal.
  function state(uint256 _proposalId) public view virtual override returns (ProposalState) {
    ProposalState _state = super.state(_proposalId);

    if (isVetoOverridden[_proposalId] && _state == ProposalState.Defeated) {
      return ProposalState.Succeeded;
    }
    return _state;
  }

  /// @notice Overrides a vetoed proposal, allowing it to be queued.
  /// @dev Only callable by the veto override role, and must be called within the override window.
  /// @param _proposalId The ID of the proposal to override.
  function overrideVeto(uint256 _proposalId) public virtual onlyVetoOverrideRole {
    ProposalState _currentState = state(_proposalId);
    if (_currentState != ProposalState.Defeated) {
      revert VetoOverrideUnexpectedState(_proposalId, _currentState);
    }
    uint48 _currentTimepoint = clock();
    uint256 _deadline = proposalDeadline(_proposalId);
    if (_currentTimepoint < _deadline || _currentTimepoint > _deadline + vetoOverrideDuration) {
      revert VetoOverrideOutsideWindow(_proposalId, _currentTimepoint);
    }

    isVetoOverridden[_proposalId] = true;
    emit VetoOverridden(_proposalId);
  }

  /// @notice Updates the veto override role.
  /// @dev Only callable by governance.
  /// @param _vetoOverrideRole New address for the veto override role
  function setVetoOverrideRole(address _vetoOverrideRole) public virtual onlyGovernance {
    _setVetoOverrideRole(_vetoOverrideRole);
  }

  /// @notice Updates the veto override duration.
  /// @dev Only callable by governance.
  /// @param _vetoOverrideDuration New duration for veto overrides.
  function setVetoOverrideDuration(uint48 _vetoOverrideDuration) public virtual onlyGovernance {
    _setVetoOverrideDuration(_vetoOverrideDuration);
  }

  /// @notice Internal function to update the veto override role.
  /// @param _vetoOverrideRole New address for the veto override role.
  function _setVetoOverrideRole(address _vetoOverrideRole) internal virtual {
    emit VetoOverrideRoleSet(vetoOverrideRole, _vetoOverrideRole);
    vetoOverrideRole = _vetoOverrideRole;
  }

  /// @notice Internal function to update the veto override duration.
  /// @param _vetoOverrideDuration New duration for veto overrides.
  function _setVetoOverrideDuration(uint48 _vetoOverrideDuration) internal virtual {
    emit VetoOverrideDurationSet(vetoOverrideDuration, _vetoOverrideDuration);
    vetoOverrideDuration = _vetoOverrideDuration;
  }

  /// @inheritdoc GovernorVetoCountingSimple
  /// @dev If a proposal is veto-overridden, treat it as successful regardless of veto votes.
  /// This allows the proposal to progress to `Succeeded` (and then be queued) even if it would
  /// otherwise remain `Defeated` under the veto counting rules.
  function _voteSucceeded(uint256 _proposalId) internal view virtual override returns (bool) {
    if (isVetoOverridden[_proposalId]) return true;
    return super._voteSucceeded(_proposalId);
  }
}
