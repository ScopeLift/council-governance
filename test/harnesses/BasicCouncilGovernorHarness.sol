// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

// Internal Dependencies
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";

// Script Dependencies
import {DeploymentConfigurationTest} from "script/DeploymentConfigurationTest.sol";

contract BasicCouncilGovernorHarness is BasicCouncilGovernor {
  constructor(IERC5805 _councilToken, address _vetoGovernor)
    BasicCouncilGovernor(
      _config().councilGovernorName,
      _councilToken,
      BasicCouncilVetoGovernor(payable(_vetoGovernor)),
      _config().councilGovernorAdmin,
      BasicCouncilGovernor.InitialCouncilParams({
        initialVotingDelay: _config().councilGovernorInitialVotingDelay,
        initialVotingPeriod: _config().councilGovernorInitialVotingPeriod,
        initialProposalThreshold: _config().councilGovernorInitialProposalThreshold,
        initialQuorumFraction: _config().councilGovernorInitialQuorumFraction,
        initialSuperQuorumFraction: _config().councilGovernorInitialSuperQuorumFraction
      })
    )
  {}

  function _config()
    internal
    returns (DeploymentConfigurationTest.CouncilGovernorDeploymentConfiguration memory)
  {
    return (new DeploymentConfigurationTest())._getCouncilGovernorDeploymentConfiguration();
  }

  function exposed_ProposalDescriptions(uint256 proposalId) public view returns (string memory) {
    return proposalDescriptions[proposalId];
  }

  function exposed_CheckGovernance() public {
    _checkGovernance();
  }

  function exposed_Cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) public {
    _cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  function exposed_Executor() public view returns (address) {
    return _executor();
  }

  function exposed_QueueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) public {
    _queueOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }

  function exposed_ExecuteOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) public {
    _executeOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }
}
