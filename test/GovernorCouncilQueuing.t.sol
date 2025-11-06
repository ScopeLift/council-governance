// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {OptimisticGovernanceTestBase} from "test/helpers/OptimisticGovernanceTestBase.sol";
import {GovernorCouncilQueuingMock} from "test/mocks/GovernorCouncilQueuingMock.sol";
import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {BasicCouncilVetoGovernorFake} from "test/fakes/BasicCouncilVetoGovernorFake.sol";

contract GovernorCouncilQueuingTest is OptimisticGovernanceTestBase {
  BasicCouncilVetoGovernorFake internal vetoFake;
  GovernorCouncilQueuingMock internal councilMock;

  function setUp() public override {
    super.setUp();
    vetoFake = new BasicCouncilVetoGovernorFake(daoToken);
    councilMock = new GovernorCouncilQueuingMock(
      "GovernorCouncilQueuingMock", // _name
      1 days, // _initialVotingDelay
      1 weeks, // _initialVotingPeriod
      1, // _initialProposalThreshold
      vetoFake, // _vetoGovernor
      address(councilToken)
    );

    vm.label(address(vetoFake), "vetoFake");
    vm.label(address(councilMock), "councilMock");
  }

  function _assertProposalState(uint256 proposalId, IGovernor.ProposalState expected) internal view {
    assertEq(uint8(councilMock.state(proposalId)), uint8(expected));
  }

  function _assertVetoGovernorProposalState(uint256 proposalId, IGovernor.ProposalState expected)
    internal
    view
  {
    assertEq(uint8(vetoFake.state(proposalId)), uint8(expected));
  }

  function _getNonTerminalVetoGovernorProposalState(uint8 _proposalStateIndex)
    internal
    pure
    returns (IGovernor.ProposalState)
  {
    _proposalStateIndex %= 3;
    if (_proposalStateIndex == 0) return IGovernor.ProposalState.Pending;
    if (_proposalStateIndex == 1) return IGovernor.ProposalState.Active;
    if (_proposalStateIndex == 2) return IGovernor.ProposalState.Succeeded;
    return IGovernor.ProposalState.Queued;
  }

  function _getFailedVetoGovernorProposalState(uint8 _proposalStateIndex)
    internal
    pure
    returns (IGovernor.ProposalState)
  {
    _proposalStateIndex %= 2;
    if (_proposalStateIndex == 0) return IGovernor.ProposalState.Canceled;
    if (_proposalStateIndex == 1) return IGovernor.ProposalState.Expired;
    return IGovernor.ProposalState.Defeated;
  }

  function _buildEmptyProposal() internal returns (Proposal memory _proposal) {
    _proposal = _buildEmptyProposal("Empty proposal");
  }

  function _buildEmptyProposal(string memory _description)
    internal
    returns (Proposal memory _proposal)
  {
    targets = new address[](1);
    values = new uint256[](1);
    calldatas = new bytes[](1);
    _proposal = Proposal(targets, values, calldatas, _description);
  }

  function _submitProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    vm.prank(_proposer);
    _proposalId = councilMock.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
  }

  function _submitProposalAndWarpPastVotingDelay(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposal(_proposer, _proposal);
    vm.warp(block.timestamp + councilMock.votingDelay() + 1);
  }

  function _passSubmittedProposal(uint256 _proposalId) public {
    // IERC20 _ercToken = IERC20(address(token));
    uint256 _quorumVotesNeeded = councilMock.quorum(block.timestamp);
    uint256 _votesCast;
    for (uint256 i = 0; i < councilMembers.length; i++) {
      address _councilMember = councilMembers[i];
      vm.prank(_councilMember);
      councilMock.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.For));
      _votesCast += councilToken.balanceOf(_councilMember);
      if (_votesCast >= _quorumVotesNeeded) break;
    }
  }

  function _passProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);
    _passSubmittedProposal(_proposalId);
    vm.warp(block.timestamp + councilMock.votingPeriod() + 1);
  }

  function _failProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);

    vm.prank(_proposer);
    councilMock.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.Against));
    vm.warp(block.timestamp + councilMock.votingPeriod() + 1);
  }

  function _passAndQueueProposal(address _proposer, address _caller, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _passProposal(_proposer, _proposal);

    vm.prank(_caller);
    councilMock.queue(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }

  function _executeProposal(Proposal memory _proposal) public {
    councilMock.execute(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }

  function _passQueueAndExecuteProposal(
    address _proposer,
    address _caller,
    Proposal memory _proposal
  ) public returns (uint256 _proposalId) {
    _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);

    vm.warp(block.timestamp + vetoFake.votingDelay() + vetoFake.votingPeriod() + 1);
    _executeProposal(_proposal);
  }
}

