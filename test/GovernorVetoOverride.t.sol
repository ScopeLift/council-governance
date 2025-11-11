// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {OptimisticGovernanceTestBase} from "test/helpers/OptimisticGovernanceTestBase.sol";
import {
  GovernorVetoOverride, GovernorVetoOverrideMock
} from "test/mocks/GovernorVetoOverrideMock.sol";

contract GovernorVetoOverrideTest is OptimisticGovernanceTestBase {
  GovernorVetoOverrideMock internal vetoOverrideMock;

  address mainDao = makeAddr("main DAO");
  address councilGovernor = makeAddr("council governor");

  function setUp() public override {
    super.setUp();
    vetoOverrideMock = new GovernorVetoOverrideMock(daoToken, mainDao, 2 weeks);
    vm.label(address(vetoOverrideMock), "vetoOverrideMock");
  }

  function _submitProposal(Proposal memory _proposal) internal returns (uint256 _proposalId) {
    vm.prank(councilGovernor);
    _proposalId = vetoOverrideMock.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
  }

  /// @notice Manually sets proposal to defeated by manipulating the return state of
  /// `_quorumReached`
  /// and `_voteSucceeded`
  function _createDefeatedProposal() public returns (uint256 _proposalId) {
    _proposalId = _submitProposal(_buildEmptyProposal());
    vetoOverrideMock.setDefeated(_proposalId, true);
    vm.warp(block.timestamp + vetoOverrideMock.votingDelay() + vetoOverrideMock.votingPeriod() + 1);
  }

  function _assertProposalState(uint256 proposalId, IGovernor.ProposalState expected) internal view {
    assertEq(uint8(vetoOverrideMock.state(proposalId)), uint8(expected));
  }
}

contract Constructor is OptimisticGovernanceTestBase {
  function testFuzz_SetsInitialParameters(address _vetoOverrideRole, uint48 _vetoOverrideDuration)
    public
  {
    GovernorVetoOverrideMock mock =
      new GovernorVetoOverrideMock(daoToken, _vetoOverrideRole, _vetoOverrideDuration);

    assertEq(mock.vetoOverrideRole(), _vetoOverrideRole);
    assertEq(mock.vetoOverrideDuration(), _vetoOverrideDuration);
  }
}

contract _setOverrideRole is GovernorVetoOverrideTest {
  function testFuzz_UpdatesOverrideRole(address _newVetoOverrideRole) public {
    vetoOverrideMock.exposed_SetOverrideRole(_newVetoOverrideRole);

    assertEq(vetoOverrideMock.vetoOverrideRole(), _newVetoOverrideRole);
  }

  function testFuzz_EmitsVetoOverrideRoleSet(address _newVetoOverrideRole) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverrideRoleSet(
      vetoOverrideMock.vetoOverrideRole(), _newVetoOverrideRole
    );

    vetoOverrideMock.exposed_SetOverrideRole(_newVetoOverrideRole);
  }
}

contract _setOverrideDuration is GovernorVetoOverrideTest {
  function testFuzz_UpdatesOverrideDuration(uint48 _newVetoOverrideDuration) public {
    vetoOverrideMock.exposed_SetOverrideDuration(_newVetoOverrideDuration);

    assertEq(vetoOverrideMock.vetoOverrideDuration(), _newVetoOverrideDuration);
  }

  function testFuzz_EmitsVetoOverrideDurationSet(uint48 _newVetoOverrideDuration) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverrideDurationSet(
      vetoOverrideMock.vetoOverrideDuration(), _newVetoOverrideDuration
    );

    vetoOverrideMock.exposed_SetOverrideDuration(_newVetoOverrideDuration);
  }
}

contract OverrideVeto is GovernorVetoOverrideTest {
  function test_OverridesVeto() public {
    uint256 _proposalId = _createDefeatedProposal();

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
    assertEq(vetoOverrideMock.isVetoOverridden(_proposalId), true);
  }

  function test_EmitsVetoOverridden(uint256 _proposalId) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverridden(_proposalId);
    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
  }

  function testFuzz_OverrideVetoWhenProposalDoesNotExist(uint256 _proposalId) public {
    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
    assertEq(vetoOverrideMock.isVetoOverridden(_proposalId), true);
  }

  function test_EmitsVetoOverriddenWhenProposalDoesNotExist(uint256 _proposalId) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverridden(_proposalId);
    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
  }

  function testFuzz_RevertIf_CallerIsNotVetoOverrideRole(address _caller) public {
    vm.assume(_caller != vetoOverrideMock.vetoOverrideRole());
    uint256 _proposalId = _createDefeatedProposal();

    vm.expectRevert();
    vm.prank(_caller);
    vetoOverrideMock.overrideVeto(_proposalId);
  }
}

contract State is GovernorVetoOverrideTest {
  function test_ReturnsOriginalStateWhenStateIsPending(uint48 _newTimestamp) public {
    uint256 _proposalId = _submitProposal(_buildEmptyProposal());
    _newTimestamp = uint48(bound(_newTimestamp, block.timestamp, vetoOverrideMock.votingDelay()));
    vm.warp(_newTimestamp);

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Pending);
  }

  function test_ReturnsOriginalStateWhenStateIsActive(uint48 _newTimestamp) public {
    uint256 _proposalId = _submitProposal(_buildEmptyProposal());
    _newTimestamp = uint48(
      bound(
        _newTimestamp,
        block.timestamp + vetoOverrideMock.votingDelay() + 1,
        block.timestamp + vetoOverrideMock.votingDelay() + vetoOverrideMock.votingPeriod()
      )
    );
    vm.warp(_newTimestamp);

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Active);
  }

  function test_ReturnsOriginalStateWhenStateIsSucceeded(uint48 _newTimestamp) public {
    uint256 _proposalId = _submitProposal(_buildEmptyProposal());
    _newTimestamp = uint48(
      bound(
        _newTimestamp,
        block.timestamp + vetoOverrideMock.votingDelay() + vetoOverrideMock.votingPeriod() + 1,
        type(uint48).max
      )
    );
    vm.warp(_newTimestamp);

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function testFuzz_ReturnsDefeatedWhenVetoIsNotOverridden(uint48 _newTimestamp) public {
    uint256 _proposalId = _createDefeatedProposal();
    _newTimestamp = uint48(bound(_newTimestamp, block.timestamp, type(uint48).max));
    vm.warp(_newTimestamp);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_ReturnsSucceededWhenVetoOverriddenAndOverrideDurationHasNotExpired(
    uint48 _newTimestamp
  ) public {
    uint256 _proposalId = _createDefeatedProposal();

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
    _newTimestamp = uint48(
      bound(
        _newTimestamp, block.timestamp, block.timestamp + vetoOverrideMock.vetoOverrideDuration()
      )
    );
    vm.warp(_newTimestamp);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function test_ReturnsDefeatedWhenVetoOverriddenAndOverrideDurationExpired(uint48 _newTimestamp)
    public
  {
    uint256 _proposalId = _createDefeatedProposal();

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
    _newTimestamp = uint48(
      bound(
        _newTimestamp,
        vetoOverrideMock.proposalDeadline(_proposalId) + vetoOverrideMock.vetoOverrideDuration() + 1,
        type(uint48).max
      )
    );
    vm.warp(_newTimestamp);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }
}
