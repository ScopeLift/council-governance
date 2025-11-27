// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, stdStorage, StdStorage} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

import {GovernorVetoGuardian} from "src/extensions/GovernorVetoGuardian.sol";
import {GovernorVetoGuardianMock} from "test/mock/GovernorVetoGuardianMock.sol";

using stdStorage for StdStorage;

contract GovernorVetoGuardianTest is Test {
  address public vetoGuardian = makeAddr("vetoGuardian");
  GovernorVetoGuardianMock public vetoGovernor;

  address[] internal targets;
  uint256[] internal values;
  bytes[] internal calldatas;

  struct Proposal {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  function setUp() public {
    vetoGovernor = new GovernorVetoGuardianMock(vetoGuardian);
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

  function _buildEmptyProposal() internal returns (Proposal memory _proposal) {
    _proposal = _buildEmptyProposal("Empty proposal");
  }

  function _submitProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    vm.prank(_proposer);
    _proposalId = vetoGovernor.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
  }

  function _submitAndCancelProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposal(_proposer, _proposal);
    vm.prank(_proposer);
    vetoGovernor.cancel(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }

  function _submitProposalAndWarpPastVotingDelay(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposal(_proposer, _proposal);
    vm.warp(block.timestamp + vetoGovernor.votingDelay() + 1);
  }

  function _submitAndPassProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);
    vm.warp(block.timestamp + vetoGovernor.votingPeriod() + 1);
  }

  function _submitAndFailProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);
    vm.warp(block.timestamp + vetoGovernor.votingPeriod() + 1);
    vetoGovernor.setDefeated(_proposalId);
  }

  function _passAndQueueProposal(address _proposer, address _caller, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitAndPassProposal(_proposer, _proposal);

    vm.prank(_caller);
    vetoGovernor.queue(
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

    vm.warp(block.timestamp + 1 days + 1);
    vetoGovernor.execute(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }

  function _assertProposalState(uint256 proposalId, IGovernor.ProposalState expected)
    internal
    view
  {
    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(expected));
  }

  function _encodeStateBitmap(IGovernor.ProposalState proposalState)
    internal
    pure
    returns (bytes32)
  {
    return bytes32(1 << uint8(proposalState));
  }
}

