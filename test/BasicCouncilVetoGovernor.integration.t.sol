// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

// External Dependencies
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Internal Dependencies
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";

// Test Dependencies
import {Test} from "forge-std/Test.sol";
import {Counter} from "test/helpers/Counter.sol";
import {MockERC20Votes} from "test/helpers/MockERC20Votes.sol";
import {MockERC20VotesBlockNumber} from "test/helpers/MockERC20VotesBlockNumber.sol";
import {MockERC20VotesNoClock} from "test/helpers/MockERC20VotesNoClock.sol";

abstract contract BasicCouncilVetoGovernorTest is Test {
  BasicCouncilGovernor internal councilGovernor;
  BasicCouncilVetoGovernor internal vetoGovernor;
  CouncilERC20 internal councilToken;
  address internal daoTokenAddress;
  TimelockController internal timelock;
  Counter internal target;

  address internal deployer = makeAddr("deployer");
  address internal nonCouncilProposer = makeAddr("nonCouncilProposer");
  address[] internal councilMembers;
  address internal vetoGuardian = makeAddr("vetoGuardian");
  address internal whale1 = makeAddr("whale1");
  address internal whale2 = makeAddr("whale2");

  address[] internal targets;
  uint256[] internal values;
  bytes[] internal calldatas;

  uint256 constant COUNCIL_SIZE = 7;
  uint256 constant TIMELOCK_MIN_DELAY = 1 days;
  uint256 constant VETO_QUORUM = 10_000e18;

  function _deployDaoToken() internal virtual returns (address);

  function _vetoGovernorParams()
    internal
    view
    virtual
    returns (BasicCouncilVetoGovernor.ConstructorParams memory);

  function _advanceTo(uint256 timepoint) internal virtual;

  function setUp() public virtual {
    target = new Counter();

    vm.prank(deployer);
    councilToken = new CouncilERC20("Council Token", "CT", deployer, 1);

    daoTokenAddress = _deployDaoToken();

    for (uint256 _i = 0; _i < COUNCIL_SIZE; _i++) {
      address _member = makeAddr(string(abi.encodePacked("councilMember", vm.toString(_i + 1))));
      councilMembers.push(_member);
      vm.prank(deployer);
      councilToken.mint(_member, 1);
    }

    // DAO token holders — mint with auto-delegate when mock supports it
    _mintDaoTokens(whale1, VETO_QUORUM);
    _mintDaoTokens(whale2, VETO_QUORUM);

    skip(1);
    uint256 _nonce = vm.getNonce(address(deployer));
    address _vetoGovernorAddress = vm.computeCreateAddress(address(deployer), _nonce + 1);
    address _councilGovernorAddress = vm.computeCreateAddress(address(deployer), _nonce + 2);

    address[] memory _proposers = new address[](1);
    address[] memory _executors = new address[](1);
    _proposers[0] = _vetoGovernorAddress;
    _executors[0] = address(0);

    vm.prank(deployer);
    timelock = new TimelockController(TIMELOCK_MIN_DELAY, _proposers, _executors, address(0));

    BasicCouncilVetoGovernor.ConstructorParams memory _vp = _vetoGovernorParams();
    _vp.token = daoTokenAddress;
    _vp.timelock = timelock;
    _vp.governorAdmin = deployer;
    _vp.council = _councilGovernorAddress;

    vm.prank(deployer);
    vetoGovernor = new BasicCouncilVetoGovernor(_vp);

    vm.prank(deployer);

    BasicCouncilGovernor.InitialCouncilParams memory _councilParams =
      BasicCouncilGovernor.InitialCouncilParams({
        initialVotingDelay: 1 days,
        initialVotingPeriod: 1 weeks,
        initialProposalThreshold: 1,
        initialQuorumFraction: 60,
        initialSuperQuorumFraction: 100
      });

    councilGovernor = new BasicCouncilGovernor(
      "BasicCouncilGovernor", councilToken, vetoGovernor, deployer, _councilParams
    );

    targets.push(address(target));
    values.push(0);
    calldatas.push(abi.encodeWithSignature("increment()"));
  }

  function _mintDaoTokens(address _holder, uint256 _amount) internal virtual;

  function _selectCouncilMember(uint256 _proposerIndex) internal view returns (address) {
    return councilMembers[_proposerIndex % COUNCIL_SIZE];
  }

  function _proposeAndForwardToVetoGovernor(uint256 _proposerIndex, string memory _description)
    internal
    returns (uint256 vetoProposalId)
  {
    bytes32 _descriptionHash = keccak256(bytes(_description));

    address _proposer = _selectCouncilMember(_proposerIndex);
    vm.prank(_proposer);
    uint256 _councilProposalId = councilGovernor.propose(targets, values, calldatas, _description);

    skip(councilGovernor.votingDelay() + 1);
    for (
      uint256 _i = 0;
      _i < councilGovernor.quorum(councilGovernor.proposalSnapshot(_councilProposalId));
      _i++
    ) {
      vm.prank(councilMembers[_i]);
      councilGovernor.castVote(_councilProposalId, 1);
    }
    skip(councilGovernor.votingPeriod() + 1);

    councilGovernor.queue(targets, values, calldatas, _descriptionHash);

    vetoProposalId = _councilProposalId;
  }
}

