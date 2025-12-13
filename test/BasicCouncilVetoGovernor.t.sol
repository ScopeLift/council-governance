// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

// External Dependencies
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {
  GovernorCountingSimple
} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Internal Dependencies
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";

// Test Dependencies
import {Test} from "forge-std/Test.sol";
import {MockERC20Votes} from "test/helpers/MockERC20Votes.sol";
import {BasicCouncilVetoGovernorHarness} from "test/harnesses/BasicCouncilVetoGovernorHarness.sol";

// Script Dependencies
import {DeploymentConfigurationTest} from "script/DeploymentConfigurationTest.sol";
import {
  DeploymentInputMainnetForkTest
} from "script/deploy-constants/DeploymentInputMainnetForkTest.sol";
import {DeployTimelock} from "script/DeployTimelock.s.sol";

contract BasicVetoGovernorTest is Test {
  struct Proposal {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  DeploymentInputMainnetForkTest internal input = new DeploymentInputMainnetForkTest();

  BasicCouncilVetoGovernorHarness internal vetoGovernor;
  address internal councilGovernor = makeAddr("Council governor");
  address internal whale = makeAddr("Whale");

  function setUp() public {
    DeploymentConfigurationTest _config = new DeploymentConfigurationTest();
    TimelockController _timelock =
      _deployTimelock(_config._getTimelockDeploymentConfiguration(), input.MAIN_DAO_GOVERNOR());
    _deployVetoGovernor(_config._getVetoGovernorDeploymentConfiguration(), _timelock);

    vm.startPrank(input.MAIN_DAO_GOVERNOR());
    _timelock.grantRole(_timelock.EXECUTOR_ROLE(), address(vetoGovernor));
    _timelock.grantRole(_timelock.PROPOSER_ROLE(), address(vetoGovernor));
    _timelock.renounceRole(_timelock.DEFAULT_ADMIN_ROLE(), input.MAIN_DAO_GOVERNOR());
    vm.stopPrank();

    MockERC20Votes(address(vetoGovernor.token())).mint(whale, 100e18);
  }

  function _deployVetoGovernor(
    DeploymentConfigurationTest.VetoGovernorDeploymentConfiguration memory _config,
    TimelockController _timelock
  ) internal {
    _config.mainDaoToken = new MockERC20Votes();
    vetoGovernor = new BasicCouncilVetoGovernorHarness(
      _config, _timelock, councilGovernor, input.MAIN_DAO_GOVERNOR()
    );
  }

  function _deployTimelock(
    DeploymentConfigurationTest.TimelockDeploymentConfiguration memory _config,
    address _deployer
  ) internal returns (TimelockController _timelock) {
    DeployTimelock _timelockScript = new DeployTimelock();
    _timelock = _timelockScript.run(_deployer, _config);
  }

  function _buildEmptyProposal(string memory _description)
    internal
    pure
    returns (Proposal memory _proposal)
  {
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    bytes[] memory _calldatas = new bytes[](1);
    _proposal = Proposal(_targets, _values, _calldatas, _description);
  }

  function _buildEmptyProposal() internal pure returns (Proposal memory _proposal) {
    _proposal = _buildEmptyProposal("Empty proposal");
  }

  function _submitProposal(Proposal memory _proposal) public returns (uint256 _proposalId) {
    vm.prank(councilGovernor);
    _proposalId = vetoGovernor.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
  }

  function _submitProposalAndWarpPastVotingDelay(Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposal(_proposal);
    vm.warp(block.timestamp + vetoGovernor.votingDelay() + 1);
  }

  function _failProposal(Proposal memory _proposal) public returns (uint256 _proposalId) {
    _proposalId = _submitProposalAndWarpPastVotingDelay(_proposal);

    vm.prank(whale);
    vetoGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.Against));
  }

  function _submitAndPassProposal(Proposal memory _proposal) public returns (uint256 _proposalId) {
    _proposalId = _submitProposalAndWarpPastVotingDelay(_proposal);
    vm.warp(block.timestamp + vetoGovernor.votingPeriod() + 1);
  }

  function _passAndQueueProposal(address _caller, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitAndPassProposal(_proposal);

    vm.prank(_caller);
    vetoGovernor.queue(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }

  function _passQueueAndExecuteProposal(address _caller, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _passAndQueueProposal(_caller, _proposal);

    vm.warp(
      block.timestamp + TimelockController(payable(address(vetoGovernor.timelock()))).getMinDelay()
    );
    vm.prank(councilGovernor);
    vetoGovernor.execute(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }

  function _assertProposalState(uint256 _proposalId, IGovernor.ProposalState _expected)
    internal
    view
  {
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(_expected));
  }

  function _timelockSalt(bytes32 _descriptionHash) internal view returns (bytes32) {
    return bytes20(address(vetoGovernor)) ^ _descriptionHash;
  }
}

