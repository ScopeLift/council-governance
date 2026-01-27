// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// Extenral Dependencies
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Internal Dependencies
import {CompoundCouncilVetoGovernor} from "src/CompoundCouncilVetoGovernor.sol";

// Script Dependencies
import {DeploymentConfigurationTestCompound} from "script/DeploymentConfigurationTestCompound.sol";

contract CompoundCouncilVetoGovernorHarness is CompoundCouncilVetoGovernor {
  constructor(
    DeploymentConfigurationTestCompound.VetoGovernorDeploymentConfiguration memory _config,
    TimelockController _timelock,
    address _council,
    address _deployer
  ) CompoundCouncilVetoGovernor(_buildParams(_config, _timelock, _council)) {}

  function _buildParams(
    DeploymentConfigurationTestCompound.VetoGovernorDeploymentConfiguration memory _config,
    TimelockController _timelock,
    address _council
  ) internal pure returns (ConstructorParams memory params) {
    params = ConstructorParams({
      name: _config.vetoGovernorName,
      token: _config.mainDaoToken,
      votingDelay: _config.vetoGovernorInitialVotingDelay,
      votingPeriod: _config.vetoGovernorInitialVotingPeriod,
      proposalThreshold: _config.vetoGovernorInitialProposalThreshold,
      vetoGuardian: _config.vetoGuardian,
      vetoOverrideRole: _config.vetoOverrideRole,
      vetoOverrideDuration: _config.vetoOverrideDuration,
      votingPeriodExtension: _config.votingPeriodExtension,
      votingPeriodExtensionThresholdPct: _config.votingPeriodExtensionThresholdPct,
      vetoThresholdNumerator: _config.vetoThresholdNumerator,
      timelock: _timelock,
      governorAdmin: _config.vetoGovernorAdmin,
      council: _council
    });
  }

  function exposed_CheckGovernance() public {
    _checkGovernance();
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