contract UpdateCouncilVetoGovernor is GovernorCouncilQueuingTest {
  function testFuzz_updateCouncilVetoGovernor() public {}
}

contract State is GovernorCouncilQueuingTest {
  function testFuzz_CouncilProposalStateIsPendingWhenProposalIsPendingOnTheCouncil(
    uint256 _councilMemberIndex
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();

    uint256 _proposalId = _submitProposal(_proposer, _proposal);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Pending);
  }

  // !fuzz the time within active
  function testFuzz_CouncilProposalStateIsActiveWhenProposalIsActiveOnTheCouncil(
    uint256 _councilMemberIndex
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();

    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Active);
  }

  function testFuzz_CouncilProposalStateIsCanceledWhenProposalIsCanceledOnTheCouncil(
    uint256 _councilMemberIndex
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();

    uint256 _proposalId = _submitProposal(_proposer, _proposal);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Pending);

    skip(1);

    vm.prank(_proposer);
    councilMock.cancel(targets, values, calldatas, keccak256(bytes("Empty proposal")));

    _assertProposalState(_proposalId, IGovernor.ProposalState.Canceled);
  }

  function testFuzz_CouncilProposalStateIsDefeatedWhenProposalIsDefeatedOnTheCouncil(
    uint256 _councilMemberIndex
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();

    uint256 _proposalId = _failProposal(_proposer, _proposal);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_CouncilProposalStateIsSucceededWhenProposalIsSucceededOnTheCouncil(
    uint256 _councilMemberIndex
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();

    uint256 _proposalId = _passProposal(_proposer, _proposal);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function testFuzz_CouncilProposalStateIsQueuedWhenProposalIsQueuedToTheVetoGovernor(
    uint256 _councilMemberIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();

    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Queued);
  }

  function testFuzz_CouncilProposalStateIsQueuedWhenProposalCouncilProposalStateIsNonTerminalOnTheVetoGovernor(
    uint256 _councilMemberIndex,
    uint8 _proposalStateIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();

    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);
    IGovernor.ProposalState _proposalState =
      _getNonTerminalVetoGovernorProposalState(_proposalStateIndex);
    vetoFake.setProposalState(_proposalId, _proposalState);

    _assertVetoGovernorProposalState(_proposalId, _proposalState);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Queued);
  }

  function testFuzz_CouncilProposalStateIsExecutedWhenProposalStatedIsExecutedOnTheVetoGovernor(
    uint256 _councilMemberIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();

    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);
    vetoFake.setProposalState(_proposalId, IGovernor.ProposalState.Executed);

    _assertVetoGovernorProposalState(_proposalId, IGovernor.ProposalState.Executed);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Executed);
  }

  function testFuzz_CouncilProposalStateIsCanceledWhenProposalFailedOnTheVetoGovernor(
    uint256 _councilMemberIndex,
    uint8 _proposalStateIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Queued);

    IGovernor.ProposalState _proposalState =
      _getFailedVetoGovernorProposalState(_proposalStateIndex);
    vetoFake.setProposalState(_proposalId, _proposalState);

    _assertVetoGovernorProposalState(_proposalId, _proposalState);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Canceled);
  }
}

