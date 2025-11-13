// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {VetoGovernorDeployInput} from "script/DeployInput.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployVetoGovernor is Script, BaseLogger, VetoGovernorDeployInput {
  function _computeCouncilGovernorAddress() internal view returns (address) {
    address deployer = tx.origin;
    uint256 nextNonce = vm.getNonce(deployer) + 1;
    return vm.computeCreateAddress(deployer, nextNonce);
  }

  function run(address payable _timelock) public returns (BasicCouncilVetoGovernor vetoGovernor) {
    vm.startBroadcast();

    BasicCouncilVetoGovernor.ConstructorParams memory params = BasicCouncilVetoGovernor
      .ConstructorParams(
      NAME,
      MAIN_DAO_TOKEN,
      INITIAL_COUNCIL_VETO_VOTING_DELAY,
      INITIAL_COUNCIL_VETO_VOTING_PERIOD,
      INITIAL_COUNCIL_VETO_PROPOSAL_THRESHOLD,
      VETO_OVERRIDE_ROLE,
      VETO_OVERRIDE_DURATION,
      VETO_GUARDIAN,
      TimelockController(_timelock),
      GOVERNOR_ADMIN,
      _computeCouncilGovernorAddress()
    );

    vetoGovernor = new BasicCouncilVetoGovernor(params);

    vm.stopBroadcast();

    _log("vetoGovernor", address(vetoGovernor));
  }
}
