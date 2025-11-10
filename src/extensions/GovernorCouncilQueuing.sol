// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";

/**
 * @title GovernorCouncilQueuing
 * @author [ScopeLift](https://scopelift.co)
 * @notice Extension of {Governor} that binds the execution process to an instance of
 * {CouncilVetoGovernor}. The {CouncilGovernor} needs to be able to call `propose`, `cancel`, and
 * `execute` for the {CouncilGovernor} to work properly.
 *
 * Using this model means the proposal will be operated by the {CouncilVetoGovernor} and not by the
 * {CouncilGovernor}. Thus, the assets and permissions must be attached to the
 * {CouncilVetoGovernor}. Any asset sent to this {CouncilGovernor} will be inaccessible from a
 * proposal, unless executed via {CouncilGovernor-relay}.
 */
abstract contract GovernorCouncilQueuing is Governor {
  mapping(uint256 proposalId => string) internal _proposalDescriptions;
  IGovernor public councilVetoGovernor;

  /**
   * @dev Emitted when the veto governor used for proposal execution is modified.
   */
  event CouncilVetoGovernorChange(address indexed oldVetoGovernor, address indexed newVetoGovernor);

  /**
   * @dev Set the veto governor.
   */
  constructor(IGovernor _councilVetoGovernor) {
    councilVetoGovernor = _councilVetoGovernor;
  }

  /**
   * @notice Checks if the {CouncilVetoGoveror}'s proposal state matches any of the allowed states.
   * @dev Uses bitwise operations to check multiple allowed states at once.
   * @param proposalId The ID of the proposal to check on the {CouncilVetoGovernor}.
   * @param allowedStates Bitmap where each bit represents an allowed proposal state.
   * @return True if the {CouncilVetoGoveror} proposal state is in the allowed state bitmap, false
   * otherwise.
   */
  function _checkVetoGovernorStateBitmap(uint256 proposalId, bytes32 allowedStates)
    internal
    view
    returns (bool)
  {
    ProposalState currentState = councilVetoGovernor.state(proposalId);
    if (_encodeStateBitmap(currentState) & allowedStates == bytes32(0)) return false;
    return true;
  }

  /**
   * @notice Returns the current state of a proposal, considering both council and veto governor
   * states.
   * @dev Overridden version of {Governor-state} function that implements dual governor logic.
   * For non-queued proposals, returns the council's state directly.
   * For queued proposals, determines the final state based on the veto governor's status:
   * - Returns Queued if veto governor proposal is in non-terminal state
   * - Returns Executed if veto governor proposal is Executed (fallback for non-council exection)
   * - Returns Canceled if veto governor proposal failed (Canceled/Defeated/Expired)
   * @param proposalId the ID of the proposal to check
   * @return The current state of the proposal considering both governors
   */
  function state(uint256 proposalId) public view virtual override returns (ProposalState) {
    ProposalState currentState = super.state(proposalId);

    if (currentState != ProposalState.Queued) return currentState;
    if (
      _checkVetoGovernorStateBitmap(
        proposalId,
        _encodeStateBitmap(ProposalState.Pending) | _encodeStateBitmap(ProposalState.Active)
          | _encodeStateBitmap(ProposalState.Queued) | _encodeStateBitmap(ProposalState.Succeeded)
      )
    ) {
      return ProposalState.Queued;
    } else if (
      _checkVetoGovernorStateBitmap(proposalId, _encodeStateBitmap(ProposalState.Executed))
    ) {
      // Fallback for proposals executed directly on the veto governor or the timelock
      return ProposalState.Executed;
    } else {
      return ProposalState.Canceled;
    }
  }

  /// @inheritdoc IGovernor
  function proposalNeedsQueuing(uint256) public view virtual override returns (bool) {
    return true;
  }

  /**
   * @notice Creates a proposal on the council governor.
   * @dev Extends {Governor-propose} to store the proposal description for later use when queuing.
   * @param targets Array of target addresses for the proposal calls
   * @param values Array of values for the proposal calls
   * @param calldatas Array of call data for the proposal calls
   * @param description Human-readable description of the proposal.
   * @return proposalId The unique identifier of the created proposal
   */
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public virtual override returns (uint256) {
    uint256 proposalId = super.propose(targets, values, calldatas, description);
    _proposalDescriptions[proposalId] = description;
    return proposalId;
  }

  /**
   * @notice Queues a successful proposal to the veto governor.
   * @dev Extends {Governor-_queueOperations} to forward the proposal to the veto governor and clean
   * up stored description.
   * @param targets Array of target addresses for the proposal calls
   * @param values Array of values for the proposal calls
   * @param calldatas Array of call data for the proposal calls
   * @return The veto governor's deadline for this proposal
   */
  function _queueOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 /* descriptionHash */
  ) internal virtual override returns (uint48) {
    councilVetoGovernor.propose(targets, values, calldatas, _proposalDescriptions[proposalId]);
    delete _proposalDescriptions[proposalId];
    return uint48(councilVetoGovernor.proposalDeadline(proposalId));
  }

  /**
   * @notice Executes a proposal through the veto governor.
   * @dev Extends {Governor-_executeOperations} to execute a forwarded proposal on the veto
   * governor.
   * @param targets Array of target addresses for the proposal calls
   * @param values Array of values for the proposal calls
   * @param calldatas Array of call data for the proposal calls
   * @param descriptionHash Hash of the proposal description
   */
  function _executeOperations(
    uint256, /*proposalId*/
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal virtual override {
    councilVetoGovernor.execute(targets, values, calldatas, descriptionHash);
  }

  /**
   * @notice This function can only cancel proposals that are in the `Pending` state on the council
   * governor. Once a proposal has been queued (forwarded to the veto governor), it cannot be
   * canceled through this mechanism.
   * @dev Overridden version of the {Governor-_cancel} function to cancel a proposal and clean up
   * associated storage.
   * @param targets Array of target addresses for the proposal calls
   * @param values Array of values for the proposal calls
   * @param calldatas Array of call data for the proposal calls
   * @param descriptionHash Hash of the proposal description
   * @return proposalId The ID of the proposal to be canceled
   */
  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal virtual override returns (uint256) {
    uint256 proposalId = super._cancel(targets, values, calldatas, descriptionHash);
    delete _proposalDescriptions[proposalId];

    return proposalId;
  }

  /**
   * @dev Address through which the governor executes action. In this case, the timelock.
   */
  function _executor() internal view virtual override returns (address) {
    return address(councilVetoGovernor);
  }

  /**
   * @notice Updates the veto governor used for proposal queuing and exeuction.
   * @dev Restricted to the main DAO governance. The council cannot change its own veto governor,
   * even through a sucessful council proposal.
   * @param newCouncilVetoGovernor The new veto governor contract address.
   * @custom:security-note It is not recommended to change the timelock while there are other queued
   * governance proposals.
   */
  function updateCouncilVetoGovernor(IGovernor newCouncilVetoGovernor)
    external
    virtual
    onlyGovernance
  {
    _updateCouncilVetoGovernor(newCouncilVetoGovernor);
  }

  /**
   * @dev Internal function to update the veto governor and emit the change event
   * @param newCouncilVetoGovernor The new veto governor contract
   */
  function _updateCouncilVetoGovernor(IGovernor newCouncilVetoGovernor) private {
    emit CouncilVetoGovernorChange(address(councilVetoGovernor), address(newCouncilVetoGovernor));
    councilVetoGovernor = newCouncilVetoGovernor;
  }
}
