// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Dependencies
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Internal Dependencies
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";

// Script Dependencies
import {Script} from "forge-std/Script.sol";
import {BaseLogger} from "script/BaseLogger.sol";

contract DeployVetoGovernor is Script, BaseLogger {
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

  function _getVetoGovernorDeploymentConfiguration()
    public
    view
    virtual
    returns (VetoGovernorDeploymentConfiguration memory)
  {}

  function _computeCouncilGovernorAddress(address _deployer) internal view returns (address) {
    // We need to account for timelock param adjustment after deployment, which takes 3
    // transactions.
    uint256 _nextNonce = vm.getNonce(_deployer) + 4;
    return vm.computeCreateAddress(_deployer, _nextNonce);
  }

  function run(
    address _deployer,
    TimelockController _timelock,
    VetoGovernorDeploymentConfiguration memory _config
  ) public returns (BasicCouncilVetoGovernor vetoGovernor) {
    address _predictedCouncilGovernorAddress = _computeCouncilGovernorAddress(_deployer);

    vm.startBroadcast(_deployer);

    BasicCouncilVetoGovernor.ConstructorParams memory _params =
      BasicCouncilVetoGovernor.ConstructorParams(
        _config.vetoGovernorName,
        _config.mainDaoToken,
        _config.vetoGovernorInitialVotingDelay,
        _config.vetoGovernorInitialVotingPeriod,
        _config.vetoGovernorInitialProposalThreshold,
        _config.vetoGuardian,
        _config.vetoOverrideRole,
        _config.vetoOverrideDuration,
        TimelockController(_timelock),
        _config.vetoGovernorAdmin,
        _predictedCouncilGovernorAddress
      );

    vetoGovernor = new BasicCouncilVetoGovernor(_params);
    _timelock.grantRole(_timelock.EXECUTOR_ROLE(), address(vetoGovernor));
    _timelock.grantRole(_timelock.PROPOSER_ROLE(), address(vetoGovernor));
    _timelock.renounceRole(_timelock.DEFAULT_ADMIN_ROLE(), _deployer);

    vm.stopBroadcast();

    _log("vetoGovernor", address(vetoGovernor));
  }
}
