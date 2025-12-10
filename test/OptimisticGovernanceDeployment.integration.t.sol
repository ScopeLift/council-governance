// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External imports
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Internal imports
import {CouncilERC20} from "src/CouncilERC20.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";

// Test imports
import {Test} from "forge-std/Test.sol";
import {DeployAndMintCouncilERC20} from "script/DeployAndMintCouncilERC20.s.sol";
import {DeployTimelock} from "script/DeployTimelock.s.sol";
import {DeployVetoGovernor} from "script/DeployVetoGovernor.s.sol";
import {DeployCouncilGovernor} from "script/DeployCouncilGovernor.s.sol";
import {DeploymentConfigurationLocal} from "script/DeploymentConfigurationLocal.sol";
import {DeploymentInputLocal} from "script/DeploymentInputLocal.sol";

/// @title Integration test for the Optimistic Governance deployment
/// @notice This test exercises the entire deployment flow with verification after each phase.
/// @dev This test suite requires MAINNET_RPC_URL environment variable to be set
contract OptimisticGovernanceDeployment is Test {
  CouncilERC20 public councilToken;
  TimelockController public timelock;
  BasicCouncilVetoGovernor public vetoGovernor;
  BasicCouncilGovernor public councilGovernor;

  DeploymentInputLocal input;
  DeploymentConfigurationLocal config;
  address deployer;

  function setUp() public {
    string memory _rpcUrl = vm.rpcUrl("mainnet");
    uint256 _forkBlock = 23_810_240;
    vm.createSelectFork(_rpcUrl, _forkBlock);

    input = new DeploymentInputLocal();
    config = new DeploymentConfigurationLocal();

    deployer = input.MAIN_DAO_GOVERNOR();
  }

  /*///////////////////////////////////////////////////////////////
                      Helper Functions
  //////////////////////////////////////////////////////////////*/

  /// @dev Run this for integration test setup.
  function runDeployScriptsForIntegrationTest()
    external
    returns (CouncilERC20, TimelockController, BasicCouncilVetoGovernor, BasicCouncilGovernor)
  {
    if (address(councilGovernor) == address(0)) {
      _step1_deployCouncilTokenAndMint();
      _step2_deployTimelock();
      _step3_deployVetoGovernorAndGrantRoles();
      _step4_deployCouncilGovernor();
      _step5_grantVetoGovernorRoles();
    }
    return (councilToken, timelock, vetoGovernor, councilGovernor);
  }

  /*///////////////////////////////////////////////////////////////
                      Test Functions
  //////////////////////////////////////////////////////////////*/

  function _step1_deployCouncilTokenAndMint() internal {
    require(address(councilToken) == address(0), "Council token already deployed");
    DeploymentConfigurationLocal.CouncilERC20DeploymentConfiguration memory _config =
      config._getCouncilERC20DeploymentConfiguration();

    DeployAndMintCouncilERC20 _script = new DeployAndMintCouncilERC20();
    _script.setLoggingSilenced(true);
    councilToken = _script.run(deployer, _config);
  }

  function _step2_deployTimelock() internal {
    require(address(timelock) == address(0), "Timelock already deployed");
    DeploymentConfigurationLocal.TimelockDeploymentConfiguration memory _config =
      config._getTimelockDeploymentConfiguration();
    DeployTimelock _script = new DeployTimelock();
    _script.setLoggingSilenced(true);
    timelock = _script.run(deployer, _config);
  }

  function _step3_deployVetoGovernorAndGrantRoles() internal {
    require(address(vetoGovernor) == address(0), "Veto governor already deployed");
    require(address(timelock) != address(0), "Timelock must be deployed first");

    DeploymentConfigurationLocal.VetoGovernorDeploymentConfiguration memory _config =
      config._getVetoGovernorDeploymentConfiguration();
    DeployVetoGovernor _script = new DeployVetoGovernor();
    _script.setLoggingSilenced(true);
    address _predictedCouncilGovernorAddress = _script.predictCouncilGovernorAddress(deployer);
    vetoGovernor = _script.run(deployer, timelock, _config, _predictedCouncilGovernorAddress);
  }

  function _step4_deployCouncilGovernor() internal {
    require(address(councilGovernor) == address(0), "Council governor already deployed");
    require(address(councilToken) != address(0), "Council token must be deployed first");
    require(address(vetoGovernor) != address(0), "Veto governor must be deployed first");

    DeploymentConfigurationLocal.CouncilGovernorDeploymentConfiguration memory _config =
      config._getCouncilGovernorDeploymentConfiguration();
    DeployCouncilGovernor _script = new DeployCouncilGovernor();
    _script.setLoggingSilenced(true);
    councilGovernor = _script.run(deployer, councilToken, vetoGovernor, _config);
  }

  function _step5_grantVetoGovernorRoles() internal {
    DeployVetoGovernor _script = new DeployVetoGovernor();
    _script.grantVetoGovernorRoles(deployer, vetoGovernor, timelock);
  }

  /// @notice Test the complete deployment flow with verification after each phase.
  function test_CompleteCouncilGovernanceWorkflow() public {
    // Step 1: Deploy the council token and distribute seats.
    _step1_deployCouncilTokenAndMint();

    // Verify Step 1
    assertEq(councilToken.name(), input.COUNCIL_TOKEN_NAME());
    assertEq(councilToken.symbol(), input.COUNCIL_TOKEN_SYMBOL());
    assertEq(councilToken.owner(), input.MAIN_DAO_GOVERNOR());
    assertEq(councilToken.MAX_TOKENS_PER_MEMBER(), input.MAX_TOKENS_PER_MEMBER());
    for (uint256 _i = 0; _i < input.COUNCIL_MEMBERS_LENGTH(); _i++) {
      assertEq(councilToken.balanceOf(input.COUNCIL_MEMBERS(_i)), input.MAX_TOKENS_PER_MEMBER());
    }

    // Step 2: Deploy the veto timelock and confirm parameters.
    _step2_deployTimelock();

    // Verify Step 2
    assertEq(timelock.getMinDelay(), input.TIMELOCK_MIN_DELAY());

    // Step 3: Deploy the veto governor and ensure wiring to the timelock.
    _step3_deployVetoGovernorAndGrantRoles();

    // Verify Step 3
    assertEq(vetoGovernor.name(), input.VETO_GOVERNOR_NAME());
    assertEq(address(vetoGovernor.token()), address(input.MAIN_DAO_TOKEN()));
    assertEq(vetoGovernor.votingDelay(), input.VETO_GOVERNOR_INITIAL_VOTING_DELAY());
    assertEq(vetoGovernor.votingPeriod(), input.VETO_GOVERNOR_INITIAL_VOTING_PERIOD());
    assertEq(vetoGovernor.proposalThreshold(), input.VETO_GOVERNOR_INITIAL_PROPOSAL_THRESHOLD());
    assertEq(vetoGovernor.vetoOverrideRole(), input.VETO_OVERRIDE_ROLE());
    assertEq(vetoGovernor.vetoOverrideDuration(), input.VETO_OVERRIDE_DURATION());
    assertEq(vetoGovernor.vetoGuardian(), input.VETO_GUARDIAN());
    assertEq(address(vetoGovernor.timelock()), address(timelock));
    assertEq(vetoGovernor.owner(), input.GOVERNOR_ADMIN());

    // Step 4: Deploy the council governor and ensure linkage to the veto governor.
    _step4_deployCouncilGovernor();

    // Verify Step 4
    assertEq(vetoGovernor.COUNCIL(), address(councilGovernor));

    assertEq(councilGovernor.name(), input.COUNCIL_GOVERNOR_NAME());
    assertEq(address(councilGovernor.token()), address(councilToken));
    assertEq(address(councilGovernor.councilVetoGovernor()), address(vetoGovernor));
    assertEq(councilGovernor.votingDelay(), input.COUNCIL_GOVERNOR_INITIAL_VOTING_DELAY());
    assertEq(councilGovernor.votingPeriod(), input.COUNCIL_GOVERNOR_INITIAL_VOTING_PERIOD());
    assertEq(
      councilGovernor.proposalThreshold(), input.COUNCIL_GOVERNOR_INITIAL_PROPOSAL_THRESHOLD()
    );
    assertEq(councilGovernor.owner(), input.GOVERNOR_ADMIN());

    // Step 5: Grant veto governor proposer and executor roles, remove deployer's default role.
    _step5_grantVetoGovernorRoles();

    // Verify Step 5
    assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(vetoGovernor)));
    assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(vetoGovernor)));
    assertFalse(timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), address(deployer)));
  }
}
