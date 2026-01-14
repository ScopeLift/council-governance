// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Internal Dependencies
import {CouncilERC20} from "src/CouncilERC20.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {CompoundCouncilVetoGovernor} from "src/CompoundCouncilVetoGovernor.sol";

// Script Dependencies
import {DeployGovernorsAndGrantRoles} from "script/DeployGovernorsAndGrantRoles.s.sol";

contract DeployCompoundGovernorsAndGrantRoles is DeployGovernorsAndGrantRoles {
  function runCompound(
    address _deployer,
    TimelockController _timelock,
    CouncilGovernorDeploymentConfiguration memory _councilConfig,
    VetoGovernorDeploymentConfiguration memory _vetoConfig,
    CouncilERC20 _councilToken
  )
    public
    returns (BasicCouncilGovernor councilGovernor, CompoundCouncilVetoGovernor vetoGovernor)
  {
    vm.startBroadcast(_deployer);

    BasicCouncilGovernor.InitialCouncilParams memory _councilParams =
      BasicCouncilGovernor.InitialCouncilParams(
        _councilConfig.councilGovernorInitialVotingDelay,
        _councilConfig.councilGovernorInitialVotingPeriod,
        _councilConfig.councilGovernorInitialProposalThreshold,
        _councilConfig.councilGovernorInitialQuorumFraction,
        _councilConfig.councilGovernorInitialSuperQuorumFraction
      );

    councilGovernor = new BasicCouncilGovernor(
      _councilConfig.councilGovernorName,
      IERC5805(_councilToken),
      IGovernor(_predictVetoGovernorAddress(_deployer)),
      _councilConfig.councilGovernorAdmin,
      _councilParams
    );

    BasicCouncilVetoGovernor.ConstructorParams memory _params =
      BasicCouncilVetoGovernor.ConstructorParams({
        name: _vetoConfig.vetoGovernorName,
        token: _vetoConfig.mainDaoToken,
        votingDelay: _vetoConfig.vetoGovernorInitialVotingDelay,
        votingPeriod: _vetoConfig.vetoGovernorInitialVotingPeriod,
        proposalThreshold: _vetoConfig.vetoGovernorInitialProposalThreshold,
        vetoGuardian: _vetoConfig.vetoGuardian,
        vetoOverrideRole: _vetoConfig.vetoOverrideRole,
        vetoOverrideDuration: _vetoConfig.vetoOverrideDuration,
        votingPeriodExtension: _vetoConfig.votingPeriodExtension,
        votingPeriodExtensionThresholdPct: _vetoConfig.votingPeriodExtensionThresholdPct,
        vetoThresholdNumerator: _vetoConfig.vetoThresholdNumerator,
        timelock: TimelockController(_timelock),
        governorAdmin: _vetoConfig.vetoGovernorAdmin,
        council: address(councilGovernor)
      });

    vetoGovernor = new CompoundCouncilVetoGovernor(_params);

    _grantVetoGovernorRoles(_deployer, address(vetoGovernor), _timelock);
    vm.stopBroadcast();

    _log("councilGovernor", address(councilGovernor));
    _log("vetoGovernor", address(vetoGovernor));
  }
}
