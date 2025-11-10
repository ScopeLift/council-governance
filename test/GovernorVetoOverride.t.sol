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
  GovernorVetoOverrideMock internal councilMock;

  address mainDao = makeAddr("main DAO");
  address councilGovernor = makeAddr("council governor");

  function setUp() public override {
    super.setUp();
    councilMock = new GovernorVetoOverrideMock(daoToken, mainDao, 2 weeks);
    vm.label(address(councilMock), "councilMock");
  }

  function _submitProposal(Proposal memory _proposal) internal returns (uint256 _proposalId) {
    vm.prank(councilGovernor);
    _proposalId = councilMock.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
  }

  /// @notice In the actual implementation, a proposal is defeated by the main DAO or the veto
  /// governor. Since we are not inheriting either in our unit test, not reaching quorum suffices to
  /// defeat the proposal.
  function _createDefeatedProposal() public returns (uint256 _proposalId) {
    _proposalId = _submitProposal(_buildEmptyProposal());
    vm.warp(block.timestamp + councilMock.votingDelay() + councilMock.votingPeriod() + 1);
  }

  function _assertProposalState(uint256 proposalId, IGovernor.ProposalState expected) internal view {
    assertEq(uint8(councilMock.state(proposalId)), uint8(expected));
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
    councilMock.exposed_SetOverrideRole(_newVetoOverrideRole);

    assertEq(councilMock.vetoOverrideRole(), _newVetoOverrideRole);
  }

  function testFuzz_EmitsVetoOverrideRoleSet(address _newVetoOverrideRole) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverrideRoleSet(
      councilMock.vetoOverrideRole(), _newVetoOverrideRole
    );

    councilMock.exposed_SetOverrideRole(_newVetoOverrideRole);
  }
}

contract _setOverrideDuration is GovernorVetoOverrideTest {
  function testFuzz_UpdatesOverrideDuration(uint48 _newVetoOverrideDuration) public {
    councilMock.exposed_SetOverrideDuration(_newVetoOverrideDuration);

    assertEq(councilMock.vetoOverrideDuration(), _newVetoOverrideDuration);
  }

  function testFuzz_EmitsVetoOverrideDurationSet(uint48 _newVetoOverrideDuration) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverrideDurationSet(
      councilMock.vetoOverrideDuration(), _newVetoOverrideDuration
    );

    councilMock.exposed_SetOverrideDuration(_newVetoOverrideDuration);
  }
}

contract OverrideVeto is GovernorVetoOverrideTest {
  function test_OverridesVeto() public {
    uint256 _proposalId = _createDefeatedProposal();

    vm.prank(councilMock.vetoOverrideRole());
    councilMock.overrideVeto(_proposalId);
    assertEq(councilMock.isVetoOverridden(_proposalId), true);
  }

  function test_EmitsVetoOverridden(uint256 _proposalId) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverridden(_proposalId);
    vm.prank(councilMock.vetoOverrideRole());
    councilMock.overrideVeto(_proposalId);
  }

  function testFuzz_OverrideVetoWhenProposalDoesNotExist(uint256 _proposalId) public {
    vm.prank(councilMock.vetoOverrideRole());
    councilMock.overrideVeto(_proposalId);
    assertEq(councilMock.isVetoOverridden(_proposalId), true);
  }

  function test_EmitsVetoOverriddenWhenProposalDoesNotExist(uint256 _proposalId) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverridden(_proposalId);
    vm.prank(councilMock.vetoOverrideRole());
    councilMock.overrideVeto(_proposalId);
  }

  function testFuzz_RevertIf_CallerIsNotVetoOverrideRole(address _caller) public {
    vm.assume(_caller != councilMock.vetoOverrideRole());
    uint256 _proposalId = _createDefeatedProposal();

    vm.expectRevert();
    vm.prank(_caller);
    councilMock.overrideVeto(_proposalId);
  }
}

contract State is GovernorVetoOverrideTest {
  function test_ReturnsOriginalStateWhenStateIsPending() public {
    uint256 _proposalId = _submitProposal(_buildEmptyProposal());

    vm.prank(councilMock.vetoOverrideRole());
    councilMock.overrideVeto(_proposalId);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Pending);
  }

  function test_ReturnsOriginalStateWhenStateIsActive() public {
    uint256 _proposalId = _submitProposal(_buildEmptyProposal());
    vm.warp(block.timestamp + councilMock.votingDelay() + 1);

    vm.prank(councilMock.vetoOverrideRole());
    councilMock.overrideVeto(_proposalId);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Active);
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

    vm.prank(councilMock.vetoOverrideRole());
    councilMock.overrideVeto(_proposalId);
    _newTimestamp = uint48(
      bound(_newTimestamp, block.timestamp, block.timestamp + councilMock.vetoOverrideDuration())
    );
    vm.warp(_newTimestamp);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function test_StateReturnsDefeatedWhenVetoOverriddenAndOverrideDurationExpired(
    uint48 _newTimestamp
  ) public {
    uint256 _proposalId = _createDefeatedProposal();

    vm.prank(councilMock.vetoOverrideRole());
    councilMock.overrideVeto(_proposalId);
    _newTimestamp = uint48(
      bound(
        _newTimestamp,
        councilMock.proposalDeadline(_proposalId) + councilMock.vetoOverrideDuration() + 1,
        type(uint48).max
      )
    );
    vm.warp(_newTimestamp);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }
}
