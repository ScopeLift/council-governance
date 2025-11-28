// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// External Dependencies
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// Internal Dependencies
import {GovernorVetoOverride} from "src/extensions/GovernorVetoOverride.sol";

/// Test Dependencies
import {Test} from "forge-std/Test.sol";
import {GovernorVetoOverrideMock} from "test/mocks/GovernorVetoOverrideMock.sol";

contract GovernorVetoOverrideTest is Test {
  struct Proposal {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  GovernorVetoOverrideMock internal vetoOverrideMock;
  address mainDao = makeAddr("main DAO");

  address[] internal targets;
  uint256[] internal values;
  bytes[] internal calldatas;

  function setUp() public {
    vetoOverrideMock = new GovernorVetoOverrideMock(mainDao, 2 weeks);
    vm.label(address(vetoOverrideMock), "vetoOverrideMock");
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
    internal
    returns (uint256 _proposalId)
  {
    vm.prank(_proposer);
    _proposalId = vetoOverrideMock.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
  }

  /// @notice Manually sets proposal to defeated by manipulating the return state of
  /// `_quorumReached`
  /// and `_voteSucceeded`
  function _createDefeatedProposal(address _proposer) public returns (uint256 _proposalId) {
    _proposalId = _submitProposal(_proposer, _buildEmptyProposal());
    vetoOverrideMock.setDefeated(_proposalId, true);
    vm.warp(block.timestamp + vetoOverrideMock.votingDelay() + vetoOverrideMock.votingPeriod() + 1);
  }

  function _assertProposalState(uint256 _proposalId, IGovernor.ProposalState _expected)
    internal
    view
  {
    assertEq(uint8(vetoOverrideMock.state(_proposalId)), uint8(_expected));
  }
}

contract Constructor is Test {
  function testFuzz_SetsInitialParameters(address _vetoOverrideRole, uint48 _vetoOverrideDuration)
    public
  {
    GovernorVetoOverrideMock _mock =
      new GovernorVetoOverrideMock(_vetoOverrideRole, _vetoOverrideDuration);

    assertEq(_mock.vetoOverrideRole(), _vetoOverrideRole);
    assertEq(_mock.vetoOverrideDuration(), _vetoOverrideDuration);
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
  function testFuzz_OverridesVeto(address _proposer) public {
    uint256 _proposalId = _createDefeatedProposal(_proposer);

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
    assertEq(vetoOverrideMock.isVetoOverridden(_proposalId), true);
  }

  function testFuzz_OverrideVetoWhenProposalDoesNotExist(uint256 _proposalId) public {
    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
    assertEq(vetoOverrideMock.isVetoOverridden(_proposalId), true);
  }

  function testFuzz_EmitsVetoOverridden(uint256 _proposalId) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverridden(_proposalId);
    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
  }

  function testFuzz_EmitsVetoOverriddenWhenProposalDoesNotExist(uint256 _proposalId) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverridden(_proposalId);
    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
  }

  function testFuzz_RevertIf_CallerIsNotVetoOverrideRole(address _proposer, address _caller) public {
    vm.assume(_caller != vetoOverrideMock.vetoOverrideRole());
    uint256 _proposalId = _createDefeatedProposal(_proposer);

    vm.expectRevert(bytes("GovernorVetoOverride: caller is not the veto override role"));
    vm.prank(_caller);
    vetoOverrideMock.overrideVeto(_proposalId);
  }
}

contract State is GovernorVetoOverrideTest {
  function testFuzz_ReturnsOriginalStateWhenStateIsPending(address _proposer, uint48 _newTimestamp)
    public
  {
    uint256 _proposalId = _submitProposal(_proposer, _buildEmptyProposal());
    _newTimestamp = uint48(bound(_newTimestamp, block.timestamp, vetoOverrideMock.votingDelay()));
    vm.warp(_newTimestamp);

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Pending);
  }

  function testFuzz_ReturnsOriginalStateWhenStateIsActive(address _proposer, uint48 _newTimestamp)
    public
  {
    uint256 _proposalId = _submitProposal(_proposer, _buildEmptyProposal());
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

  function testFuzz_ReturnsOriginalStateWhenStateIsSucceeded(
    address _proposer,
    uint48 _newTimestamp
  ) public {
    uint256 _proposalId = _submitProposal(_proposer, _buildEmptyProposal());
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

  function testFuzz_ReturnsDefeatedWhenVetoIsNotOverridden(address _proposer, uint48 _newTimestamp)
    public
  {
    uint256 _proposalId = _createDefeatedProposal(_proposer);
    _newTimestamp = uint48(bound(_newTimestamp, block.timestamp, type(uint48).max));
    vm.warp(_newTimestamp);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_ReturnsSucceededWhenVetoOverriddenAndOverrideDurationHasNotExpired(
    address _proposer,
    uint48 _newTimestamp
  ) public {
    uint256 _proposalId = _createDefeatedProposal(_proposer);

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

  function testFuzz_ReturnsDefeatedWhenVetoOverriddenAndOverrideDurationExpired(
    address _proposer,
    uint48 _newTimestamp
  ) public {
    uint256 _proposalId = _createDefeatedProposal(_proposer);

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
