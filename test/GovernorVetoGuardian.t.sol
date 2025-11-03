// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BasicCouncilVetoGovernorTest} from "./BasicCouncilVetoGovernor.t.sol";
import {GovernorVetoGuardian} from "../src/extensions/GovernorVetoGuardian.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

contract GovernorVetoGuardianTest is BasicCouncilVetoGovernorTest {
  function _forwardProposalThatUpdatesVetoGuardian(
    address _newVetoGuardian,
    string memory _description
  ) internal returns (uint256 proposalId) {
    targets[0] = address(vetoGovernor);
    calldatas[0] = abi.encodeCall(GovernorVetoGuardian.setVetoGuardian, _newVetoGuardian);

    proposalId = _proposeAndForwardToVetoGovernor(_description);
  }

  function _warpPastVotingPeriod() internal {
    vm.warp(block.timestamp + vetoGovernor.votingDelay() + vetoGovernor.votingPeriod() + 1);
  }

  function _assertProposalState(uint256 proposalId, IGovernor.ProposalState expected) internal view {
    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(expected));
  }
}

contract SetVetoGuardian is GovernorVetoGuardianTest {
  // TODO: This test should pass only when called by the main DAO, and fail when called by the
  // council.
  function testFuzz_CouncilSetsVetoGuardian(address _newVetoGuardian) public {
    string memory _description = "Set new veto guardian";
    bytes32 _descriptionHash = keccak256(bytes(_description));

    _forwardProposalThatUpdatesVetoGuardian(_newVetoGuardian, _description);
    _warpPastVotingPeriod();
    vetoGovernor.queue(targets, values, calldatas, _descriptionHash);
    skip(timelock.getMinDelay() + 1);

    councilGovernor.execute(targets, values, calldatas, _descriptionHash);

    assertEq(vetoGovernor.vetoGuardian(), _newVetoGuardian);
  }

  function test_SetsTheSameVetoGuardian() public {
    string memory _description = "Set the same veto guardian";
    bytes32 _descriptionHash = keccak256(bytes(_description));

    _forwardProposalThatUpdatesVetoGuardian(vetoGuardian, _description);
    _warpPastVotingPeriod();
    vetoGovernor.queue(targets, values, calldatas, _descriptionHash);
    skip(timelock.getMinDelay() + 1);

    councilGovernor.execute(targets, values, calldatas, _descriptionHash);

    assertEq(vetoGovernor.vetoGuardian(), vetoGuardian);
  }

  function testFuzz_Emit_VetoGuardianSet(address _newVetoGuardian) public {
    vm.assume(_newVetoGuardian != vetoGuardian);

    address _oldVetoGuardian = vetoGuardian;
    string memory _description = "Emit veto guardian set";
    bytes32 _descriptionHash = keccak256(bytes(_description));

    _forwardProposalThatUpdatesVetoGuardian(_newVetoGuardian, _description);
    _warpPastVotingPeriod();
    vetoGovernor.queue(targets, values, calldatas, _descriptionHash);
    skip(timelock.getMinDelay() + 1);

    vm.expectEmit();
    emit GovernorVetoGuardian.VetoGuardianModified(_oldVetoGuardian, _newVetoGuardian);
    councilGovernor.execute(targets, values, calldatas, _descriptionHash);
  }
}