contract State is GovernorVetoGuardianTest {
  function testFuzz_StateIsDefeatedWhenPendingProposalIsVetoed(address _proposer) public {
    uint256 _proposalId = _submitProposal(_proposer, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Pending);

    stdstore.target(address(vetoGovernor)).sig("guardianVetoed(uint256)").with_key(_proposalId)
      .checked_write(true);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_StateIsDefeatedWhenActiveProposalIsVetoed(address _proposer) public {
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Active);

    stdstore.target(address(vetoGovernor)).sig("guardianVetoed(uint256)").with_key(_proposalId)
      .checked_write(true);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_StateIsDefeatedWhenCanceledProposalIsVetoed(address _proposer) public {
    uint256 _proposalId = _submitAndCancelProposal(_proposer, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Canceled);

    stdstore.target(address(vetoGovernor)).sig("guardianVetoed(uint256)").with_key(_proposalId)
      .checked_write(true);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_StateIsDefeatedWhenSucceededProposalIsVetoed(address _proposer) public {
    uint256 _proposalId = _submitAndPassProposal(_proposer, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);

    stdstore.target(address(vetoGovernor)).sig("guardianVetoed(uint256)").with_key(_proposalId)
      .checked_write(true);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_StateIsDefeatedWhenDefeatedProposalIsVetoed(address _proposer) public {
    uint256 _proposalId = _submitAndFailProposal(_proposer, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);

    stdstore.target(address(vetoGovernor)).sig("guardianVetoed(uint256)").with_key(_proposalId)
      .checked_write(true);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_StateIsQueuedWhenQueuedProposalIsVetoed(address _proposer, address _caller)
    public
  {
    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Queued);

    stdstore.target(address(vetoGovernor)).sig("guardianVetoed(uint256)").with_key(_proposalId)
      .checked_write(true);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Queued);
  }

  function testFuzz_StateIsExecutedWhenExecutedProposalIsVetoed(address _proposer, address _caller)
    public
  {
    uint256 _proposalId = _passQueueAndExecuteProposal(_proposer, _caller, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Executed);

    stdstore.target(address(vetoGovernor)).sig("guardianVetoed(uint256)").with_key(_proposalId)
      .checked_write(true);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Executed);
  }
}

contract VetoByGuardian is GovernorVetoGuardianTest {
  function testFuzz_VetoGuardianVetoesPendingProposal(address _proposer) public {
    uint256 proposalId = _submitProposal(_proposer, _buildEmptyProposal());
    _assertProposalState(proposalId, IGovernor.ProposalState.Pending);

    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);

    assertEq(vetoGovernor.guardianVetoed(proposalId), true);
    _assertProposalState(proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_VetoGuardianVetoesActiveProposal(address _proposer) public {
    uint256 proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _buildEmptyProposal());
    _assertProposalState(proposalId, IGovernor.ProposalState.Active);

    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);

    assertEq(vetoGovernor.guardianVetoed(proposalId), true);
    _assertProposalState(proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_Emit_ProposalVetoedByGuardian(address _proposer) public {
    uint256 proposalId = _submitProposal(_proposer, _buildEmptyProposal());
    _assertProposalState(proposalId, IGovernor.ProposalState.Pending);

    vm.expectEmit();
    emit GovernorVetoGuardian.ProposalVetoedByGuardian(proposalId);

    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }

  function testFuzz_RevertIf_NonVetoGuardianVetoesProposal(
    address _proposer,
    address _nonVetoGuardian
  ) public {
    vm.assume(_nonVetoGuardian != vetoGuardian);

    uint256 proposalId = _submitProposal(_proposer, _buildEmptyProposal());
    vm.expectRevert(
      abi.encodeWithSelector(GovernorVetoGuardian.GovernorVetoGuardian_Unauthorized.selector)
    );
    vm.prank(_nonVetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }

  function testFuzz_RevertIf_OldVetoGuardianVetoesProposal(
    address _proposer,
    address _newVetoGuardian
  ) public {
    vm.assume(_newVetoGuardian != vetoGuardian);

    address _oldVetoGuardian = vetoGuardian;
    stdstore.target(address(vetoGovernor)).sig(vetoGovernor.vetoGuardian.selector)
      .checked_write(address(_newVetoGuardian));
    assertEq(vetoGovernor.vetoGuardian(), _newVetoGuardian);

    uint256 proposalId = _submitProposal(_proposer, _buildEmptyProposal());
    vm.expectRevert(
      abi.encodeWithSelector(GovernorVetoGuardian.GovernorVetoGuardian_Unauthorized.selector)
    );
    vm.prank(_oldVetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }

  function testFuzz_RevertIf_VetoGuardianVetoesCanceledProposal(address _proposer) public {
    uint256 _proposalId = _submitAndCancelProposal(_proposer, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Canceled);

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnexpectedProposalState.selector,
        _proposalId,
        IGovernor.ProposalState.Canceled,
        _encodeStateBitmap(IGovernor.ProposalState.Pending)
          | _encodeStateBitmap(IGovernor.ProposalState.Active)
      )
    );
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(_proposalId);
  }

  function testFuzz_RevertIf_VetoGuardianVetoesSucceededProposal(address _proposer) public {
    uint256 _proposalId = _submitAndPassProposal(_proposer, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnexpectedProposalState.selector,
        _proposalId,
        IGovernor.ProposalState.Succeeded,
        _encodeStateBitmap(IGovernor.ProposalState.Pending)
          | _encodeStateBitmap(IGovernor.ProposalState.Active)
      )
    );
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(_proposalId);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function testFuzz_RevertIf_VetoGuardianVetoesQueuedProposal(address _proposer, address _caller)
    public
  {
    uint256 _proposalId = _passAndQueueProposal(_proposer, _caller, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Queued);

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnexpectedProposalState.selector,
        _proposalId,
        IGovernor.ProposalState.Queued,
        _encodeStateBitmap(IGovernor.ProposalState.Pending)
          | _encodeStateBitmap(IGovernor.ProposalState.Active)
      )
    );
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(_proposalId);
  }

  function testFuzz_RevertIf_VetoGuardianVetoesExecutedProposal(address _proposer, address _caller)
    public
  {
    uint256 _proposalId = _passQueueAndExecuteProposal(_proposer, _caller, _buildEmptyProposal());
    _assertProposalState(_proposalId, IGovernor.ProposalState.Executed);

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnexpectedProposalState.selector,
        _proposalId,
        IGovernor.ProposalState.Executed,
        _encodeStateBitmap(IGovernor.ProposalState.Pending)
          | _encodeStateBitmap(IGovernor.ProposalState.Active)
      )
    );
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(_proposalId);
  }

  function testFuzz_RevertIf_VetoGuardianVetoesTheSameProposalTwice(address _proposer) public {
    uint256 _proposalId = _submitProposal(_proposer, _buildEmptyProposal());

    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(_proposalId);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);

    vm.expectRevert(
      abi.encodeWithSelector(
        IGovernor.GovernorUnexpectedProposalState.selector,
        _proposalId,
        IGovernor.ProposalState.Defeated,
        _encodeStateBitmap(IGovernor.ProposalState.Pending)
          | _encodeStateBitmap(IGovernor.ProposalState.Active)
      )
    );
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(_proposalId);
  }
}

contract _SetVetoGuardian is GovernorVetoGuardianTest {
  function testFuzz_SetsNewVetoGuardian(address _caller, address _newVetoGuardian) public {
    vm.prank(_caller);
    vetoGovernor.exposed_SetVetoGuardian(_newVetoGuardian);

    assertEq(vetoGovernor.vetoGuardian(), _newVetoGuardian);
  }

  function testFuzz_SetsVetoGuardianToAddressZero(address _caller) public {
    vm.prank(_caller);
    vetoGovernor.exposed_SetVetoGuardian(address(0));

    assertEq(vetoGovernor.vetoGuardian(), address(0));
  }

  function testFuzz_SetsTheSameVetoGuardian(address _caller) public {
    address _oldVetoGuardian = vetoGovernor.vetoGuardian();

    vm.prank(_caller);
    vetoGovernor.exposed_SetVetoGuardian(vetoGovernor.vetoGuardian());

    assertEq(vetoGovernor.vetoGuardian(), _oldVetoGuardian);
  }

  function testFuzz_Emit_VetoGuardianModified(address _caller, address _newVetoGuardian) public {
    address _oldVetoGuardian = vetoGovernor.vetoGuardian();

    vm.expectEmit();
    emit GovernorVetoGuardian.VetoGuardianModified(_oldVetoGuardian, _newVetoGuardian);
    vm.prank(_caller);
    vetoGovernor.exposed_SetVetoGuardian(_newVetoGuardian);
  }
}
