// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";

// Internal Dependencies
import {CouncilERC20} from "src/CouncilERC20.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";

// Script Dependencies
import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";

contract DeployCouncilGovernor is Script, BaseLogger {
  struct CouncilGovernorDeploymentConfiguration {
    string councilGovernorName;
    uint48 councilGovernorInitialVotingDelay;
    uint32 councilGovernorInitialVotingPeriod;
    uint256 councilGovernorInitialProposalThreshold;
    address councilGovernorAdmin;
  }

  function _getCouncilGovernorDeploymentConfiguration()
    public
    view
    virtual
    returns (CouncilGovernorDeploymentConfiguration memory)
  {}

  function run(
    address _deployer,
    CouncilERC20 _councilToken,
    BasicCouncilVetoGovernor _vetoGovernor,
    CouncilGovernorDeploymentConfiguration memory _config
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
