// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Governor, IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {
  GovernorVotesQuorumFraction,
  GovernorVotes
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {GovernorCouncilQueuing} from "src/extensions/GovernorCouncilQueuing.sol";

/**
 * @title GovernorCouncilQueuingMock
 * @dev Mock implementation of GovernorCouncilQueuing for testing purposes.
 */
contract GovernorCouncilQueuingMock is
  GovernorCouncilQueuing,
  GovernorSettings,
  GovernorCountingSimple,
  GovernorVotesQuorumFraction
{
  constructor(
    uint48 _initialVotingDelay,
    uint32 _initialVotingPeriod,
    uint256 _initialProposalThreshold,
    IGovernor _vetoGovernor,
    address councilToken
  )
    Governor("GovernorCouncilQueuingMock")
    GovernorCouncilQueuing(_vetoGovernor)
    GovernorSettings(_initialVotingDelay, _initialVotingPeriod, _initialProposalThreshold)
    GovernorVotesQuorumFraction(100)
    GovernorVotes(IVotes(councilToken))
  {}

  function quorum(uint256)
    public
    pure
    override(Governor, GovernorVotesQuorumFraction)
    returns (uint256)
  {
    return 5;
  }

  function state(uint256 proposalId)
    public
    view
    override(Governor, GovernorCouncilQueuing)
    returns (ProposalState)
  {
    return super.state(proposalId);
  }

  function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
    return super.proposalThreshold();
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override(Governor, GovernorCouncilQueuing) returns (uint256) {
    return super.propose(targets, values, calldatas, description);
  }

  function proposalNeedsQueuing(uint256 proposalId)
    public
    view
    virtual
    override(Governor, GovernorCouncilQueuing)
    returns (bool)
  {
    return super.proposalNeedsQueuing(proposalId);
  }

  function _queueOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorCouncilQueuing) returns (uint48) {
    return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function exposed_queueOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public returns (uint48) {
    return _queueOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function exposed_executeOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public {
    _executeOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function exposed_cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public {
    _cancel(targets, values, calldatas, descriptionHash);
  }

  function exposed_checkVetoGovernorStateBitmap(uint256 proposalId, bytes32 allowedStates)
    public
    view
    returns (bool)
  {
    return _checkVetoGovernorStateBitmap(proposalId, allowedStates);
  }

  function exposed_proposalDescription(uint256 proposalId) public view returns (string memory) {
    return _proposalDescriptions[proposalId];
  }

  function _executeOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorCouncilQueuing) {
    super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorCouncilQueuing) returns (uint256) {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  function _executor() internal view override(Governor, GovernorCouncilQueuing) returns (address) {
    return super._executor();
  }
}