// --- TIMESTAMP-CLOCK TOKEN TESTS ---

contract TimestampDaoTokenTest is BasicCouncilVetoGovernorTest {
  MockERC20Votes internal daoToken;

  function _deployDaoToken() internal override returns (address) {
    daoToken = new MockERC20Votes();
    return address(daoToken);
  }

  function _vetoGovernorParams()
    internal
    view
    override
    returns (BasicCouncilVetoGovernor.ConstructorParams memory)
  {
    return BasicCouncilVetoGovernor.ConstructorParams(
      "BasicCouncilVetoGovernor",
      address(0),
      1 hours,
      1 days,
      0,
      vetoGuardian,
      deployer,
      4 days,
      3 days,
      50,
      10,
      TimelockController(payable(address(0))),
      deployer,
      address(0)
    );
  }

  function _mintDaoTokens(address _holder, uint256 _amount) internal override {
    daoToken.mint(_holder, _amount);
    vm.prank(_holder);
    daoToken.delegate(_holder);
  }

  function _advanceTo(uint256 timepoint) internal override {
    vm.warp(timepoint);
  }
}

contract BasicCouncilVetoGovernorSmokeTest is TimestampDaoTokenTest {
  function test_SetupAndInitialization() public view {
    assertEq(vetoGovernor.COUNCIL(), address(councilGovernor));
    assertEq(vetoGovernor.vetoOverrideRole(), deployer);
    assertEq(address(vetoGovernor.timelock()), address(timelock));
  }

  function test_HappyPath_ProposalSucceedsAndExecutes(uint256 _proposerIndex) public {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Succeeds");

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Succeeds")));

    skip(timelock.getMinDelay() + 1);

    assertEq(target.number(), 0);
    councilGovernor.execute(targets, values, calldatas, keccak256(bytes("Succeeds")));

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Executed));
    assertEq(target.number(), 1);
  }

  function test_VetoPath_ProposalIsSuccessfullyVetoed(uint256 _proposerIndex) public {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Vetoed");

    _advanceTo(block.timestamp + vetoGovernor.votingDelay() + 1);

    vm.prank(whale1);
    vetoGovernor.castVote(_proposalId, 0);

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Defeated));

    vm.expectRevert();
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Vetoed")));
  }

  function test_VetoOverridePath_VetoedProposalIsOverriddenAndExecuted(uint256 _proposerIndex)
    public
  {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Overridden");

    _advanceTo(block.timestamp + vetoGovernor.votingDelay() + 1);
    vm.prank(whale1);
    vetoGovernor.castVote(_proposalId, 0);

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Defeated));

    vm.prank(deployer);
    vetoGovernor.overrideVeto(_proposalId);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Overridden")));
    skip(timelock.getMinDelay() + 1);
    councilGovernor.execute(targets, values, calldatas, keccak256(bytes("Overridden")));

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Executed));
    assertEq(target.number(), 1);
  }

  function test_RevertIf_NonCouncilProposes() public {
    vm.expectRevert("Only council");
    vm.prank(nonCouncilProposer);
    vetoGovernor.propose(targets, values, calldatas, "Invalid Proposal");
  }

  function test_RevertIf_CancelAPendingProposal(uint256 _proposerIndex) public {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Overridden");

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Pending));

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnableToCancel.selector, _proposalId, councilMembers[0]
      )
    );
    vm.prank(councilMembers[0]);
    vetoGovernor.cancel(targets, values, calldatas, keccak256(bytes("Overridden")));
  }

  function testFuzz_ExecutionSucceedsWithPrefundedTimelock(uint256 _proposerIndex, uint256 _value)
    public
  {
    vm.assume(_value > 0);
    values[0] = _value;
    calldatas[0] = abi.encodeWithSignature("depositExact(uint256)", _value);
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "");

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("")));
    skip(timelock.getMinDelay());

    vm.deal(address(timelock), _value);
    vm.prank(councilMembers[0]);
    councilGovernor.execute(targets, values, calldatas, keccak256(bytes("")));

    assertEq(address(timelock).balance, 0);
    assertEq(targets[0].balance, _value);
  }

  function testFuzz_ExecutionSucceedsWithCallerValue(uint256 _proposerIndex, uint256 _value)
    public
  {
    vm.assume(_value > 0);
    values[0] = _value;
    calldatas[0] = abi.encodeWithSignature("depositExact(uint256)", _value);
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "");

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("")));
    skip(timelock.getMinDelay());

    vm.deal(councilMembers[0], _value);
    vm.prank(councilMembers[0]);
    councilGovernor.execute{value: _value}(targets, values, calldatas, keccak256(bytes("")));

    assertEq(councilMembers[0].balance, 0);
    assertEq(targets[0].balance, _value);
  }

  function testFuzz_ExecutionSucceedsWithSplitFunding(uint256 _proposerIndex, uint256 _callerValue)
    public
  {
    vm.assume(0 < _callerValue && _callerValue < 1e18);
    values[0] = 1e18;
    calldatas[0] = abi.encodeWithSignature("deposit()");
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "");

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("")));
    skip(timelock.getMinDelay());

    vm.deal(councilMembers[0], _callerValue);
    vm.deal(address(timelock), 1e18 - _callerValue);
    vm.prank(councilMembers[0]);
    councilGovernor.execute{value: _callerValue}(targets, values, calldatas, keccak256(bytes("")));

    assertEq(councilMembers[0].balance, 0);
    assertEq(address(timelock).balance, 0);
    assertEq(targets[0].balance, 1e18);
  }
}

