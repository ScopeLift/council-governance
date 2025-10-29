// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {IGovernor, Governor} from "@openzeppelin/contracts/governance/Governor.sol";

/**
 * @dev Extension of {Governor} that binds the execution process to an instance of
 * {CouncilVetoGovernor}. The {CouncilGovernor} needs to be able to call `propose`, `cancel`, and
 * `execute` for the {CouncilGovernor} to work properly.
 * to work properly.
 *
 * Using this model means the proposal will be operated by the {CouncilVetoGovernor} and not by the
 * {CouncilGovernor}. Thus,
 * the assets and permissions must be attached to the {CouncilVetoGovernor}. Any asset sent to this
 * {CouncilGovernor} will be
 * inaccessible from a proposal, unless executed via {CouncilGovernor-relay}.
 */
abstract contract GovernorCouncilQueuing is Governor {
  mapping(uint256 proposalId => string) private _proposalDescriptions;
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
   * @dev Overridden version of the {Governor-state} function that considers the status reported by
   * the GovernorCouncilVetoGovernor.
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
      // Normally execution will flow from CouncilGovernor to CouncilVetoGovernor to Timelock, and
      // we'll already have recorded execution (or cancellation). But in case the proposal is
      // executed directly either on the CouncilVetoGovernor or the Timelock, this is our fallback.
      return ProposalState.Executed;
    } else {
      // See comment above.
      return ProposalState.Canceled;
    }
  }

  /// @inheritdoc IGovernor
  function proposalNeedsQueuing(uint256) public view virtual override returns (bool) {
    return true;
  }

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
   * @dev Function to queue a proposal to the timelock.
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
   * @dev Overridden version of the {Governor-_executeOperations} function that runs the already
   * queued proposal
   * through the timelock.
   */
  function _executeOperations(
    uint256, /*proposalId*/
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal virtual override {
    // execute
    councilVetoGovernor.execute(targets, values, calldatas, descriptionHash);
  }

  /**
   * @dev Overridden version of the {Governor-_cancel} function to cancel the proposal if it has
   * already
   * been queued.
   */
  // This function can reenter through the external call to the veto governor, but we assume the
  // veto governor
  // is trusted and
  // well behaved (according to BasicCouncilVetoGovernor) and this will not happen.
  // slither-disable-next-line reentrancy-no-eth
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
   * @dev Public endpoint to update the underlying timelock instance. Restricted to the timelock
   * itself, so updates
   * must be proposed, scheduled, and executed through governance proposals.
   *
   * CAUTION: It is not recommended to change the timelock while there are other queued governance
   * proposals.
   */
  function updateCouncilVetoGovernor(IGovernor newCouncilVetoGovernor)
    external
    virtual
    onlyGovernance
  {
    _updateCouncilVetoGovernor(newCouncilVetoGovernor);
  }

  function _updateCouncilVetoGovernor(IGovernor newCouncilVetoGovernor) private {
    emit CouncilVetoGovernorChange(address(councilVetoGovernor), address(newCouncilVetoGovernor));
    councilVetoGovernor = newCouncilVetoGovernor;
  }
}