contract VetoByGuardian is GovernorVetoGuardianTest {
  function test_VetoGuardianVetoesPendingProposal() public {
    uint256 proposalId = _proposeAndForwardToVetoGovernor("Proposal vetoed");
    _assertProposalState(proposalId, IGovernor.ProposalState.Pending);

    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);

    assertEq(vetoGovernor.guardianVetoed(proposalId), true);
    _assertProposalState(proposalId, IGovernor.ProposalState.Defeated);
  }

  function test_VetoGuardianVetoesActiveProposal() public {
    uint256 proposalId = _proposeAndForwardToVetoGovernor("Proposal vetoed");
    skip(vetoGovernor.votingDelay() + 1);
    _assertProposalState(proposalId, IGovernor.ProposalState.Active);

    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);

    assertEq(vetoGovernor.guardianVetoed(proposalId), true);
    _assertProposalState(proposalId, IGovernor.ProposalState.Defeated);
  }

  function test_ProposalVetoedByGuardianIsOverriddenAndExecuted() public {
    string memory _description = "Veto overridden";
    bytes32 _descriptionHash = keccak256(bytes(_description));
    uint256 proposalId = _proposeAndForwardToVetoGovernor(_description);

    skip(vetoGovernor.votingDelay() + 1);
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
    skip(vetoGovernor.votingPeriod() + 1);

    assertEq(vetoGovernor.guardianVetoed(proposalId), true);
    _assertProposalState(proposalId, IGovernor.ProposalState.Defeated);

    vm.prank(deployer);
    vetoGovernor.overrideVeto(proposalId);
    _assertProposalState(proposalId, IGovernor.ProposalState.Succeeded);

    vetoGovernor.queue(targets, values, calldatas, _descriptionHash);
    _assertProposalState(proposalId, IGovernor.ProposalState.Queued);

    skip(timelock.getMinDelay() + 1);
    councilGovernor.execute(targets, values, calldatas, _descriptionHash);
    _assertProposalState(proposalId, IGovernor.ProposalState.Executed);

    assertEq(vetoGovernor.guardianVetoed(proposalId), true);
  }

  function test_Emit_ProposalVetoedByGuardian() public {
    uint256 proposalId = _proposeAndForwardToVetoGovernor("Emit proposal vetoed");
    _assertProposalState(proposalId, IGovernor.ProposalState.Pending);

    vm.expectEmit();
    emit GovernorVetoGuardian.ProposalVetoedByGuardian(proposalId);

    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }

  function testFuzz_RevertIf_OldVetoGuardianVetoesProposal(address _newVetoGuardian) public {
    vm.assume(_newVetoGuardian != vetoGuardian);

    address _oldVetoGuardian = vetoGuardian;
    string memory _description = "Set veto guardian";
    bytes32 _descriptionHash = keccak256(bytes(_description));

    _forwardProposalThatUpdatesVetoGuardian(_newVetoGuardian, _description);
    skip(vetoGovernor.votingDelay() + vetoGovernor.votingPeriod() + 1);
    vetoGovernor.queue(targets, values, calldatas, _descriptionHash);
    skip(timelock.getMinDelay() + 1);
    councilGovernor.execute(targets, values, calldatas, _descriptionHash);
    assertEq(vetoGovernor.vetoGuardian(), _newVetoGuardian);

    uint256 proposalId = _proposeAndForwardToVetoGovernor("Old guardian vetoes");
    vm.expectRevert(
      abi.encodeWithSelector(
        GovernorVetoGuardian.GovernorVetoGuardian_Unauthorized.selector, _oldVetoGuardian
      )
    );
    vm.prank(_oldVetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }

  function test_RevertIf_OldGuardianVetoesAfterRemoval() public {
    address oldGuardian = vetoGuardian;
    string memory _description = "Remove veto guardian";
    bytes32 _descriptionHash = keccak256(bytes(_description));

    _forwardProposalThatUpdatesVetoGuardian(address(0), _description);
    skip(vetoGovernor.votingDelay() + vetoGovernor.votingPeriod() + 1);
    vetoGovernor.queue(targets, values, calldatas, _descriptionHash);
    skip(timelock.getMinDelay() + 1);
    councilGovernor.execute(targets, values, calldatas, _descriptionHash);

    uint256 proposalId = _proposeAndForwardToVetoGovernor("Old guardian vetoes");

    vm.expectRevert(
      abi.encodeWithSelector(
        GovernorVetoGuardian.GovernorVetoGuardian_Unauthorized.selector, oldGuardian
      )
    );
    vm.prank(oldGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
    assertEq(vetoGovernor.isVetoOverridden(proposalId), false);
  }

  // TODO: name it such that it excludes DAO veto
  function testFuzz_RevertIf_NonVetoGuardianVetoesProposal(address _nonVetoGuardian) public {
    vm.assume(_nonVetoGuardian != vetoGuardian);

    uint256 proposalId = _proposeAndForwardToVetoGovernor("Vetoed by non veto guardian");
    skip(vetoGovernor.votingDelay() + 1);

    vm.expectRevert(
      abi.encodeWithSelector(
        GovernorVetoGuardian.GovernorVetoGuardian_Unauthorized.selector, _nonVetoGuardian
      )
    );
    vm.prank(_nonVetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }

  // TODO: current cancel fails, merge `feat/council-cancel`
  function test_RevertIf_VetoGuardianVetoesCanceledProposal() public {
    string memory _description = "Canceled proposal is not forwarded";
    bytes32 _descriptionHash = keccak256(bytes(_description));
    vm.prank(councilMembers[0]);
    uint256 proposalId = councilGovernor.propose(targets, values, calldatas, _description);

    assertEq(uint8(councilGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));
    vm.prank(councilMembers[0]);
    councilGovernor.cancel(targets, values, calldatas, _descriptionHash);

    vm.expectRevert(
      abi.encodeWithSelector(IGovernor.GovernorNonexistentProposal.selector, proposalId)
    );
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }

  function test_RevertIf_VetoGuardianVetoesSucceededProposal() public {
    uint256 proposalId = _proposeAndForwardToVetoGovernor("Not Vetoed");
    skip(vetoGovernor.votingDelay() + vetoGovernor.votingPeriod() + 1);
    _assertProposalState(proposalId, IGovernor.ProposalState.Succeeded);

    vm.expectRevert(GovernorVetoGuardian.GovernorVetoGuardian_UnexpectedProposalState.selector);
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
    _assertProposalState(proposalId, IGovernor.ProposalState.Succeeded);
  }

  function test_RevertIf_VetoGuardianVetoesQueuedProposal() public {
    uint256 proposalId = _proposeAndForwardToVetoGovernor("Already Queued");
    skip(vetoGovernor.votingDelay() + vetoGovernor.votingPeriod() + 1);
    _assertProposalState(proposalId, IGovernor.ProposalState.Succeeded);

    vetoGovernor.queue(targets, values, calldatas, keccak256(bytes("Already Queued")));
    _assertProposalState(proposalId, IGovernor.ProposalState.Queued);

    vm.expectRevert(GovernorVetoGuardian.GovernorVetoGuardian_UnexpectedProposalState.selector);
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }

  function test_RevertIf_VetoGuardianVetoesExecutedProposal() public {
    string memory _description = "Already Executed";
    bytes32 _descriptionHash = keccak256(bytes(_description));
    uint256 proposalId = _proposeAndForwardToVetoGovernor(_description);
    skip(vetoGovernor.votingDelay() + vetoGovernor.votingPeriod() + 1);
    _assertProposalState(proposalId, IGovernor.ProposalState.Succeeded);

    vetoGovernor.queue(targets, values, calldatas, _descriptionHash);
    _assertProposalState(proposalId, IGovernor.ProposalState.Queued);

    skip(timelock.getMinDelay() + 1);
    councilGovernor.execute(targets, values, calldatas, _descriptionHash);
    _assertProposalState(proposalId, IGovernor.ProposalState.Executed);

    vm.expectRevert(GovernorVetoGuardian.GovernorVetoGuardian_UnexpectedProposalState.selector);
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }

  function test_RevertIf_VetoGuardianVetoesTheSameProposalTwice() public {
    uint256 proposalId = _proposeAndForwardToVetoGovernor("Already Vetoed");

    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
    _assertProposalState(proposalId, IGovernor.ProposalState.Defeated);

    vm.expectRevert(
      abi.encodeWithSelector(
        GovernorVetoGuardian.GovernorVetoGuardian_UnexpectedProposalState.selector
      )
    );
    vm.prank(vetoGuardian);
    vetoGovernor.vetoByGuardian(proposalId);
  }
}