contract _IsValidDescriptionForProposer is TimestampDaoTokenTest {
  function testFuzz_ProposalWithProposerRestrictedDescriptionCanBeForwarded(uint256 _proposerIndex)
    public
  {
    address _proposer = _selectCouncilMember(_proposerIndex);
    string memory _description =
      string.concat("Test proposal #proposer=", Strings.toHexString(_proposer));
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, _description);

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Pending));
  }
}

// --- BLOCK-CLOCK ERC-5805 TOKEN TESTS ---

abstract contract BlockClockDaoTokenTest is BasicCouncilVetoGovernorTest {
  uint48 constant VETO_VOTING_DELAY = 10;
  uint32 constant VETO_VOTING_PERIOD = 100;

  function _vetoGovernorParams()
    internal
    view
    override
    returns (BasicCouncilVetoGovernor.ConstructorParams memory)
  {
    return BasicCouncilVetoGovernor.ConstructorParams(
      "BasicCouncilVetoGovernor",
      address(0),
      VETO_VOTING_DELAY,
      VETO_VOTING_PERIOD,
      0,
      vetoGuardian,
      deployer,
      VETO_VOTING_PERIOD * 4,
      VETO_VOTING_PERIOD * 3,
      50,
      10,
      TimelockController(payable(address(0))),
      deployer,
      address(0)
    );
  }

  function _advanceTo(uint256 timepoint) internal override {
    vm.roll(timepoint);
  }
}

contract BlockClockDaoTokenSetupTest is BlockClockDaoTokenTest {
  MockERC20VotesBlockNumber internal daoToken;

  function _deployDaoToken() internal override returns (address) {
    daoToken = new MockERC20VotesBlockNumber();
    return address(daoToken);
  }

  function _mintDaoTokens(address _holder, uint256 _amount) internal override {
    daoToken.mint(_holder, _amount);
  }
}