contract Constructor is Test {
  function test_ConstructorSetsParamsCorrectly(
    BasicCouncilVetoGovernor.ConstructorParams memory _params
  ) public {
    vm.assume(_params.governorAdmin != address(0));
    vm.assume(_params.votingPeriod != 0);
    _params.votingPeriodExtensionThresholdPct =
      uint16(bound(_params.votingPeriodExtensionThresholdPct, 0, 100));
    _params.vetoThresholdNumerator = bound(_params.vetoThresholdNumerator, 0, 100);

    BasicCouncilVetoGovernor.ConstructorParams memory _newParams =
      BasicCouncilVetoGovernor.ConstructorParams(
        _params.name,
        _params.token,
        _params.votingDelay,
        _params.votingPeriod,
        _params.proposalThreshold,
        _params.vetoGuardian,
        _params.vetoOverrideRole,
        _params.vetoOverrideDuration,
        _params.votingPeriodExtension,
        _params.votingPeriodExtensionThresholdPct,
        _params.vetoThresholdNumerator,
        _params.timelock,
        _params.governorAdmin,
        _params.council
      );
    BasicCouncilVetoGovernor _vetoGovernor = new BasicCouncilVetoGovernor(_newParams);

    assertEq(_vetoGovernor.name(), _newParams.name);
    assertEq(address(_vetoGovernor.token()), address(_newParams.token));
    assertEq(_vetoGovernor.votingDelay(), _newParams.votingDelay);
    assertEq(_vetoGovernor.votingPeriod(), _newParams.votingPeriod);
    assertEq(_vetoGovernor.proposalThreshold(), _newParams.proposalThreshold);
    assertEq(_vetoGovernor.vetoOverrideRole(), _newParams.vetoOverrideRole);
    assertEq(_vetoGovernor.vetoOverrideDuration(), _newParams.vetoOverrideDuration);
    assertEq(_vetoGovernor.vetoGuardian(), _newParams.vetoGuardian);
    assertEq(address(_vetoGovernor.timelock()), address(_newParams.timelock));
    assertEq(_vetoGovernor.owner(), _newParams.governorAdmin);
    assertEq(_vetoGovernor.COUNCIL(), _newParams.council);
    assertEq(_vetoGovernor.votingPeriodExtension(), _newParams.votingPeriodExtension);
    assertEq(
      _vetoGovernor.minorVetoExtensionThresholdPct(), _newParams.votingPeriodExtensionThresholdPct
    );
  }
}

contract VotingDelay is BasicVetoGovernorTest {
  function test_ReturnsVotingDelay() public view {
    assertEq(vetoGovernor.votingDelay(), input.VETO_GOVERNOR_INITIAL_VOTING_DELAY());
  }
}

contract VotingPeriod is BasicVetoGovernorTest {
  function test_ReturnsVotingPeriod() public view {
    assertEq(vetoGovernor.votingPeriod(), input.VETO_GOVERNOR_INITIAL_VOTING_PERIOD());
  }
}

contract ProposalThreshold is BasicVetoGovernorTest {
  function test_ReturnsProposalThreshold() public view {
    assertEq(vetoGovernor.proposalThreshold(), input.VETO_GOVERNOR_INITIAL_PROPOSAL_THRESHOLD());
  }
}

contract Quorum is BasicVetoGovernorTest {
  function testFuzz_ReturnsQuorum(uint256 _timepoint) public view {
    assertEq(vetoGovernor.quorum(_timepoint), 0);
  }
}

contract Clock is BasicVetoGovernorTest {
  function testFuzz_ReturnsCurrentTimestamp(uint256 _timestamp) public {
    vm.warp(_timestamp);
    assertEq(vetoGovernor.clock(), uint48(_timestamp));
  }
}

contract CLOCK_MODE is BasicVetoGovernorTest {
  function test_ReturnsTimestamp() public view {
    assertEq(
      abi.encodePacked(keccak256(bytes(vetoGovernor.CLOCK_MODE()))),
      abi.encodePacked(keccak256("mode=timestamp"))
    );
  }
}

