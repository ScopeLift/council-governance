// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

import {BaseLogger} from "script/BaseLogger.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";
import {CouncilGovernorDeployInput} from "script/DeployInput.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract DeployCouncilGovernor is Script, BaseLogger, CouncilGovernorDeployInput {
  function run(
    address _deployer,
    CouncilERC20 _councilToken,
    BasicCouncilVetoGovernor _vetoGovernor
  ) public returns (BasicCouncilGovernor councilGovernor) {
    vm.startBroadcast(_deployer);

    councilGovernor = new BasicCouncilGovernor(
      IERC5805(_councilToken),
      IGovernor(_vetoGovernor),
      GOVERNOR_ADMIN,
      INITIAL_COUNCIL_GOVERNOR_VOTING_DELAY,
      INITIAL_COUNCIL_GOVERNOR_VOTING_PERIOD,
      INITIAL_COUNCIL_GOVERNOR_PROPOSAL_THRESHOLD
    );

    vm.stopBroadcast();

    _log("councilGovernor", address(councilGovernor));
  }
}
