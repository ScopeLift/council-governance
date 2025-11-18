// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {DeploymentConfigurationBase} from "script/DeploymentConfigurationBase.s.sol";

contract DeployTimelock is Script, BaseLogger {
  function _computeVetoGovernorAddress(address _deployer) internal view returns (address) {
    uint256 _nextNonce = vm.getNonce(_deployer) + 1;
    return vm.computeCreateAddress(_deployer, _nextNonce);
  }

  function run(
    address _deployer,
    DeploymentConfigurationBase.TimelockDeploymentConfiguration memory _config
  ) public returns (TimelockController timelock) {
    address _predictedVetoGovernorAddress = _computeVetoGovernorAddress(_deployer);

    vm.startBroadcast(_deployer);

    address[] memory _proposers = new address[](1);
    address[] memory _executors = new address[](1);
    _proposers[0] = _predictedVetoGovernorAddress;
    _executors[0] = _predictedVetoGovernorAddress;

    timelock = new TimelockController(_config.timelockMinDelay, _proposers, _executors, address(0));

    vm.stopBroadcast();

    _log("timelock", address(timelock));
  }
}