contract BasicCouncilVetoGovernorBlockClockSmokeTest is BlockClockDaoTokenSetupTest {
  function test_ClockReturnsBlockNumber() public view {
    assertEq(vetoGovernor.clock(), uint48(block.number));
    assertEq(vetoGovernor.CLOCK_MODE(), "mode=blocknumber&from=default");
  }

  function test_HappyPath_ProposalSucceedsAndExecutes(uint256 _proposerIndex) public {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Succeeds");

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Succeeds")));

    skip(timelock.getMinDelay() + 1);
    assertEq(target.number(), 0);
    councilGovernor.execute(targets, values, calldatas, keccak256(bytes("Succeeds")));

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Executed));
    assertEq(target.number(), 1);
  }

  function test_VetoPath_ProposalIsSuccessfullyVetoed(uint256 _proposerIndex) public {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Vetoed");

    _advanceTo(block.number + vetoGovernor.votingDelay() + 1);

    vm.prank(whale1);
    vetoGovernor.castVote(_proposalId, 0);

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Defeated));

    vm.expectRevert();
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Vetoed")));
  }

  function test_VetoOverridePath_VetoedProposalIsOverriddenAndExecuted(uint256 _proposerIndex)
    public
  {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Overridden");

    _advanceTo(block.number + vetoGovernor.votingDelay() + 1);
    vm.prank(whale1);
    vetoGovernor.castVote(_proposalId, 0);

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Defeated));

    vm.prank(deployer);
    vetoGovernor.overrideVeto(_proposalId);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Overridden")));
    skip(timelock.getMinDelay() + 1);
    councilGovernor.execute(targets, values, calldatas, keccak256(bytes("Overridden")));

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Executed));
    assertEq(target.number(), 1);
  }
}

// --- NO-CLOCK ERC-5805 TOKEN TESTS (GovernorVotes fallback) ---

contract NoClockDaoTokenSetupTest is BlockClockDaoTokenTest {
  MockERC20VotesNoClock internal daoToken;

  function _deployDaoToken() internal override returns (address) {
    daoToken = new MockERC20VotesNoClock();
    return address(daoToken);
  }

  function _mintDaoTokens(address _holder, uint256 _amount) internal override {
    daoToken.mint(_holder, _amount);
  }
}

contract BasicCouncilVetoGovernorNoClockSmokeTest is NoClockDaoTokenSetupTest {
  function test_ClockFallsBackToBlockNumber() public view {
    assertEq(vetoGovernor.clock(), uint48(block.number));
    assertEq(vetoGovernor.CLOCK_MODE(), "mode=blocknumber&from=default");
  }

  function test_HappyPath_ProposalSucceedsAndExecutes(uint256 _proposerIndex) public {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Succeeds");

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Succeeds")));

    skip(timelock.getMinDelay() + 1);
    assertEq(target.number(), 0);
    councilGovernor.execute(targets, values, calldatas, keccak256(bytes("Succeeds")));

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Executed));
    assertEq(target.number(), 1);
  }

  function test_VetoPath_ProposalIsSuccessfullyVetoed(uint256 _proposerIndex) public {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Vetoed");

    _advanceTo(block.number + vetoGovernor.votingDelay() + 1);

    vm.prank(whale1);
    vetoGovernor.castVote(_proposalId, 0);

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Defeated));

    vm.expectRevert();
    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Vetoed")));
  }

  function test_VetoOverridePath_VetoedProposalIsOverriddenAndExecuted(uint256 _proposerIndex)
    public
  {
    uint256 _proposalId = _proposeAndForwardToVetoGovernor(_proposerIndex, "Overridden");

    _advanceTo(block.number + vetoGovernor.votingDelay() + 1);
    vm.prank(whale1);
    vetoGovernor.castVote(_proposalId, 0);

    _advanceTo(vetoGovernor.proposalDeadline(_proposalId) + 1);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Defeated));

    vm.prank(deployer);
    vetoGovernor.overrideVeto(_proposalId);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));

    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Overridden")));
    skip(timelock.getMinDelay() + 1);
    councilGovernor.execute(targets, values, calldatas, keccak256(bytes("Overridden")));

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Executed));
    assertEq(target.number(), 1);
  }
}
