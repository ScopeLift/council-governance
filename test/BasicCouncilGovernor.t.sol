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

// Base contract for setting up the test environment
abstract contract BasicCouncilGovernorTest is Test {
  // === Contracts ===
  BasicCouncilGovernor internal councilGovernor;
  BasicCouncilVetoGovernor internal vetoGovernor;
  CouncilERC20 internal councilToken;
  MockERC20Votes internal daoToken;
  TimelockController internal timelock;
  Counter internal target;

  // === Users ===
  address internal deployer = makeAddr("deployer");
  address internal nonCouncilMember = makeAddr("nonCouncilMember");
  address[] internal councilMembers;

  // === Proposal Details ===
  address[] internal targets;
  uint256[] internal values;
  bytes[] internal calldatas;
  string internal description = "Proposal to increment Counter";
  bytes32 internal descriptionHash;

  // === Constants ===
  uint256 constant COUNCIL_SIZE = 7;
  uint256 constant TIMELOCK_MIN_DELAY = 1 days;

  function setUp() public virtual {
    // 1. Deploy target contract
    target = new Counter();

    // 2. Deploy tokens
    vm.prank(deployer);
    councilToken = new CouncilERC20("Council Token", "CT", deployer, 1);
    vm.prank(deployer);
    daoToken = new MockERC20Votes();

    // 3. Create and fund council members
    for (uint256 i = 0; i < COUNCIL_SIZE; i++) {
      address member = makeAddr(string(abi.encodePacked("councilMember", vm.toString(i + 1))));
      councilMembers.push(member);
      vm.prank(deployer);
      councilToken.mint(member, 1); // 1 address = 1 vote
    }
    skip(1);
    uint256 nonce = vm.getNonce(address(deployer));
    address vetoGovernorAddress = vm.computeCreateAddress(address(deployer), nonce + 1);
    address councilGovernorAddress = vm.computeCreateAddress(address(deployer), nonce + 2);
    // 4. Deploy Timelock and Veto Governor
    address[] memory proposers = new address[](1);
    address[] memory executors = new address[](1);
    proposers[0] = vetoGovernorAddress;
    executors[0] = vetoGovernorAddress;

    vm.prank(deployer);
    timelock = new TimelockController(TIMELOCK_MIN_DELAY, proposers, executors, address(0));

    vm.prank(deployer);
    vetoGovernor = new BasicCouncilVetoGovernor(
      daoToken,
      councilGovernorAddress,
      deployer, // Veto override role
      4 days, // Veto override duration
      timelock
    );

    // 5. Deploy the Council Governor
    vm.prank(deployer);
    councilGovernor = new BasicCouncilGovernor(councilToken, vetoGovernor);

    // 6. Prepare a sample proposal payload
    targets.push(address(target));
    values.push(0);
    calldatas.push(abi.encodeWithSignature("increment()"));
    descriptionHash = keccak256(bytes(description));
  }
}