contract SetVotingDelay is BasicVetoGovernorTest {
  function testFuzz_GovernanceSetsVotingDelay(uint48 _newVotingDelay) public {
    vm.prank(vetoGovernor.owner());
    vetoGovernor.setVotingDelay(_newVotingDelay);

    assertEq(vetoGovernor.votingDelay(), _newVotingDelay);
  }

  function testFuzz_EmitVotingDelaySet(uint48 _newVotingDelay) public {
    vm.expectEmit();
    emit GovernorSettings.VotingDelaySet(vetoGovernor.votingDelay(), uint48(_newVotingDelay));
    vm.prank(vetoGovernor.owner());
    vetoGovernor.setVotingDelay(_newVotingDelay);
  }

  function testFuzz_RevertIf_NonAdminSetsVotingDelay(address _caller, uint48 _newVotingDelay)
    public
  {
    vm.assume(_caller != vetoGovernor.owner());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    vetoGovernor.setVotingDelay(_newVotingDelay);
  }
}

contract SetVotingPeriod is BasicVetoGovernorTest {
  function testFuzz_GovernanceSetsVotingPeriod(uint32 _newVotingPeriod) public {
    vm.assume(_newVotingPeriod != 0);

    vm.prank(vetoGovernor.owner());
    vetoGovernor.setVotingPeriod(_newVotingPeriod);

    assertEq(vetoGovernor.votingPeriod(), _newVotingPeriod);
  }

  function testFuzz_EmitVotingPeriodSet(uint32 _newVotingPeriod) public {
    vm.assume(_newVotingPeriod != 0);

    vm.expectEmit();
    emit GovernorSettings.VotingPeriodSet(vetoGovernor.votingPeriod(), uint32(_newVotingPeriod));
    vm.prank(vetoGovernor.owner());
    vetoGovernor.setVotingPeriod(_newVotingPeriod);
  }

  function testFuzz_RevertIf_NonAdminSetsVotingPeriod(address _caller, uint32 _newVotingPeriod)
    public
  {
    vm.assume(_newVotingPeriod != 0);
    vm.assume(_caller != vetoGovernor.owner());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    vetoGovernor.setVotingPeriod(_newVotingPeriod);
  }
}

contract SetProposalThreshold is BasicVetoGovernorTest {
  function testFuzz_GovernanceSetsVotingPeriod(uint256 _newProposalThreshold) public {
    vm.prank(vetoGovernor.owner());
    vetoGovernor.setProposalThreshold(_newProposalThreshold);

    assertEq(vetoGovernor.proposalThreshold(), _newProposalThreshold);
  }

  function testFuzz_EmitVotingPeriodSet(uint256 _newProposalThreshold) public {
    vm.expectEmit();
    emit GovernorSettings.ProposalThresholdSet(
      vetoGovernor.proposalThreshold(), _newProposalThreshold
    );
    vm.prank(vetoGovernor.owner());
    vetoGovernor.setProposalThreshold(_newProposalThreshold);
  }

  function testFuzz_RevertIf_NonAdminSetsVotingDelay(address _caller, uint256 _newProposalThreshold)
    public
  {
    vm.assume(_caller != vetoGovernor.owner());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    vetoGovernor.setProposalThreshold(_newProposalThreshold);
  }
}

contract ProposalNeedsQueuing is BasicVetoGovernorTest {
  function testFuzz_ProposalNeedsQueuingReturnsTrue(uint256 _proposalId) public view {
    assertTrue(vetoGovernor.proposalNeedsQueuing(_proposalId));
  }
}

