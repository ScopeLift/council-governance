// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {OptimisticGovernanceTestBase} from "test/helpers/OptimisticGovernanceTestBase.sol";
import {GovernorCouncilQueuingMock} from "test/mocks/GovernorCouncilQueuingMock.sol";
import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

contract GovernorCouncilQueuingTest is OptimisticGovernanceTestBase {
  bytes32 internal constant ALL_PROPOSAL_STATES_BITMAP =
    bytes32((2 ** (uint8(type(IGovernor.ProposalState).max) + 1)) - 1);

  address internal vetoGovernor;
  GovernorCouncilQueuingMock internal councilMock;

  function setUp() public override {
    super.setUp();
    vetoGovernor = makeAddr("veto governor");
    councilMock = new GovernorCouncilQueuingMock(
      "GovernorCouncilQueuingMock", // _name
      1 days, // _initialVotingDelay
      1 weeks, // _initialVotingPeriod
      1, // _initialProposalThreshold
      IGovernor(vetoGovernor), // _vetoGovernor
      address(councilToken) // councilToken
    );

    vm.label(address(councilMock), "councilMock");
  }

  function _assertProposalState(uint256 proposalId, IGovernor.ProposalState expected) internal view {
    assertEq(uint8(councilMock.state(proposalId)), uint8(expected));
  }

  function _encodeStateBitmap(IGovernor.ProposalState proposalState) public pure returns (bytes32) {
    return bytes32(1 << uint8(proposalState));
  }

  function _mockVetoGovernorState(uint256 _proposalId, IGovernor.ProposalState _proposalState)
    internal
  {
    vm.mockCall(
      vetoGovernor,
      abi.encodeWithSelector(IGovernor.state.selector, _proposalId),
      abi.encode(_proposalState)
    );
  }

  function _mockVetoGovernorPropose(uint256 _proposalId) internal {
    vm.mockCall(
      vetoGovernor, abi.encodeWithSelector(IGovernor.propose.selector), abi.encode(_proposalId)
    );
  }

  function _mockVetoGovernorProposalDeadline(uint256 _proposalId, uint48 _expectedDeadline)
    internal
  {
    vm.mockCall(
      address(vetoGovernor),
      abi.encodeWithSelector(IGovernor.proposalDeadline.selector, _proposalId),
      abi.encode(_expectedDeadline)
    );
  }

  function _mockVetoGovernorProposalDeadline(uint256 _proposalId) internal {
    _mockVetoGovernorProposalDeadline(_proposalId, 1 days);
  }

  function _mockVetoGovernorExecute(uint256 _proposalId, Proposal memory _proposal) internal {
    vm.mockCall(
      address(vetoGovernor),
      abi.encodeWithSelector(
        IGovernor.execute.selector,
        _proposal.targets,
        _proposal.values,
        _proposal.calldatas,
        keccak256(bytes(_proposal.description))
      ),
      abi.encode(_proposalId)
    );
  }

  function _expectVetoGovernorPropose(Proposal memory _proposal) internal {
    vm.expectCall(
      vetoGovernor,
      abi.encodeCall(
        IGovernor.propose,
        (_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description)
      )
    );
  }

  function _expectVetoGovernorExecute(Proposal memory _proposal) internal {
    vm.expectCall(
      vetoGovernor,
      abi.encodeCall(
        IGovernor.execute,
        (
          _proposal.targets,
          _proposal.values,
          _proposal.calldatas,
          keccak256(bytes(_proposal.description))
        )
      )
    );
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

    _mockVetoGovernorPropose(_proposalId);
    _mockVetoGovernorProposalDeadline(_proposalId);
    _mockVetoGovernorState(_proposalId, IGovernor.ProposalState.Pending);

    vm.prank(_caller);
    councilMock.queue(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }
}

contract _checkVetoGovernorStateBitmap is GovernorCouncilQueuingTest {
  function testFuzz_ReturnsTrueWhenProposalStateMatchesBitmap(
    uint256 _councilMemberIndex,
    uint8 _proposalStateIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);
    IGovernor.ProposalState _proposalState =
      IGovernor.ProposalState(uint8(bound(_proposalStateIndex, 0, 7)));

    _mockVetoGovernorState(_proposalId, _proposalState);

    assertEq(
      councilMock.exposed_checkVetoGovernorStateBitmap(
        _proposalId, _encodeStateBitmap(_proposalState)
      ),
      true
    );
  }

  function testFuzz_ReturnsFalseWhenProposalStateNotInBitmap(
    uint256 _councilMemberIndex,
    uint8 _proposalStateIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);
    IGovernor.ProposalState _proposalState =
      IGovernor.ProposalState(uint8(bound(_proposalStateIndex, 0, 7)));

    _mockVetoGovernorState(_proposalId, _proposalState);

    assertEq(
      councilMock.exposed_checkVetoGovernorStateBitmap(
        _proposalId, ALL_PROPOSAL_STATES_BITMAP ^ _encodeStateBitmap(_proposalState)
      ),
      false
    );
  }

  function test_CorrectlyHandlesNonTerminalStateBitmap(uint256 _councilMemberIndex, address _caller)
    public
  {
    bytes32 nonTerminalBitmap = _encodeStateBitmap(IGovernor.ProposalState.Pending)
      | _encodeStateBitmap(IGovernor.ProposalState.Active)
      | _encodeStateBitmap(IGovernor.ProposalState.Queued)
      | _encodeStateBitmap(IGovernor.ProposalState.Succeeded);

    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);

    IGovernor.ProposalState[] memory nonTerminalStates = new IGovernor.ProposalState[](4);
    nonTerminalStates[0] = IGovernor.ProposalState.Pending;
    nonTerminalStates[1] = IGovernor.ProposalState.Active;
    nonTerminalStates[2] = IGovernor.ProposalState.Queued;
    nonTerminalStates[3] = IGovernor.ProposalState.Succeeded;

    for (uint256 i = 0; i < nonTerminalStates.length; i++) {
      _mockVetoGovernorState(_proposalId, nonTerminalStates[i]);
      assertTrue(councilMock.exposed_checkVetoGovernorStateBitmap(_proposalId, nonTerminalBitmap));
    }

    IGovernor.ProposalState[] memory terminalStates = new IGovernor.ProposalState[](4);
    terminalStates[0] = IGovernor.ProposalState.Canceled;
    terminalStates[1] = IGovernor.ProposalState.Defeated;
    terminalStates[2] = IGovernor.ProposalState.Expired;
    terminalStates[3] = IGovernor.ProposalState.Executed;

    for (uint256 i = 0; i < terminalStates.length; i++) {
      _mockVetoGovernorState(_proposalId, terminalStates[i]);
      assertFalse(councilMock.exposed_checkVetoGovernorStateBitmap(_proposalId, nonTerminalBitmap));
    }
  }
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

  function testFuzz_CouncilProposalStateIsQueuedWhenProposalStateIsNonTerminalOnTheVetoGovernor(
    uint256 _councilMemberIndex,
    uint8 _proposalStateIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);

    IGovernor.ProposalState _proposalState =
      _getNonTerminalVetoGovernorProposalState(_proposalStateIndex);
    _mockVetoGovernorState(_proposalId, _proposalState);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Queued);
  }

  function testFuzz_CouncilProposalStateIsExecutedWhenProposalStatedIsExecutedOnTheVetoGovernor(
    uint256 _councilMemberIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal();

    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);
    _mockVetoGovernorState(_proposalId, IGovernor.ProposalState.Executed);

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

    IGovernor.ProposalState _proposalState =
      _getFailedVetoGovernorProposalState(_proposalStateIndex);
    _mockVetoGovernorState(_proposalId, _proposalState);

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

    _expectVetoGovernorPropose(_proposal);
    _passAndQueueProposal(_proposer, _caller, _proposal);
  }

  function testFuzz_QueueSavesProposalDescriptionToStorage(
    uint256 _councilMemberIndex,
    string memory _proposalDescription
  ) public {
    address proposer = _selectCouncilMember(_councilMemberIndex);
    Proposal memory _proposal = _buildEmptyProposal(_proposalDescription);
    uint256 _proposalId = _submitProposal(proposer, _proposal);

    assertEq(councilMock.exposed_proposalDescription(_proposalId), _proposalDescription);
  }
}

