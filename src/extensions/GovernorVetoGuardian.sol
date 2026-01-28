// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Dependencies
import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";

/// @title GovernorVetoGuardian
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension of {Governor} that allows a trusted address to veto a proposal if the proposal
/// state is pending or active.
abstract contract GovernorVetoGuardian is Governor {
  /// @notice The address of the veto guardian.
  address public vetoGuardian;
  /// @dev Mapping of proposal IDs to their guardian veto status.
  mapping(uint256 => bool) public guardianVetoed;

  /// @notice Emitted when the veto guardian address is modified.
  event VetoGuardianModified(address indexed oldVetoGuardian, address indexed newVetoGuardian);

  /// @notice Emitted when the veto guardian vetoes a proposal.
  event ProposalVetoedByGuardian(uint256 indexed proposalId);

  /// @notice Thrown when any address other than the veto guardian calls the function.
  error GovernorVetoGuardian_Unauthorized();

  constructor(address _vetoGuardian) {
    _setVetoGuardian(_vetoGuardian);
  }

  /// @notice Restricts the function to the current veto guardian.
  /// @dev Reverts with `GovernorVetoGuardian_Unauthorized` when the caller is not `vetoGuardian`.
  modifier onlyVetoGuardian() {
    if (_msgSender() != vetoGuardian) revert GovernorVetoGuardian_Unauthorized();
    _;
  }

  /// @notice Treats vetoed proposals as `Defeated` unless the state is `Queued` or `Executed`.
  /// @dev The guardian flag is ignored once queue succeeds, so veto overrides can still promote
  /// the proposal.
  function state(uint256 _proposalId) public view virtual override returns (ProposalState) {
    ProposalState _currentState = super.state(_proposalId);

    if (
      guardianVetoed[_proposalId] && _currentState != ProposalState.Queued
        && _currentState != ProposalState.Executed
    ) return ProposalState.Defeated;
    return _currentState;
  }

  /// @notice Allows the guardian to veto proposals while they are `Pending` or `Active`.
  /// Vetoed proposals evaluate to `Defeated`.
  /// @param _proposalId The proposalId to be vetoed by the guardian.
  function vetoByGuardian(uint256 _proposalId) external onlyVetoGuardian {
    _validateStateBitmap(
      _proposalId,
      _encodeStateBitmap(IGovernor.ProposalState.Pending)
        | _encodeStateBitmap(IGovernor.ProposalState.Active)
    );

    guardianVetoed[_proposalId] = true;
    emit ProposalVetoedByGuardian(_proposalId);
  }

  /// @notice Set the veto guardian address. Can only be called by the governance.
  /// @dev Passing address(0) effectively removes the guardian. Callers must ensure that is
  /// acceptable.
  /// @param _vetoGuardian Address of the new veto guardian.
  function setVetoGuardian(address _vetoGuardian) external virtual onlyGovernance {
    _setVetoGuardian(_vetoGuardian);
  }

  /// @notice Internal method to set the veto guardian address.
  /// @param _vetoGuardian Address of the new veto guardian.
  function _setVetoGuardian(address _vetoGuardian) internal virtual {
    address _oldVetoGuardian = vetoGuardian;
    vetoGuardian = _vetoGuardian;
    emit VetoGuardianModified(_oldVetoGuardian, _vetoGuardian);
  }
}
