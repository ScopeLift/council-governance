// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {DeploymentConfigurationBase} from "script/DeploymentConfigurationBase.s.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployVetoGovernor is Script, BaseLogger {
  function _computeCouncilGovernorAddress(address _deployer) internal view returns (address) {
    // We need to account for timelock param adjustment after deployment, which takes 3 transactions.
    uint256 _nextNonce = vm.getNonce(_deployer) + 4;
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
      _config.vetoGuardian,
      _config.vetoOverrideRole,
      _config.vetoOverrideDuration,
      TimelockController(_timelock),
      _config.vetoGovernorAdmin,
      _predictedCouncilGovernorAddress
    );

    vetoGovernor = new BasicCouncilVetoGovernor(_params);
    _timelock.grantRole(_timelock.EXECUTOR_ROLE(), address(vetoGovernor));
    _timelock.grantRole(_timelock.PROPOSER_ROLE(), address(vetoGovernor));
    _timelock.renounceRole(_timelock.DEFAULT_ADMIN_ROLE(), _deployer);

    vm.stopBroadcast();

    _log("vetoGovernor", address(vetoGovernor));
  }
}
