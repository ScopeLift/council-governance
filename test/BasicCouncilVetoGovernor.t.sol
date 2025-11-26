// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {BasicCouncilGovernor} from "../src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "../src/BasicCouncilVetoGovernor.sol";
import {CouncilERC20} from "../src/CouncilERC20.sol";
import {MockERC20Votes} from "./helpers/MockERC20Votes.sol";
import {Counter} from "./helpers/Counter.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

// Base contract for setting up the full two-governor test environment
abstract contract BasicCouncilVetoGovernorTest is Test {
  // === Contracts ===
  BasicCouncilGovernor internal councilGovernor;
  BasicCouncilVetoGovernor internal vetoGovernor;
  CouncilERC20 internal councilToken;
  MockERC20Votes internal daoToken;
  TimelockController internal timelock;
  Counter internal target;

  // === Users ===
  address internal deployer = makeAddr("deployer");
  address internal nonCouncilProposer = makeAddr("nonCouncilProposer");
  address[] internal councilMembers;
  address internal vetoGuardian = makeAddr("vetoGuardian");
  address internal whale1 = makeAddr("whale1");
  address internal whale2 = makeAddr("whale2");

  // === Proposal Details ===
  address[] internal targets;
  uint256[] internal values;
  bytes[] internal calldatas;

  // === Constants ===
  uint256 constant COUNCIL_SIZE = 7;
  uint256 constant TIMELOCK_MIN_DELAY = 1 days;
  uint256 constant VETO_QUORUM = 10_000e18;

  function setUp() public virtual {
    // 1. Deploy target contract
    target = new Counter();

    // 2. Deploy tokens
    vm.prank(deployer);
    councilToken = new CouncilERC20("Council Token", "CT", deployer, 1);
    vm.prank(deployer);
    daoToken = new MockERC20Votes();

    // 3. Create and fund council members for the CouncilGovernor
    for (uint256 i = 0; i < COUNCIL_SIZE; i++) {
      address member = makeAddr(string(abi.encodePacked("councilMember", vm.toString(i + 1))));
      councilMembers.push(member);
      vm.prank(deployer);
      councilToken.mint(member, 1); // 1 address = 1 vote
    }

    // 4. Create and fund DAO token holders for the VetoGovernor
    daoToken.mint(whale1, VETO_QUORUM);
    daoToken.mint(whale2, VETO_QUORUM);
    vm.prank(whale1);
    daoToken.delegate(whale1);
    vm.prank(whale2);
    daoToken.delegate(whale2);

    // --- This setup uses vm.computeCreateAddress to handle circular dependencies ---
    // The VetoGovernor needs the CouncilGovernor's address at deployment, and vice-versa.
    skip(1);
    uint256 nonce = vm.getNonce(address(deployer));
    address vetoGovernorAddress = vm.computeCreateAddress(address(deployer), nonce + 1);
    address councilGovernorAddress = vm.computeCreateAddress(address(deployer), nonce + 2);

    // 5. Deploy Timelock, giving the future VetoGovernor the PROPOSER role
    address[] memory proposers = new address[](1);
    address[] memory executors = new address[](1);
    proposers[0] = vetoGovernorAddress;
    executors[0] = address(0); // Anyone can execute

    vm.prank(deployer);
    timelock = new TimelockController(TIMELOCK_MIN_DELAY, proposers, executors, address(0));

    // 6. Deploy the Veto Governor, passing it the pre-computed council address
    vm.prank(deployer);
    vetoGovernor = new BasicCouncilVetoGovernor(
      daoToken,
      councilGovernorAddress,
      vetoGuardian,
      deployer, // Veto override role
      4 days, // Veto override duration
      timelock
    );

    // 7. Deploy the Council Governor
    vm.prank(deployer);
    councilGovernor = new BasicCouncilGovernor(councilToken, vetoGovernor);

    // 8. Prepare a sample proposal payload
    targets.push(address(target));
    values.push(0);
    calldatas.push(abi.encodeWithSignature("increment()"));
  }

  /**
   * @notice Helper function to fully propose and forward a proposal from the
   *         CouncilGovernor to the VetoGovernor, returning the VetoGovernor's proposalId.
   */
  function _proposeAndForwardToVetoGovernor(string memory _description)
    internal
    returns (uint256 vetoProposalId)
  {
    bytes32 _descriptionHash = keccak256(bytes(_description));

    // 1. Propose on Council Governor
    vm.prank(councilMembers[0]);
    uint256 councilProposalId = councilGovernor.propose(targets, values, calldatas, _description);

    // 2. Pass council vote
    skip(councilGovernor.votingDelay() + 1);
    for (uint256 i = 0; i < councilGovernor.quorum(0); i++) {
      vm.prank(councilMembers[i]);
      councilGovernor.castVote(councilProposalId, 1);
    }
    skip(councilGovernor.votingPeriod() + 1);

    // 3. Queue (forward) the proposal
    councilGovernor.queue(targets, values, calldatas, _descriptionHash);

    vetoProposalId = councilProposalId;
  }
}

