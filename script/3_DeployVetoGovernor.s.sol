// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {VetoGovernorDeployInput} from "script/DeployInput.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployVetoGovernor is Script, BaseLogger, VetoGovernorDeployInput {
  function _computeCouncilGovernorAddress(address _deployer) internal view returns (address) {
    uint256 _nextNonce = vm.getNonce(_deployer) + 1;
    return vm.computeCreateAddress(_deployer, _nextNonce);
  }

  function run(address _deployer, TimelockController _timelock)
    public
    returns (BasicCouncilVetoGovernor vetoGovernor)
  {
    vm.startBroadcast(_deployer);

    address _councilGovernorAddress = _computeCouncilGovernorAddress(_deployer);

    vetoGovernor = new BasicCouncilVetoGovernor(
      MAIN_DAO_TOKEN, _councilGovernorAddress, VETO_OVERRIDE_ROLE, VETO_OVERRIDE_DURATION, _timelock
    );

    vm.stopBroadcast();

    _log("vetoGovernor", address(vetoGovernor));
  }
}
