// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";
import {
  DeployErc5805CouncilGovernanceTestConfig
} from "script/test/DeployErc5805CouncilGovernanceTestConfig.s.sol";
import {
  DeployLegacyCompoundCouncilGovernanceTestConfig
} from "script/test/DeployLegacyCompoundCouncilGovernanceTestConfig.s.sol";

contract DeployCouncilGovernanceIntegrationTest is Test {
  uint256 internal constant MAINNET_FORK_BLOCK = 23_810_240;

  function test_DeploysCompleteTimestampClockSystem() public {
    DeployErc5805CouncilGovernanceTestConfig _deploy =
      new DeployErc5805CouncilGovernanceTestConfig();
    _deploy.disableLogging();
    _deploy.run();

    _assertCommonDeployment(
      _deploy.councilToken(), _deploy.timelock(), _deploy.councilGovernor(), _deploy.vetoGovernor()
    );
    assertEq(_deploy.vetoGovernor().CLOCK_MODE(), "mode=timestamp");
  }

  function test_DeploysCompleteLegacyCompoundSystem() public {
    vm.createSelectFork(vm.rpcUrl("mainnet"), MAINNET_FORK_BLOCK);
    DeployLegacyCompoundCouncilGovernanceTestConfig _deploy =
      new DeployLegacyCompoundCouncilGovernanceTestConfig();
    _deploy.disableLogging();
    _deploy.run();

    _assertCommonDeployment(
      _deploy.councilToken(), _deploy.timelock(), _deploy.councilGovernor(), _deploy.vetoGovernor()
    );
    assertEq(_deploy.vetoGovernor().CLOCK_MODE(), "mode=blocknumber&from=default");
  }

  function _assertCommonDeployment(
    CouncilERC20 _token,
    TimelockController _timelock,
    BasicCouncilGovernor _councilGovernor,
    BasicCouncilVetoGovernor _vetoGovernor
  ) internal view {
    assertEq(address(_councilGovernor.token()), address(_token));
    assertEq(_token.owner(), address(0xA11CE));
    assertEq(address(_councilGovernor.councilVetoGovernor()), address(_vetoGovernor));
    assertEq(address(_vetoGovernor.timelock()), address(_timelock));
    assertEq(_vetoGovernor.COUNCIL(), address(_councilGovernor));
    assertTrue(_timelock.hasRole(_timelock.PROPOSER_ROLE(), address(_vetoGovernor)));
    assertTrue(_timelock.hasRole(_timelock.EXECUTOR_ROLE(), address(_vetoGovernor)));
    assertTrue(_timelock.hasRole(_timelock.DEFAULT_ADMIN_ROLE(), address(_timelock)));
    assertFalse(_timelock.hasRole(_timelock.CANCELLER_ROLE(), address(_councilGovernor)));
    assertFalse(_timelock.hasRole(_timelock.CANCELLER_ROLE(), address(_vetoGovernor)));
  }
}