// --- SMOKE TESTS ---
contract BasicCouncilGovernorSmokeTest is BasicCouncilGovernorTest {
  /**
   * @notice Test 1: Verifies that the governor is initialized with the correct state variables.
   */
  function test_SetupAndInitialization() public view {
    assertEq(councilGovernor.name(), "BasicCouncilGovernor");
    assertEq(address(councilGovernor.token()), address(councilToken));
    assertEq(address(councilGovernor.councilVetoGovernor()), address(vetoGovernor));
  }

  /**
   * @notice Test 2: Verifies the happy path where a council proposes and passes a vote,
   *         and the proposal state becomes `Succeeded`.
   */
  function test_HappyPath_CouncilProposesAndPasses() public {
    // Propose
    vm.prank(councilMembers[0]);
    uint256 proposalId = councilGovernor.propose(targets, values, calldatas, description);

    // Warp past voting delay to make proposal Active
    skip(councilGovernor.votingDelay() + 1);

    // Cast votes to meet quorum (4)
    for (uint256 i = 0; i < councilGovernor.quorum(0); i++) {
      vm.prank(councilMembers[i]);
      councilGovernor.castVote(proposalId, 1); // 1 = For
    }

    // Warp past voting period to end the vote
    skip(councilGovernor.votingPeriod() + 1);

    // Assert state is Succeeded
    assertEq(uint8(councilGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));
  }

  /**
   * @notice Test 3: Verifies that a `Succeeded` proposal, when queued, correctly
   *         forwards the proposal to the Veto Governor.
   */
  function test_HappyPath_SuccessfulProposalIsForwardedToVetoGovernor() public {
    // Propose and pass the council vote
    vm.prank(councilMembers[0]);
    uint256 proposalId = councilGovernor.propose(targets, values, calldatas, description);
    vm.warp(block.timestamp + councilGovernor.votingDelay() + 1);
    for (uint256 i = 0; i < councilGovernor.quorum(0); i++) {
      vm.prank(councilMembers[i]);
      councilGovernor.castVote(proposalId, 1);
    }
    vm.warp(block.timestamp + councilGovernor.votingPeriod() + 1);
    assertEq(uint8(councilGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

    // Expect a `propose` call on the Veto Governor
    vm.expectCall(
      address(vetoGovernor),
      abi.encodeWithSelector(vetoGovernor.propose.selector, targets, values, calldatas, description)
    );

    // Queue the proposal, which triggers the forwarding
    councilGovernor.queue(targets, values, calldatas, descriptionHash);

    // Assert the state is now `Queued` (which means "Forwarded" in this context)
    assertEq(uint8(councilGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));
  }

  /**
   * @notice Test 4: Verifies that meeting the `superQuorum` immediately moves the
   *         proposal to the `Succeeded` state, ready for forwarding.
   */
  function test_HappyPath_SuperQuorumFastTracksProposal() public {
    // Propose
    vm.prank(councilMembers[0]);
    uint256 proposalId = councilGovernor.propose(targets, values, calldatas, description);

    // Warp past voting delay
    vm.warp(block.timestamp + councilGovernor.votingDelay() + 1);

    // Cast votes to meet superQuorum (7)
    for (uint256 i = 0; i < councilGovernor.superQuorum(0); i++) {
      vm.prank(councilMembers[i]);
      councilGovernor.castVote(proposalId, 1); // 1 = For
    }

    // Assert state is *immediately* Succeeded, without warping past the voting period
    assertEq(uint8(councilGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

    // Verify it can now be queued (forwarded)
    vm.expectCall(
      address(vetoGovernor),
      abi.encodeWithSelector(vetoGovernor.propose.selector, targets, values, calldatas, description)
    );
    councilGovernor.queue(targets, values, calldatas, descriptionHash);
  }

  /**
   * @notice Test 5: Verifies that an address without a council token cannot create a proposal.
   */
  function test_RevertIf_NonCouncilMemberProposes() public {
    // Check that the non-council member has 0 votes
    assertEq(councilToken.getVotes(nonCouncilMember), 0);

    // OpenZeppelin Governor reverts with this error when the proposer has insufficient votes.
    // In our case, the threshold is 0, but `_canPropose` is implicitly overridden by our setup,
    // so we check if the proposer's voting weight is > 0.
    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorInsufficientProposerVotes.selector,
        nonCouncilMember,
        0,
        councilGovernor.proposalThreshold()
      )
    );

    // Attempt to propose
    vm.prank(nonCouncilMember);
    councilGovernor.propose(targets, values, calldatas, description);
  }

  function test_CancelsAPendingProposal() public {
    vm.prank(councilMembers[0]);
    uint256 proposalId = councilGovernor.propose(targets, values, calldatas, description);

    skip(1);

    vm.prank(councilMembers[0]);
    councilGovernor.cancel(targets, values, calldatas, descriptionHash);

    assertEq(uint8(councilGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Canceled));
  }

  function test_RevertsIf_CancelsAForwardedProposal() public {
    vm.prank(councilMembers[0]);
    uint256 proposalId = councilGovernor.propose(targets, values, calldatas, description);
    vm.warp(block.timestamp + councilGovernor.votingDelay() + 1);
    for (uint256 i = 0; i < councilGovernor.quorum(0); i++) {
      vm.prank(councilMembers[i]);
      councilGovernor.castVote(proposalId, 1);
    }
    vm.warp(block.timestamp + councilGovernor.votingPeriod() + 1);

    // Queue the proposal, which triggers the forwarding
    councilGovernor.queue(targets, values, calldatas, descriptionHash);

    // Assert the state is now `Queued` (which means "Forwarded" in this context)
    assertEq(uint8(councilGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));
    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnableToCancel.selector, proposalId, councilMembers[0]
      )
    );
    vm.prank(councilMembers[0]);
    councilGovernor.cancel(targets, values, calldatas, descriptionHash);
  }
}
