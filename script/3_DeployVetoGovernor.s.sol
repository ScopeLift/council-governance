// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {VetoGovernorDeployInput} from "script/DeployInput.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployVetoGovernor is Script, BaseLogger, VetoGovernorDeployInput {
  function _computeCouncilGovernorAddress(address _deployer) internal view returns (address) {
    uint256 nextNonce = vm.getNonce(_deployer) + 1;
    return vm.computeCreateAddress(_deployer, nextNonce);
  }

  function run(address _deployer, TimelockController _timelock)
    public
    returns (BasicCouncilVetoGovernor vetoGovernor)
  {
    vm.startBroadcast(_deployer);

    BasicCouncilVetoGovernor.ConstructorParams memory params = BasicCouncilVetoGovernor
      .ConstructorParams(
      VETO_GOVERNOR_NAME,
      MAIN_DAO_TOKEN,
      INITIAL_VETO_GOVERNOR_VOTING_DELAY,
      INITIAL_VETO_GOVERNOR_VOTING_PERIOD,
      INITIAL_VETO_GOVERNOR_PROPOSAL_THRESHOLD,
      VETO_OVERRIDE_ROLE,
      VETO_OVERRIDE_DURATION,
      VETO_GUARDIAN,
      TimelockController(_timelock),
      GOVERNOR_ADMIN,
      _computeCouncilGovernorAddress(_deployer)
    );

    vetoGovernor = new BasicCouncilVetoGovernor(params);

    vm.stopBroadcast();

    _log("vetoGovernor", address(vetoGovernor));
  }
}
