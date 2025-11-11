// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
/**
 * @title GovernorVetoOverride
 * @author [ScopeLift](https://scopelift.co)
 * @notice Extension for {Governor} that allows overriding vetoed proposals.
 * @dev This contract enables an authorized role to override defeated proposals and temporarily
 * change their state to Succeeded. The override is only valid within a specified duration after the
 * proposal's voting deadline. Intended to be used with {GovernorVetoCountingSimple} or similar veto
 * mechanisms where proposals can be defeated through inverse quorum (veto votes).
 */

abstract contract GovernorVetoOverride is Governor {
  /**
   * @notice Tracks whether a proposal's veto has been overridden.
   * @dev Maps proposal ID to override status. Once set to true, cannot be reverted.
   */
  mapping(uint256 proposalId => bool) public isVetoOverridden;

  /**
   * @notice Duration after proposal deadline during which veto can be overridden.
   * @dev Once this window expires, overridden proposal state is restored to `Defeated`.
   */
  uint48 public vetoOverrideDuration;

  /**
   * @notice Address authorized to override proposal vetoes.
   * @dev Only this address can call `overrideVeto()`. Typically set to a multisig or DAO.
   */
  address public vetoOverrideRole;

  /**
   * @notice Emitted when a proposal's veto is overridden.
   * @param proposalId The ID of the proposal whose veto was overridden.
   */
  event VetoOverridden(uint256 proposalId);

  /**
   * @notice Emitted when the veto override duration is updated.
   * @param oldVetoOverrideDuration The previous override duration.
   * @param newVetoOverrideDuration The new override duration.
   */
  event VetoOverrideDurationSet(uint48 oldVetoOverrideDuration, uint48 newVetoOverrideDuration);

  /**
   * @notice Emitted when the veto override role is updated.
   * @param oldVetoOverrideRole The previous override role address.
   * @param newVetoOverrideRole The new override role address.
   */
  event VetoOverrideRoleSet(
    address indexed oldVetoOverrideRole, address indexed newVetoOverrideRole
  );

  /**
   * @notice Restricts function access to the veto override role.
   * @dev Reverts if caller is not the designated veto override role.
   */
  modifier onlyVetoOverrideRole() {
    require(
      _msgSender() == vetoOverrideRole, "GovernorVetoOverride: caller is not the veto override role"
    );
    _;
  }

  /**
   * @notice Initializes the veto override extension.
   * @param _vetoOverrideRole Address authorized to override vetoes.
   * @param _vetoOverrideDuration Time window for overrides after proposal deadline.
   */
  constructor(address _vetoOverrideRole, uint48 _vetoOverrideDuration) {
    vetoOverrideRole = _vetoOverrideRole;
    vetoOverrideDuration = _vetoOverrideDuration;
  }

  /**
   * @notice Updates the veto override role.
   *  @dev Only callable by governance.
   * @param _vetoOverrideRole New address for the veto override role
   */
  function setVetoOverrideRole(address _vetoOverrideRole) public virtual onlyGovernance {
    _setVetoOverrideRole(_vetoOverrideRole);
  }

  /**
   * @notice Updates the veto override duration.
   *  @dev Only callable by governance.
   * @param _vetoOverrideDuration New duration for veto overrides.
   */
  function setVetoOverrideDuration(uint48 _vetoOverrideDuration) public virtual onlyGovernance {
    _setVetoOverrideDuration(_vetoOverrideDuration);
  }

  /**
   * @notice Internal function to update the veto override role.
   * @param _vetoOverrideRole New address for the veto override role.
   */
  function _setVetoOverrideRole(address _vetoOverrideRole) internal virtual {
    emit VetoOverrideRoleSet(vetoOverrideRole, _vetoOverrideRole);
    vetoOverrideRole = _vetoOverrideRole;
  }

  /**
   * @notice Internal function to update the veto override duration.
   * @param _vetoOverrideDuration New duration for veto overrides.
   */
  function _setVetoOverrideDuration(uint48 _vetoOverrideDuration) internal virtual {
    emit VetoOverrideDurationSet(vetoOverrideDuration, _vetoOverrideDuration);
    vetoOverrideDuration = _vetoOverrideDuration;
  }

  /**
   * @notice Overrides the veto for a specific proposal.
   * @dev Only callable by the veto override role. Can be called on any proposal ID, regardless of
   * its current state.
   * @param proposalId The ID of the proposal to override.
   */
  function overrideVeto(uint256 proposalId) public virtual onlyVetoOverrideRole {
    isVetoOverridden[proposalId] = true;
    emit VetoOverridden(proposalId);
  }

  /**
   * @notice Returns the current state of a proposal, accounting for veto overrides.
   * @dev If a proposal is `Defeated`, overridden, and within the override window, it returns
   * `Succeeded` instead of `Defeated`. Override window is measured from the proposal's voting
   * deadline.
   * @param proposalId The ID of the proposal to check.
   * @return ProposalState The current state of the proposal.
   */
  function state(uint256 proposalId) public view virtual override returns (ProposalState) {
    ProposalState _state = super.state(proposalId);
    if (
      isVetoOverridden[proposalId] && _state == ProposalState.Defeated
        && clock() - proposalDeadline(proposalId) < vetoOverrideDuration
    ) return ProposalState.Succeeded;
    return _state;
  }
}
