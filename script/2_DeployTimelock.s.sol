// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {DeploymentConfigurationBase} from "script/DeploymentConfigurationBase.s.sol";

contract DeployTimelock is Script, BaseLogger {
  function run(
    address _deployer,
    DeploymentConfigurationBase.TimelockDeploymentConfiguration memory _config
  ) public returns (TimelockController timelock) {
    vm.startBroadcast(_deployer);

    address[] memory _proposers = new address[](0);
    address[] memory _executors = new address[](0);
    timelock = new TimelockController(_config.timelockMinDelay, _proposers, _executors, _deployer);

    vm.stopBroadcast();

    _log("timelock", address(timelock));
  }
}
