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
import {BaseLogger} from "script/BaseLogger.sol";
import {Script} from "forge-std/Script.sol";

contract DeployCompoundGovernorsAndGrantRoles is Script, BaseLogger {
  struct CouncilGovernorDeploymentConfiguration {
    string councilGovernorName;
    uint48 councilGovernorInitialVotingDelay;
    uint32 councilGovernorInitialVotingPeriod;
    uint256 councilGovernorInitialProposalThreshold;
    uint256 councilGovernorInitialQuorumFraction;
    uint256 councilGovernorInitialSuperQuorumFraction;
    address councilGovernorAdmin;
  }

  struct VetoGovernorDeploymentConfiguration {
    string vetoGovernorName;
    address mainDaoToken;
    uint48 vetoGovernorInitialVotingDelay;
    uint32 vetoGovernorInitialVotingPeriod;
    uint256 vetoGovernorInitialProposalThreshold;
    address vetoOverrideRole;
    uint48 vetoOverrideDuration;
    uint48 votingPeriodExtension;
    uint16 votingPeriodExtensionThresholdPct;
    uint256 vetoThresholdNumerator;
    address vetoGuardian;
    address vetoGovernorAdmin;
  }

  function _getCouncilGovernorDeploymentConfiguration()
    public
    view
    virtual
    returns (CouncilGovernorDeploymentConfiguration memory)
  {}

  function _getVetoGovernorDeploymentConfiguration()
    public
    view
    virtual
    returns (VetoGovernorDeploymentConfiguration memory)
  {}

  function _predictVetoGovernorAddress(address _deployer) internal view returns (address) {
    uint256 _nextNonce = vm.getNonce(_deployer) + 1;
    return vm.computeCreateAddress(_deployer, _nextNonce);
  }

  function _grantVetoGovernorRoles(
    address _deployer,
    address _vetoGovernor,
    TimelockController _timelock
  ) internal {
    _timelock.grantRole(_timelock.EXECUTOR_ROLE(), _vetoGovernor);
    _timelock.grantRole(_timelock.PROPOSER_ROLE(), _vetoGovernor);
    _timelock.renounceRole(_timelock.DEFAULT_ADMIN_ROLE(), _deployer);
  }

  function run(
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