// --- SMOKE TESTS ---
contract BasicCouncilVetoGovernorSmokeTest is BasicCouncilVetoGovernorTest {
  /**
   * @notice Test 1: Verifies that the veto governor is initialized correctly.
   */
  function test_SetupAndInitialization() public view {
    assertEq(vetoGovernor.COUNCIL(), address(councilGovernor));
    assertEq(vetoGovernor.vetoOverrideRole(), deployer);
    assertEq(address(vetoGovernor.timelock()), address(timelock));
  }

  /**
   * @notice Test 2: Verifies the happy path where a proposal is not vetoed and
   *         successfully queues and executes.
   */
  function test_HappyPath_ProposalSucceedsAndExecutes() public {
    uint256 proposalId = _proposeAndForwardToVetoGovernor("Succeeds");

    skip(vetoGovernor.proposalDeadline(proposalId) + 1);

    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

    // Queue in timelock
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Succeeds")));

    skip(timelock.getMinDelay() + 1);

    assertEq(target.number(), 0);

    // Execute
    councilGovernor.execute(targets, values, calldatas, keccak256(bytes("Succeeds")));

    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    assertEq(target.number(), 1, "Target contract should have been incremented");
  }

  /**
   * @notice Test 3: Verifies that a proposal is successfully vetoed when the vetoQuorum is met.
   */
  function test_VetoPath_ProposalIsSuccessfullyVetoed() public {
    uint256 proposalId = _proposeAndForwardToVetoGovernor("Vetoed");

    skip(vetoGovernor.votingDelay() + 1);

    // Cast one vote to meet the veto quorum
    vm.prank(whale1);
    vetoGovernor.castVote(proposalId, 0); // 0 = Against (Veto)

    skip(vetoGovernor.votingPeriod() + 1);

    // Assert state is Defeated
    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));

    // Verify it cannot be queued
    vm.expectRevert();
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Vetoed")));
  }

  /**
   * @notice Test 4: Verifies that a vetoed proposal can be overridden by the designated
   *         role and then successfully executed.
   */
  function test_VetoOverridePath_VetoedProposalIsOverriddenAndExecuted() public {
    uint256 proposalId = _proposeAndForwardToVetoGovernor("Overridden");

    // Veto the proposal
    skip(vetoGovernor.votingDelay() + 1);
    vm.prank(whale1);
    vetoGovernor.castVote(proposalId, 0);
    skip(vetoGovernor.votingPeriod() + 1);
    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));

    // Override the veto
    vm.prank(deployer); // `deployer` has the vetoOverrideRole
    vetoGovernor.overrideVeto(proposalId);

    // Assert the state is now Succeeded due to the override
    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

    // Now, proceed with queuing and executing
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Overridden")));
    skip(timelock.getMinDelay() + 1);
    councilGovernor.execute(targets, values, calldatas, keccak256(bytes("Overridden")));

    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));
    assertEq(target.number(), 1);
  }

  /**
   * @notice Test 5: Verifies that only the designated Council Governor can create proposals.
   */
  function test_RevertIf_NonCouncilProposes() public {
    vm.expectRevert("Only council");

    vm.prank(nonCouncilProposer);
    vetoGovernor.propose(targets, values, calldatas, "Invalid Proposal");
  }

  function test_RevertIf_CancelAPendingProposal() public {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor("Overridden");

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Pending));

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnableToCancel.selector, _proposalId, councilMembers[0]
      )
    );
    vm.prank(councilMembers[0]);
    vetoGovernor.cancel(targets, values, calldatas, keccak256(bytes("Overridden")));
  }
}
