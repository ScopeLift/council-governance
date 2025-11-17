// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {TimelockDeployInput} from "script/DeployInput.sol";

contract DeployTimelock is Script, BaseLogger, TimelockDeployInput {
  function _computeVetoGovernorAddress(address _deployer) internal view returns (address) {
    uint256 nextNonce = vm.getNonce(_deployer) + 1;
    return vm.computeCreateAddress(_deployer, nextNonce);
  }

  function run(address _deployer) public returns (TimelockController timelock) {
    vm.startBroadcast(_deployer);

    address[] memory _proposers = new address[](1);
    address[] memory _executors = new address[](1);
    _proposers[0] = _computeVetoGovernorAddress(_deployer);
    _executors[0] = _computeVetoGovernorAddress(_deployer);

    timelock = new TimelockController(TIMELOCK_MIN_DELAY, _proposers, _executors, address(0));

    vm.stopBroadcast();

    _log("timelock", address(timelock));
  }
}