contract State is BasicVetoGovernorTest {
  function test_StatePendingBeforeVotingDelay() public {
    uint256 _proposalId = _submitProposal(_buildEmptyProposal());

    _assertProposalState(_proposalId, IGovernor.ProposalState.Pending);
  }

  function test_StateActiveDuringVotingPeriod() public {
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_proposal);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Active);
  }

  function test_StateActiveDuringVotingPeriodWithVetoQuorum() public {
    uint256 _proposalId = _failProposal(_buildEmptyProposal());

    _assertProposalState(_proposalId, IGovernor.ProposalState.Active);
  }

  function test_StateDefeatedDuringVotingPeriodWithVetoGuardian() public {
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_buildEmptyProposal());
    vm.prank(vetoGovernor.vetoGuardian());
    vetoGovernor.vetoByGuardian(_proposalId);

    assertTrue(vetoGovernor.guardianVetoed(_proposalId));
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function test_StateSucceededAfterVotingPeriod() public {
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_buildEmptyProposal());
    vm.warp(block.timestamp + vetoGovernor.votingPeriod());

    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function test_StateDefeatedAfterVotingPeriodWithVetoQuorum() public {
    uint256 _proposalId = _failProposal(_buildEmptyProposal());
    vm.warp(vetoGovernor.proposalDeadline(_proposalId) + 1);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function test_StateDefeatedAfterVotingPeriodWithVetoGuardian() public {
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_buildEmptyProposal());
    vm.prank(vetoGovernor.vetoGuardian());
    vetoGovernor.vetoByGuardian(_proposalId);
    // Guardian veto immediately defeats, but strict expiration check helps consistency
    vm.warp(vetoGovernor.proposalDeadline(_proposalId) + 1);

    assertTrue(vetoGovernor.guardianVetoed(_proposalId));
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function test_StateDefeatedAfterVotingPeriodWithVetoGuardianAndVetoQuorum() public {
    uint256 _proposalId = _failProposal(_buildEmptyProposal());
    vm.prank(vetoGovernor.vetoGuardian());
    vetoGovernor.vetoByGuardian(_proposalId);
    vm.warp(vetoGovernor.proposalDeadline(_proposalId) + 1);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function test_StateSucceededAfterVotingPeriodWithVetoQuorumAndVetoOverride() public {
    uint256 _proposalId = _failProposal(_buildEmptyProposal());
    vm.warp(vetoGovernor.proposalDeadline(_proposalId) + 1);

    vm.prank(vetoGovernor.vetoOverrideRole());
    vetoGovernor.overrideVeto(_proposalId);

    assertTrue(vetoGovernor.isVetoOverridden(_proposalId));
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function test_StateSucceededAfterVotingPeriodWithVetoGuardianAndVetoOverride() public {
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_buildEmptyProposal());
    vm.prank(vetoGovernor.vetoGuardian());
    vetoGovernor.vetoByGuardian(_proposalId);
    vm.warp(vetoGovernor.proposalDeadline(_proposalId) + 1);

    vm.prank(vetoGovernor.vetoOverrideRole());
    vetoGovernor.overrideVeto(_proposalId);

    assertTrue(vetoGovernor.isVetoOverridden(_proposalId));
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function test_StateSucceededAfterVotingPeriodWithVetoGuardianAndVetoQuorumAndVetoOverride()
    public
  {
    uint256 _proposalId = _failProposal(_buildEmptyProposal());
    vm.prank(vetoGovernor.vetoGuardian());
    vetoGovernor.vetoByGuardian(_proposalId);
    vm.warp(vetoGovernor.proposalDeadline(_proposalId) + 1);

    vm.prank(vetoGovernor.vetoOverrideRole());
    vetoGovernor.overrideVeto(_proposalId);

    assertTrue(vetoGovernor.isVetoOverridden(_proposalId));
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function test_StateDefeatedAfterVetoOverrideDurationExpires() public {
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_buildEmptyProposal());
    vm.prank(vetoGovernor.vetoGuardian());
    vetoGovernor.vetoByGuardian(_proposalId);
    vm.warp(block.timestamp + vetoGovernor.votingPeriod() + 1);

    vm.prank(vetoGovernor.vetoOverrideRole());
    vetoGovernor.overrideVeto(_proposalId);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);

    vm.warp(vetoGovernor.proposalDeadline(_proposalId) + vetoGovernor.vetoOverrideDuration());

    assertTrue(vetoGovernor.isVetoOverridden(_proposalId));
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function test_StateQueuedAfterVetoOverrideDurationExpires() public {
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_proposal);
    vm.prank(vetoGovernor.vetoGuardian());
    vetoGovernor.vetoByGuardian(_proposalId);
    vm.warp(block.timestamp + vetoGovernor.votingPeriod() + 1);

    vm.prank(vetoGovernor.vetoOverrideRole());
    vetoGovernor.overrideVeto(_proposalId);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);

    vm.prank(councilGovernor);
    vetoGovernor.queue(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );

    vm.warp(vetoGovernor.proposalDeadline(_proposalId) + vetoGovernor.vetoOverrideDuration());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Queued);
  }
}

contract Propose is BasicVetoGovernorTest {
  function test_CouncilProposesProposal() public {
    Proposal memory _proposal = _buildEmptyProposal();
    vm.expectCall(
      address(vetoGovernor),
      abi.encodeWithSelector(
        BasicCouncilVetoGovernor.propose.selector,
        _proposal.targets,
        _proposal.values,
        _proposal.calldatas,
        _proposal.description
      )
    );
    _submitProposal(_proposal);
  }

  function test_RevertIf_NonCouncilCallsPropose(address _caller) public {
    vm.assume(_caller != councilGovernor);
    Proposal memory _proposal = _buildEmptyProposal();

    vm.expectRevert(bytes("Only council"));
    vm.prank(_caller);
    vetoGovernor.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
  }
}