contract _queueOperations is GovernorCouncilQueuingTest {
  function testFuzz_QueueOperationsCallsVetoGovernorPropose(
    uint256 _councilMemberIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    vm.assume(_caller != _proposer);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passProposal(_proposer, _proposal);

    _mockVetoGovernorPropose(_proposalId);
    _mockVetoGovernorProposalDeadline(_proposalId);
    _expectVetoGovernorPropose(_proposal);

    vm.prank(_caller);
    councilMock.exposed_queueOperations(
      _proposalId, targets, values, calldatas, keccak256(bytes(_proposal.description))
    );
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

    _mockVetoGovernorPropose(_proposalId);
    _mockVetoGovernorProposalDeadline(_proposalId);
    _expectVetoGovernorPropose(_proposal);

    vm.prank(_caller);
    councilMock.exposed_queueOperations(
      _proposalId, targets, values, calldatas, keccak256(bytes(_proposal.description))
    );
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

    _mockVetoGovernorPropose(_proposalId);
    _mockVetoGovernorProposalDeadline(_proposalId);

    vm.prank(_caller);
    councilMock.exposed_queueOperations(
      _proposalId, targets, values, calldatas, keccak256(bytes(_proposal.description))
    );

    assertEq(councilMock.exposed_proposalDescription(_proposalId), "");
  }

  function testFuzz_QueueOperationsReturnsVetoGovernorProposalDeadline(
    uint256 _councilMemberIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    vm.assume(_caller != _proposer);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passProposal(_proposer, _proposal);
    uint48 _expectedDeadline = uint48(block.timestamp + 2 weeks);

    _mockVetoGovernorPropose(_proposalId);
    _mockVetoGovernorProposalDeadline(_proposalId, _expectedDeadline);

    vm.prank(_caller);
    uint48 _returnedDeadline = councilMock.exposed_queueOperations(
      _proposalId, targets, values, calldatas, keccak256(bytes(_proposal.description))
    );
    assertEq(_expectedDeadline, _returnedDeadline);
  }
}

contract _executeOperations is GovernorCouncilQueuingTest {
  function testFuzz_ExecuteOperationsCallsVetoGovernorExecute(
    uint256 _councilMemberIndex,
    address _caller
  ) public {
    address _proposer = _selectCouncilMember(_councilMemberIndex);
    vm.assume(_caller != _proposer);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _proposal);

    _mockVetoGovernorState(_proposalId, IGovernor.ProposalState.Queued);
    _mockVetoGovernorExecute(_proposalId, _proposal);
    _expectVetoGovernorExecute(_proposal);

    vm.prank(_caller);
    councilMock.exposed_executeOperations(
      _proposalId,
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }
}

// updateCouncilVetoGovernor can only be properly tested once GovernorAdmin is merged.
contract UpdateCouncilVetoGovernor is GovernorCouncilQueuingTest {
  function testFuzz_MainDaoUpdatesCouncilVetoGovernor() public {
    vm.skip();
  }

  function testFuzz_EmitsCouncilVetoGvernorChange() public {
    vm.skip();
  }

  function testFuzz_RevertIf_AnyAddressOtherThanMainDaoUpdatesCouncilVetoGovernor() public {
    vm.skip();
  }
}
