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

// Script Dependencies
import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";

contract DeployGovernorsAndGrantRoles is Script, BaseLogger {
  struct CouncilGovernorDeploymentConfiguration {
    string councilGovernorName;
    uint48 councilGovernorInitialVotingDelay;
    uint32 councilGovernorInitialVotingPeriod;
    uint256 councilGovernorInitialProposalThreshold;
    address councilGovernorAdmin;
  }

  struct VetoGovernorDeploymentConfiguration {
    string vetoGovernorName;
    IERC5805 mainDaoToken;
    uint48 vetoGovernorInitialVotingDelay;
    uint32 vetoGovernorInitialVotingPeriod;
    uint256 vetoGovernorInitialProposalThreshold;
    address vetoOverrideRole;
    uint48 vetoOverrideDuration;
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
    BasicCouncilVetoGovernor _vetoGovernor,
    TimelockController _timelock
  ) internal {
    _timelock.grantRole(_timelock.EXECUTOR_ROLE(), address(_vetoGovernor));
    _timelock.grantRole(_timelock.PROPOSER_ROLE(), address(_vetoGovernor));
    _timelock.renounceRole(_timelock.DEFAULT_ADMIN_ROLE(), _deployer);
  }

  function run(
    address _deployer,
    TimelockController _timelock,
    CouncilGovernorDeploymentConfiguration memory _councilConfig,
    VetoGovernorDeploymentConfiguration memory _vetoConfig,
    CouncilERC20 _councilToken
  ) public returns (BasicCouncilGovernor councilGovernor, BasicCouncilVetoGovernor vetoGovernor) {
    vm.startBroadcast(_deployer);

    councilGovernor = new BasicCouncilGovernor(
      _councilConfig.councilGovernorName,
      IERC5805(_councilToken),
      IGovernor(_predictVetoGovernorAddress(_deployer)),
      _councilConfig.councilGovernorAdmin,
      _councilConfig.councilGovernorInitialVotingDelay,
      _councilConfig.councilGovernorInitialVotingPeriod,
      _councilConfig.councilGovernorInitialProposalThreshold
    );

    BasicCouncilVetoGovernor.ConstructorParams memory _params =
      BasicCouncilVetoGovernor.ConstructorParams(
        _vetoConfig.vetoGovernorName,
        _vetoConfig.mainDaoToken,
        _vetoConfig.vetoGovernorInitialVotingDelay,
        _vetoConfig.vetoGovernorInitialVotingPeriod,
        _vetoConfig.vetoGovernorInitialProposalThreshold,
        _vetoConfig.vetoGuardian,
        _vetoConfig.vetoOverrideRole,
        _vetoConfig.vetoOverrideDuration,
        TimelockController(_timelock),
        _vetoConfig.vetoGovernorAdmin,
        address(councilGovernor)
      );

    vetoGovernor = new BasicCouncilVetoGovernor(_params);

    _grantVetoGovernorRoles(_deployer, vetoGovernor, _timelock);
    vm.stopBroadcast();

    _log("councilGovernor", address(councilGovernor));
    _log("vetoGovernor", address(vetoGovernor));
  }
}