contract Execute is BasicVetoGovernorTest {
  function test_CouncilExecutesProposal(address _caller) public {
    _passQueueAndExecuteProposal(_caller, _buildEmptyProposal());
  }

  function test_RevertIf_NonCouncilExecutesProposal(address _caller) public {
    vm.assume(_caller != councilGovernor);

    Proposal memory _proposal = _buildEmptyProposal();
    _passAndQueueProposal(_caller, _proposal);
    vm.warp(block.timestamp + TimelockController(payable(vetoGovernor.timelock())).getMinDelay());

    vm.expectRevert(bytes("Only council"));
    vm.prank(_caller);
    vetoGovernor.execute(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }
}

contract SetVetoOverrideRole is BasicVetoGovernorTest {
  function testFuzz_AdminSetsVetoOverrideRole(address _newVetoOverrideRole) public {
    vm.prank(vetoGovernor.owner());
    vetoGovernor.setVetoOverrideRole(_newVetoOverrideRole);

    assertEq(vetoGovernor.vetoOverrideRole(), _newVetoOverrideRole);
  }

  function testFuzz_RevertIf_NonAdminSetsVetoOverrideRole(
    address _caller,
    address _newVetoOverrideRole
  ) public {
    vm.assume(_caller != vetoGovernor.owner());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    vetoGovernor.setVetoOverrideRole(_newVetoOverrideRole);
  }
}

contract SetVetoOverrideDuration is BasicVetoGovernorTest {
  function testFuzz_AdminSetsVetoOverrideDuration(uint48 _newVetoOverrideDuration) public {
    vm.prank(vetoGovernor.owner());
    vetoGovernor.setVetoOverrideDuration(_newVetoOverrideDuration);

    assertEq(vetoGovernor.vetoOverrideDuration(), _newVetoOverrideDuration);
  }

  function testFuzz_RevertIf_NonAdminSetsVetoOverrideDuration(
    address _caller,
    uint48 _newVetoOverrideDuration
  ) public {
    vm.assume(_caller != vetoGovernor.owner());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    vetoGovernor.setVetoOverrideDuration(_newVetoOverrideDuration);
  }
}

contract SetVetoGuardian is BasicVetoGovernorTest {
  function testFuzz_AdminSetsVetoGuardian(address _newVetoGuardian) public {
    vm.prank(vetoGovernor.owner());
    vetoGovernor.setVetoGuardian(_newVetoGuardian);

    assertEq(vetoGovernor.vetoGuardian(), _newVetoGuardian);
  }

  function testFuzz_RevertIf_NonAdminSetsVetoGuardian(address _caller, address _newVetoGuardian)
    public
  {
    vm.assume(_caller != vetoGovernor.owner());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    vetoGovernor.setVetoGuardian(_newVetoGuardian);
  }
}

contract _checkGovernance is BasicVetoGovernorTest {
  function test_CheckGovernanceAllowsOwner() public {
    vm.prank(vetoGovernor.owner());
    vetoGovernor.exposed_CheckGovernance();
  }

  function testFuzz_RevertIf_CheckGovernanceCalledByNonOwner(address _caller) public {
    vm.assume(_caller != vetoGovernor.owner());
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    vetoGovernor.exposed_CheckGovernance();
  }
}

contract _executor is BasicVetoGovernorTest {
  function test_ExecutorReturnsTimelock() public view {
    assertEq(vetoGovernor.exposed_Executor(), vetoGovernor.timelock());
  }
}

// ! Doesn't get called, dead code
contract _cancel is BasicVetoGovernorTest {}

contract _queueOperations is BasicVetoGovernorTest {
  function testFuzz_QueueOperationsCallsTimelockScheduleBatch(address _caller) public {
    Proposal memory _proposal = _buildEmptyProposal();
    vm.expectCall(
      address(vetoGovernor.timelock()),
      abi.encodeCall(
        TimelockController.scheduleBatch,
        (
          _proposal.targets,
          _proposal.values,
          _proposal.calldatas,
          0,
          _timelockSalt(keccak256(bytes(_proposal.description))),
          TimelockController(payable(address(vetoGovernor.timelock()))).getMinDelay()
        )
      )
    );
    _passAndQueueProposal(_caller, _proposal);
  }
}

contract _executeOperations is BasicVetoGovernorTest {
  function testFuzz_ExecuteOperationsCallsTimelockExecuteBatch(address _caller) public {
    Proposal memory _proposal = _buildEmptyProposal();
    vm.expectCall(
      address(vetoGovernor.timelock()),
      abi.encodeCall(
        TimelockController.executeBatch,
        (
          _proposal.targets,
          _proposal.values,
          _proposal.calldatas,
          0,
          _timelockSalt(keccak256(bytes(_proposal.description)))
        )
      )
    );
    _passQueueAndExecuteProposal(_caller, _proposal);
  }
}