contract Propose is GovernorCouncilQueuingTest {
  function testFuzz_ProposeCallsVetoGovernorPropose(uint256 _councilMemberIndex, address _caller)
    public
  {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    vm.assume(_caller != _proposer);
    Proposal memory _proposal = _buildEmptyProposal();
    _passAndQueueProposal(_proposer, _caller, _proposal);

    assertEq(vetoFake.proposeCallCount(), 1);
  }

  function testFuzz_QueueSavesProposalDescriptionInStorage(
    uint256 _councilMemberIndex,
    string memory _proposalDescription
  ) public {
    address proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal(_proposalDescription);
    uint256 _proposalId = _submitProposal(proposer, _proposal);

    assertEq(councilMock.exposed_proposalDescription(_proposalId), _proposalDescription);
  }
}

contract _executeOperations is GovernorCouncilQueuingTest {
  // !
  function testFuzz_ExecuteOperationsCallsVetoGovernorExecute(
    uint256 _councilMemberIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    vm.assume(_caller != _proposer);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);

    // Manually set proposal state to queued
    vetoFake.setProposalState(_proposalId, IGovernor.ProposalState.Queued);

    vm.prank(_caller);
    councilMock.exposed_executeOperations(
      _proposalId,
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
    assertEq(vetoFake.executeCallCount(), 1);
  }
}

contract _queueOperations is GovernorCouncilQueuingTest {
  // !
  function testFuzz_QueueOperationsCallsVetoGovernorPropose(
    uint256 _councilMemberIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    vm.assume(_caller != _proposer);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passProposal(_proposer, _proposal);

    vm.prank(_caller);
    councilMock.exposed_queueOperations(
      _proposalId, targets, values, calldatas, keccak256(bytes(_proposal.description))
    );

    assertEq(vetoFake.proposeCallCount(), 1);
  }

  function testFuzz_QueueOperationsSetsVetoGovernorProposalParams(
    uint256 _councilMemberIndex,
    string memory _proposalDescription,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    vm.assume(_caller != _proposer);
    Proposal memory _proposal = _buildEmptyProposal(_proposalDescription);
    uint256 _proposalId = _passProposal(_proposer, _proposal);

    vm.prank(_caller);
    councilMock.exposed_queueOperations(
      _proposalId, targets, values, calldatas, keccak256(bytes(_proposal.description))
    );

    assertEq(vetoFake.lastProposedId(), _proposalId);
    for (uint256 i = 0; i < targets.length; i++) {
      assertEq(vetoFake.lastProposeTargets(i), targets[i]);
      assertEq(vetoFake.lastProposeValues(i), values[i]);
      assertEq(vetoFake.lastProposeCalldatas(i), calldatas[i]);
    }
    assertEq(vetoFake.lastProposeDescription(), _proposalDescription);
  }

  function testFuzz_QueueOpeartionsDeletesProposalDescriptionFromStorage(
    uint256 _councilMemberIndex,
    string memory _proposalDescription,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    vm.assume(_caller != _proposer);
    Proposal memory _proposal = _buildEmptyProposal(_proposalDescription);
    uint256 _proposalId = _passProposal(_proposer, _proposal);

    vm.prank(_caller);
    councilMock.exposed_queueOperations(
      _proposalId, targets, values, calldatas, keccak256(bytes(_proposal.description))
    );

    assertEq(councilMock.exposed_proposalDescription(_proposalId), "");
  }

  function testFuzz_QueueOperationReturnsVetoGovernorProposalDeadline(
    uint256 _councilMemberIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    vm.assume(_caller != _proposer);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passProposal(_proposer, _proposal);

    vm.prank(_caller);
    uint48 _proposalDeadline = councilMock.exposed_queueOperations(
      _proposalId, targets, values, calldatas, keccak256(bytes(_proposal.description))
    );
    assertEq(vetoFake.proposalDeadline(_proposalId), _proposalDeadline);
  }
}

contract _checkVetoGovernorStateBitmap is GovernorCouncilQueuingTest {}
