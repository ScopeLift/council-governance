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

/// @title Integration test for the Optimistic Governance deployment
/// @notice This test exercises the entire deployment flow with verification after each phase.
/// @dev This test suite requires MAINNET_RPC_URL environment variable to be set
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
    string memory _rpcUrl = vm.rpcUrl("mainnet");
    uint256 _forkBlock = 23_810_240;
    vm.createSelectFork(_rpcUrl, _forkBlock);

    baseInput = new OptimisticGovernanceDeployInput();
    councilERC20Input = new CouncilERC20DeployInput();
    timelockInput = new TimelockDeployInput();
    councilInput = new CouncilGovernorDeployInput();
    vetoInput = new VetoGovernorDeployInput();
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
      _step3_deployVetoGovernor();
      _step4_deployCouncilGovernor();
    }
    return (councilToken, timelock, vetoGovernor, councilGovernor);
  }

  /*///////////////////////////////////////////////////////////////
                      Test Functions
  //////////////////////////////////////////////////////////////*/

  function _step1_deployCouncilTokenAndMint() internal {
    require(address(councilToken) == address(0), "Council token already deployed");

    DeployAndMintCouncilERC20 _script = new DeployAndMintCouncilERC20();
    _script.setLoggingSilenced(true);
    councilToken = _script.run(baseInput.MAIN_DAO_GOVERNOR());
  }

  function _step2_deployTimelock() internal {
    require(address(timelock) == address(0), "Timelock already deployed");

    DeployTimelock _script = new DeployTimelock();
    _script.setLoggingSilenced(true);
    timelock = _script.run(baseInput.MAIN_DAO_GOVERNOR());
  }

  function _step3_deployVetoGovernor() internal {
    require(address(vetoGovernor) == address(0), "Veto governor already deployed");
    require(address(timelock) != address(0), "Timelock must be deployed first");

    DeployVetoGovernor _script = new DeployVetoGovernor();
    _script.setLoggingSilenced(true);
    vetoGovernor = _script.run(baseInput.MAIN_DAO_GOVERNOR(), timelock);
  }

  function _step4_deployCouncilGovernor() internal {
    require(address(councilGovernor) == address(0), "Council governor already deployed");
    require(address(councilToken) != address(0), "Council token must be deployed first");
    require(address(vetoGovernor) != address(0), "Veto governor must be deployed first");

    DeployCouncilGovernor _script = new DeployCouncilGovernor();
    _script.setLoggingSilenced(true);
    councilGovernor = _script.run(baseInput.MAIN_DAO_GOVERNOR(), councilToken, vetoGovernor);
  }

  /// @notice Test the complete deployment flow with verification after each phase.
  function test_CompleteCouncilGovernanceWorkflow() public {
    // Step 1: Deploy the council token and distribute seats.
    _step1_deployCouncilTokenAndMint();

    // Verify Step 1
    assertEq(councilToken.name(), councilERC20Input.NAME());
    assertEq(councilToken.symbol(), councilERC20Input.SYMBOL());
    assertEq(councilToken.owner(), councilERC20Input.MAIN_DAO_GOVERNOR());
    for (uint256 _i = 0; _i < councilERC20Input.COUNCIL_MEMBERS_LENGTH(); _i++) {
      assertEq(
        councilToken.balanceOf(councilERC20Input.COUNCIL_MEMBERS(_i)),
        councilERC20Input.MAX_TOKENS_PER_MEMBER()
      );
    }

    // Step 2: Deploy the veto timelock and confirm parameters.
    _step2_deployTimelock();

    // Verify Step 2
    assertEq(timelock.getMinDelay(), timelockInput.TIMELOCK_MIN_DELAY());

    // Step 3: Deploy the veto governor and ensure wiring to the timelock.
    _step3_deployVetoGovernor();

    // Verify Step 3
    assertEq(vetoGovernor.name(), vetoInput.VETO_GOVERNOR_NAME());
    assertEq(address(vetoGovernor.token()), address(vetoInput.MAIN_DAO_TOKEN()));
    assertEq(vetoGovernor.votingDelay(), vetoInput.INITIAL_VETO_GOVERNOR_VOTING_DELAY());
    assertEq(vetoGovernor.votingPeriod(), vetoInput.INITIAL_VETO_GOVERNOR_VOTING_PERIOD());
    assertEq(vetoGovernor.proposalThreshold(), vetoInput.INITIAL_VETO_GOVERNOR_PROPOSAL_THRESHOLD());
    assertEq(vetoGovernor.vetoOverrideRole(), vetoInput.VETO_OVERRIDE_ROLE());
    assertEq(vetoGovernor.vetoOverrideDuration(), vetoInput.VETO_OVERRIDE_DURATION());
    assertEq(address(vetoGovernor.timelock()), address(timelock));

    // Step 4: Deploy the council governor and ensure linkage to the veto governor.
    _step4_deployCouncilGovernor();

    // Verify Step 4
    assertEq(councilGovernor.name(), councilInput.COUNCIL_GOVERNOR_NAME());
    assertEq(address(councilGovernor.token()), address(councilToken));
    assertEq(address(councilGovernor.councilVetoGovernor()), address(vetoGovernor));
    assertEq(councilGovernor.votingDelay(), councilInput.INITIAL_COUNCIL_GOVERNOR_VOTING_DELAY());
    assertEq(councilGovernor.votingPeriod(), councilInput.INITIAL_COUNCIL_GOVERNOR_VOTING_PERIOD());
    assertEq(
      councilGovernor.proposalThreshold(),
      councilInput.INITIAL_COUNCIL_GOVERNOR_PROPOSAL_THRESHOLD()
    );
    assertEq(vetoGovernor.COUNCIL(), address(councilGovernor));
  }
}
