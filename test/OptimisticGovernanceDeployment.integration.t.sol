// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";

import {DeployAndMintCouncilERC20} from "script/1_DeployAndMintCouncilERC20.s.sol";
import {DeployTimelock} from "script/2_DeployTimelock.s.sol";
import {DeployVetoGovernor} from "script/3_DeployVetoGovernor.s.sol";
import {DeployCouncilGovernor} from "script/4_DeployCouncilGovernor.s.sol";
import {
  OptimisticGovernanceDeployInput,
  CouncilERC20DeployInput,
  TimelockDeployInput,
  VetoGovernorDeployInput,
  CouncilGovernorDeployInput
} from "script/DeployInput.sol";

contract OptimisticGovernanceDeployment is Test {
  CouncilERC20 public councilToken;
  TimelockController public timelock;
  BasicCouncilVetoGovernor public vetoGovernor;
  BasicCouncilGovernor public councilGovernor;

  OptimisticGovernanceDeployInput baseInput;
  CouncilERC20DeployInput councilERC20Input;
  TimelockDeployInput timelockInput;
  CouncilGovernorDeployInput councilInput;
  VetoGovernorDeployInput vetoInput;

  function setUp() public {
    string memory rpcUrl = vm.rpcUrl("mainnet");
    uint256 forkBlock = 23_810_240;
    vm.createSelectFork(rpcUrl, forkBlock);

    baseInput = new OptimisticGovernanceDeployInput();
    councilERC20Input = new CouncilERC20DeployInput();
    timelockInput = new TimelockDeployInput();
    councilInput = new CouncilGovernorDeployInput();
    vetoInput = new VetoGovernorDeployInput();

    DeployAndMintCouncilERC20 councilERC20Script = new DeployAndMintCouncilERC20();
    DeployTimelock timelockScript = new DeployTimelock();
    DeployVetoGovernor vetoGovernorScript = new DeployVetoGovernor();
    DeployCouncilGovernor councilGovernorScript = new DeployCouncilGovernor();

    councilToken = councilERC20Script.run(baseInput.MAIN_DAO_GOVERNOR());
    timelock = timelockScript.run(baseInput.MAIN_DAO_GOVERNOR());
    vetoGovernor = vetoGovernorScript.run(baseInput.MAIN_DAO_GOVERNOR(), timelock);
    councilGovernor =
      councilGovernorScript.run(baseInput.MAIN_DAO_GOVERNOR(), councilToken, vetoGovernor);
  }

  function test_CouncilERC20TokenParams() public view {
    assertEq(councilToken.name(), councilERC20Input.NAME());
    assertEq(councilToken.symbol(), councilERC20Input.SYMBOL());
    assertEq(councilToken.owner(), councilERC20Input.MAIN_DAO_GOVERNOR());
    assertEq(councilToken.MAX_TOKENS_PER_MEMBER(), councilERC20Input.MAX_TOKENS_PER_MEMBER());
    for (uint256 i = 0; i < councilERC20Input.COUNCIL_MEMBERS_LENGTH(); i++) {
      assertEq(
        councilToken.balanceOf(councilERC20Input.COUNCIL_MEMBERS(i)),
        councilERC20Input.MAX_TOKENS_PER_MEMBER()
      );
    }
  }

  function test_TimelockParams() public view {
    assertEq(timelock.getMinDelay(), timelockInput.TIMELOCK_MIN_DELAY());
  }

  function test_CouncilGovernorParams() public view {
    assertEq(councilGovernor.name(), councilInput.COUNCIL_GOVERNOR_NAME());
    assertEq(address(councilGovernor.token()), address(councilToken));
    assertEq(address(councilGovernor.councilVetoGovernor()), address(vetoGovernor));
    assertEq(councilGovernor.votingDelay(), councilInput.INITIAL_COUNCIL_GOVERNOR_VOTING_DELAY());
    assertEq(councilGovernor.votingPeriod(), councilInput.INITIAL_COUNCIL_GOVERNOR_VOTING_PERIOD());
    assertEq(
      councilGovernor.proposalThreshold(),
      councilInput.INITIAL_COUNCIL_GOVERNOR_PROPOSAL_THRESHOLD()
    );
    assertEq(councilGovernor.owner(), councilInput.GOVERNOR_ADMIN());
  }

  function test_VetoGovernorParams() public view {
    assertEq(vetoGovernor.name(), vetoInput.VETO_GOVERNOR_NAME());
    assertEq(address(vetoGovernor.token()), address(vetoInput.MAIN_DAO_TOKEN()));
    assertEq(vetoGovernor.votingDelay(), vetoInput.INITIAL_VETO_GOVERNOR_VOTING_DELAY());
    assertEq(vetoGovernor.votingPeriod(), vetoInput.INITIAL_VETO_GOVERNOR_VOTING_PERIOD());
    assertEq(vetoGovernor.proposalThreshold(), vetoInput.INITIAL_VETO_GOVERNOR_PROPOSAL_THRESHOLD());
    assertEq(vetoGovernor.vetoOverrideRole(), vetoInput.VETO_OVERRIDE_ROLE());
    assertEq(vetoGovernor.vetoOverrideDuration(), vetoInput.VETO_OVERRIDE_DURATION());
    assertEq(vetoGovernor.vetoGuardian(), vetoInput.VETO_GUARDIAN());
    assertEq(address(vetoGovernor.timelock()), address(timelock));
    assertEq(vetoGovernor.owner(), vetoInput.GOVERNOR_ADMIN());
    assertEq(vetoGovernor.COUNCIL(), address(councilGovernor));
  }
}
