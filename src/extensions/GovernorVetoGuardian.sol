// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";

/// @title GovernorVetoGuardian
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension of {Governor} that allows a trusted address to veto a proposal if the proposal
/// state is pending or active.
abstract contract GovernorVetoGuardian is Governor {
  address public vetoGuardian;
  mapping(uint256 => bool) public guardianVetoed;

  constructor(address _vetoGuardian) {
    vetoGuardian = _vetoGuardian;
  }

  /// @notice Emitted when the veto guardian address is modified.
  event VetoGuardianModified(address indexed oldVetoGuardian, address indexed newVetoGuardian);

  /// @notice Emitted when the veto guardian vetoes a proposal.
  event ProposalVetoedByGuardian(uint256 indexed proposalId);

  /// @notice Thrown when any address other than the veto guardian calls the function.
  error GovernorVetoGuardian_Unauthorized(address caller);

  /// @notice Thrown when any guardian tries to veto a proposal that is not pending or active.
  error GovernorVetoGuardian_UnexpectedProposalState();

  modifier onlyVetoGuardian() {
    if (_msgSender() != vetoGuardian) revert GovernorVetoGuardian_Unauthorized(_msgSender());
    _;
  }

  /// @notice Treats vetoed proposals as Defeated unless they have already been queued or executed.
  /// @dev The guardian flag is ignored once queue succeeds, so veto overrides can still promote
  /// the proposal.
  function state(uint256 proposalId) public view virtual override returns (ProposalState) {
    ProposalState currentState = super.state(proposalId);

    // Unfortunately we cannot use _validateStateBitmap here because it returns `ProposalState`
    // rather than boolean. Current implementation is the most readable.
    // Veto override modules evaluate after this, so queued/executed proposals are treated as
    // already rescued.
    if (
      guardianVetoed[proposalId] && currentState != ProposalState.Queued
        && currentState != ProposalState.Executed
    ) return ProposalState.Defeated;
    return currentState;
  }

  /// @notice Set the veto guardian address. Can only be called by the main DAO governor.
  /// @dev Passing address(0) effectively removes the guardian. Callers must ensure that is
  /// acceptable.
  function setVetoGuardian(address newVetoGuardian) external virtual onlyGovernance {
    address oldVetoGuardian = vetoGuardian;
    vetoGuardian = newVetoGuardian;
    emit VetoGuardianModified(oldVetoGuardian, newVetoGuardian);
  }

  /// @notice Allows the guardian to veto proposals while they are `Pending` or `Active`; vetoed
  /// proposals evaluates to `Defeated`.
  /// @dev This status can later be cleared by a veto override module.
  /// @param proposalId is the proposalId to be vetoed by the guardian.
  function vetoByGuardian(uint256 proposalId) external onlyVetoGuardian {
    ProposalState current = state(proposalId);
    if (current != ProposalState.Pending && current != ProposalState.Active) {
      revert GovernorVetoGuardian_UnexpectedProposalState();
    }

    guardianVetoed[proposalId] = true;
    emit ProposalVetoedByGuardian(proposalId);
  }
}
