// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {CouncilERC20} from "src/CouncilERC20.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {CompoundCouncilVetoGovernor} from "src/CompoundCouncilVetoGovernor.sol";

import {Test} from "forge-std/Test.sol";
import {DeployCouncilGovernance} from "script/DeployCouncilGovernance.s.sol";
import {DeployCouncilGovernanceTest} from "script/DeployCouncilGovernanceTest.s.sol";
import {
  DeployCouncilGovernanceTestCompound
} from "script/DeployCouncilGovernanceTestCompound.s.sol";
import {MockERC20Votes} from "test/helpers/MockERC20Votes.sol";

contract OptimisticGovernanceDeployment is Test {
  CouncilERC20 public councilToken;
  TimelockController public timelock;
  BasicCouncilVetoGovernor public vetoGovernor;
  BasicCouncilGovernor public councilGovernor;

  function test_DeploysErc5805System() public {
    MockERC20Votes _daoToken = new MockERC20Votes();
    _daoToken.mint(address(this), 1e18);

    DeployCouncilGovernanceTest _deploy = new DeployCouncilGovernanceTest(_daoToken, address(this));
    _deploy.disableLogging();
    _deploy.run();

    councilToken = _deploy.councilToken();
    timelock = _deploy.timelock();
    councilGovernor = _deploy.councilGovernor();
    vetoGovernor = _deploy.vetoGovernor();

    _assertCouncilToken();
    _assertTimelock();
    _assertCouncilGovernor();
    _assertErc5805VetoGovernor();
    _assertRoles();
  }

  function test_DeploysLegacyCompoundSystem() public {
    string memory _rpcUrl = vm.rpcUrl("mainnet");
    uint256 _forkBlock = 23_810_240;
    vm.createSelectFork(_rpcUrl, _forkBlock);

    DeployCouncilGovernanceTestCompound _deploy =
      new DeployCouncilGovernanceTestCompound(address(this));
    _deploy.disableLogging();
    _deploy.run();

    councilToken = _deploy.councilToken();
    timelock = _deploy.timelock();
    councilGovernor = _deploy.councilGovernor();
    vetoGovernor = _deploy.vetoGovernor();

    assertEq(vetoGovernor.clock(), block.number, "veto governor should use block clock");
    assertNotEq(vetoGovernor.clock(), block.timestamp, "veto governor should NOT use timestamp");

    _assertCouncilToken();
    _assertTimelock();
    _assertCouncilGovernor();
    _assertCompoundVetoGovernor();
    _assertRoles();
  }

  function _assertCouncilToken() internal view {
    assertEq(councilToken.name(), "Optimistic Council");
    assertEq(councilToken.symbol(), "OC");
    assertEq(councilToken.MAX_TOKENS_PER_MEMBER(), 1);
    assertEq(councilToken.totalSupply(), 7);

    address[7] memory _members = [
      address(bytes20("council member 0")),
      address(bytes20("council member 1")),
      address(bytes20("council member 2")),
      address(bytes20("council member 3")),
      address(bytes20("council member 4")),
      address(bytes20("council member 5")),
      address(bytes20("council member 6"))
    ];
    for (uint256 _i = 0; _i < 7; _i++) {
      assertEq(councilToken.balanceOf(_members[_i]), 1);
      assertEq(councilToken.delegates(_members[_i]), _members[_i]);
    }
  }

  function _assertTimelock() internal view {
    assertEq(timelock.getMinDelay(), 1 days);
  }

  function _assertCouncilGovernor() internal view {
    assertEq(councilGovernor.name(), "BasicCouncilGovernor");
    assertEq(address(councilGovernor.token()), address(councilToken));
    assertEq(address(councilGovernor.councilVetoGovernor()), address(vetoGovernor));
    assertEq(councilGovernor.votingDelay(), 1 days);
    assertEq(councilGovernor.votingPeriod(), 1 weeks);
    assertEq(councilGovernor.proposalThreshold(), 1);
  }

  function _assertErc5805VetoGovernor() internal view {
    assertEq(vetoGovernor.name(), "BasicCouncilVetoGovernor");
    assertEq(vetoGovernor.COUNCIL(), address(councilGovernor));
    assertEq(address(vetoGovernor.timelock()), address(timelock));
    assertEq(vetoGovernor.votingDelay(), 1 hours);
    assertEq(vetoGovernor.votingPeriod(), 1 days);
    assertEq(vetoGovernor.proposalThreshold(), 0);
  }

  function _assertCompoundVetoGovernor() internal view {
    assertEq(vetoGovernor.name(), "CompoundCouncilVetoGovernor");
    assertEq(vetoGovernor.COUNCIL(), address(councilGovernor));
    assertEq(address(vetoGovernor.timelock()), address(timelock));
    assertEq(vetoGovernor.votingDelay(), 300);
    assertEq(vetoGovernor.votingPeriod(), 7200);
    assertEq(vetoGovernor.proposalThreshold(), 0);
  }

  function _assertRoles() internal view {
    assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(vetoGovernor)));
    assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(vetoGovernor)));
    assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(this)));
  }
}
