// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Libraries
import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";

/// @title GovernorCouncilQueuing
/// @author [ScopeLift](https://scopelift.co)
/// @notice Extension of {Governor} that binds the execution process to an instance of
/// {CouncilVetoGovernor}. The {CouncilGovernor} needs to be able to call `propose`, `cancel`, and
/// `execute` for the {CouncilGovernor} to work properly.
///
/// Using this model means the proposal will be operated by the {CouncilVetoGovernor} and not by the
/// {CouncilGovernor}. Thus, the assets and permissions must be attached to the
/// {CouncilVetoGovernor}. Any asset sent to this {CouncilGovernor} will be inaccessible from a
/// proposal, unless executed via {CouncilGovernor-relay}.
abstract contract GovernorCouncilQueuing is Governor {
  /*///////////////////////////////////////////////////////////////
                          Events
  //////////////////////////////////////////////////////////////*/

  /// @dev Emitted when the veto governor used for proposal execution is modified.
  /// @param oldVetoGovernor The address of the old veto governor.
  /// @param newVetoGovernor The address of the new veto governor.
  event CouncilVetoGovernorChange(address indexed oldVetoGovernor, address indexed newVetoGovernor);

  /*///////////////////////////////////////////////////////////////
                          State Variables
  //////////////////////////////////////////////////////////////*/

  /// @notice Mapping of proposal IDs to their descriptions.
  /// @dev Veto governor needs the description to create the proposal.
  mapping(uint256 proposalId => string) internal _proposalDescriptions;

  /// @notice The council veto governor instance.
  IGovernor public councilVetoGovernor;

  /*///////////////////////////////////////////////////////////////
                          Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Initializes the extension with the council veto governor instance.
  /// @param _councilVetoGovernor The council veto governor instance.
  constructor(IGovernor _councilVetoGovernor) {
    councilVetoGovernor = _councilVetoGovernor;
  }

  /*///////////////////////////////////////////////////////////////
                          External Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Returns the current state of a proposal, considering both council and veto governor
  /// states.
  /// @dev Overridden version of {Governor-state} function that implements dual governor logic.
  /// For non-queued proposals, returns the council governor's state directly.
  /// For queued proposals, determines the final state based on the veto governor's status:
  /// - Returns Queued if veto governor proposal is in non-terminal state.
  /// - Returns Executed if veto governor proposal is Executed (fallback for non-council exection).
  /// - Returns Canceled if veto governor proposal failed (Canceled/Defeated/Expired).
  /// @param _proposalId the ID of the proposal to check.
  /// @return The current state of the proposal considering both governors.
  function state(uint256 _proposalId) public view virtual override returns (ProposalState) {
    ProposalState _currentState = super.state(_proposalId);

    if (_currentState != ProposalState.Queued) return _currentState;
    if (
      _checkVetoGovernorStateBitmap(
        _proposalId,
        _encodeStateBitmap(ProposalState.Pending) | _encodeStateBitmap(ProposalState.Active)
          | _encodeStateBitmap(ProposalState.Queued) | _encodeStateBitmap(ProposalState.Succeeded)
      )
    ) {
      return ProposalState.Queued;
    } else if (
      _checkVetoGovernorStateBitmap(_proposalId, _encodeStateBitmap(ProposalState.Executed))
    ) {
      // Fallback for proposals executed directly on the veto governor or the timelock
      return ProposalState.Executed;
    } else {
      return ProposalState.Canceled;
    }
  }

  /// @inheritdoc IGovernor
  /// @dev All proposals are required to be queued so that it can be forwarded to the veto governor.
  function proposalNeedsQueuing(uint256) public view virtual override returns (bool) {
    return true;
  }

  /// @notice Creates a proposal on the council governor.
  /// @dev Extends {Governor-propose} to store the proposal description for later use when queuing.
  /// @param _targets Array of target addresses for the proposal calls.
  /// @param _values Array of values for the proposal calls.
  /// @param _calldatas Array of call data for the proposal calls
  /// @param _description Human-readable description of the proposal.
  /// @return _proposalId The unique identifier of the created proposal.
  function propose(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) public virtual override returns (uint256 _proposalId) {
    _proposalId = super.propose(_targets, _values, _calldatas, _description);
    _proposalDescriptions[_proposalId] = _description;
  }

  /// @notice Updates the veto governor used for proposal queuing and exeuction.
  /// @dev Restricted to the main DAO governance. The council cannot change its own veto governor,
  /// even through a sucessful council proposal.
  /// @param _newCouncilVetoGovernor The new veto governor contract address.
  /// @custom:security-note It is not recommended to change the timelock while there are other
  /// queued governance proposals.
  function updateCouncilVetoGovernor(IGovernor _newCouncilVetoGovernor)
    external
    virtual
    onlyGovernance
  {
    _updateCouncilVetoGovernor(_newCouncilVetoGovernor);
  }

  /*///////////////////////////////////////////////////////////////
                          Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Checks if the {CouncilVetoGovernor}'s proposal state matches any of the allowed
  /// states.
  /// @dev Used in state() to determine council governor's proposal state based on veto governor's
  /// status.
  /// @param _proposalId The ID of the proposal to check on the {CouncilVetoGovernor}.
  /// @param _allowedStates Bitmap where each bit represents an allowed proposal state.
  /// @return True if the {CouncilVetoGovernor}'s proposal state is in the allowed state bitmap,
  /// false otherwise.
  function _checkVetoGovernorStateBitmap(uint256 _proposalId, bytes32 _allowedStates)
    internal
    view
    returns (bool)
  {
    ProposalState _currentState = councilVetoGovernor.state(_proposalId);
    if (_encodeStateBitmap(_currentState) & _allowedStates == bytes32(0)) return false;
    return true;
  }

  /// @notice Queues a successful proposal to the veto governor.
  /// @dev Extends {Governor-_queueOperations} to forward the proposal to the veto governor and
  /// clean up stored description.
  /// @param _proposalId The proposal ID to queue.
  /// @param _targets Array of target addresses for the proposal calls.
  /// @param _values Array of values for the proposal calls.
  /// @param _calldatas Array of call data for the proposal calls.
  /// @return Veto governor's deadline for this proposal.
  function _queueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 /* _descriptionHash */
  ) internal virtual override returns (uint48) {
    // Forward the proposal to the veto governor
    councilVetoGovernor.propose(_targets, _values, _calldatas, _proposalDescriptions[_proposalId]);
    // Clean up the stored description
    delete _proposalDescriptions[_proposalId];
    // Return the veto governor's deadline for this proposal
    return uint48(councilVetoGovernor.proposalDeadline(_proposalId));
  }

  /// @notice Executes a proposal through the veto governor.
  /// @dev Extends {Governor-_executeOperations} to execute a forwarded proposal on the veto
  /// governor.
  /// @param _targets Array of target addresses for the proposal calls.
  /// @param _values Array of values for the proposal calls.
  /// @param _calldatas Array of call data for the proposal calls.
  /// @param _descriptionHash Hash of the proposal description.
  function _executeOperations(
    uint256, /*_proposalId*/
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal virtual override {
    councilVetoGovernor.execute(_targets, _values, _calldatas, _descriptionHash);
  }

  /// @notice This function can only cancel proposals that are in the `Pending` state on the council
  /// governor. Once a proposal has been queued (forwarded to the veto governor), it cannot be
  /// canceled through this mechanism.
  /// @dev Overridden version of the {Governor-_cancel} function to cancel a proposal and clean up
  /// associated storage.
  /// @param _targets Array of target addresses for the proposal calls.
  /// @param _values Array of values for the proposal calls.
  /// @param _calldatas Array of call data for the proposal calls.
  /// @param _descriptionHash Hash of the proposal description.
  /// @return _proposalId The ID of the proposal to be canceled.
  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal virtual override returns (uint256 _proposalId) {
    _proposalId = super._cancel(_targets, _values, _calldatas, _descriptionHash);
    delete _proposalDescriptions[_proposalId];
  }

  /// @inheritdoc Governor
  /// @dev Address through which the governor executes action. In this case, the veto governor.
  function _executor() internal view virtual override returns (address) {
    return address(councilVetoGovernor);
  }

  /// @notice Internal function to update the veto governor and emit the change event.
  /// @param _newCouncilVetoGovernor The new veto governor contract.
  function _updateCouncilVetoGovernor(IGovernor _newCouncilVetoGovernor) internal {
    emit CouncilVetoGovernorChange(address(councilVetoGovernor), address(_newCouncilVetoGovernor));
    councilVetoGovernor = _newCouncilVetoGovernor;
  }
}
