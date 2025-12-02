// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

import {BaseLogger} from "script/BaseLogger.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";
import {DeploymentConfigurationBase} from "script/DeploymentConfigurationBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

contract DeployCouncilGovernor is Script, BaseLogger {
  function run(
    address _deployer,
    CouncilERC20 _councilToken,
    BasicCouncilVetoGovernor _vetoGovernor,
    DeploymentConfigurationBase.CouncilGovernorDeploymentConfiguration memory _config
  ) public returns (BasicCouncilGovernor councilGovernor) {
    vm.startBroadcast(_deployer);

    councilGovernor = new BasicCouncilGovernor(
      IERC5805(_councilToken),
      IGovernor(_vetoGovernor),
      _config.councilGovernorAdmin,
      _config.councilGovernorInitialVotingDelay,
      _config.councilGovernorInitialVotingPeriod,
      _config.councilGovernorInitialProposalThreshold
    );

    vm.stopBroadcast();

    _log("councilGovernor", address(councilGovernor));
  }
}
