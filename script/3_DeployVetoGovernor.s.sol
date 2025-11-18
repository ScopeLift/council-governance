// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {DeploymentConfigurationBase} from "script/DeploymentConfigurationBase.s.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployVetoGovernor is Script, BaseLogger {
  function _computeCouncilGovernorAddress(address _deployer) internal view returns (address) {
    uint256 _nextNonce = vm.getNonce(_deployer) + 1;
    return vm.computeCreateAddress(_deployer, _nextNonce);
  }

  function run(
    address _deployer,
    TimelockController _timelock,
    DeploymentConfigurationBase.VetoGovernorDeploymentConfiguration memory _config
  ) public returns (BasicCouncilVetoGovernor vetoGovernor) {
    address _predictedCouncilGovernorAddress = _computeCouncilGovernorAddress(_deployer);

    vm.startBroadcast(_deployer);

    BasicCouncilVetoGovernor.ConstructorParams memory _params = BasicCouncilVetoGovernor
      .ConstructorParams(
      _config.vetoGovernorName,
      _config.mainDaoToken,
      _config.vetoGovernorInitialVotingDelay,
      _config.vetoGovernorInitialVotingPeriod,
      _config.vetoGovernorInitialProposalThreshold,
      _config.vetoOverrideRole,
      _config.vetoOverrideDuration,
      _config.vetoGuardian,
      TimelockController(_timelock),
      _config.vetoGovernorAdmin,
      _computeCouncilGovernorAddress(_deployer)
    );

    vetoGovernor = new BasicCouncilVetoGovernor(_params);

    vm.stopBroadcast();

    _log("vetoGovernor", address(vetoGovernor));
  }
}
