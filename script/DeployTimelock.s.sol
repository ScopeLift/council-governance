// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Script Dependencies
import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";

contract DeployTimelock is Script, BaseLogger {
  struct TimelockDeploymentConfiguration {
    uint256 timelockMinDelay;
  }

  function _getTimelockDeploymentConfiguration()
    public
    view
    virtual
    returns (TimelockDeploymentConfiguration memory)
  {}

  function run(address _deployer, TimelockDeploymentConfiguration memory _config)
    public
    returns (TimelockController _timelock)
  {
    vm.startBroadcast(_deployer);

    address[] memory _proposers = new address[](0);
    address[] memory _executors = new address[](0);
    _timelock = new TimelockController(_config.timelockMinDelay, _proposers, _executors, _deployer);

    vm.stopBroadcast();

    _log("_timelock", address(_timelock));
  }
}
