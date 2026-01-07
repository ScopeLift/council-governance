// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

/// External Dependencies
import {
  IGovernor,
  GovernorCountingSimple
} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

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
  address whale = makeAddr("whale");

  address[] internal targets;
  uint256[] internal values;
  bytes[] internal calldatas;

  function setUp() public {
    vetoOverrideMock = new GovernorVetoOverrideMock(mainDao, 2 weeks);
    vm.label(address(vetoOverrideMock), "vetoOverrideMock");

    vetoOverrideMock.daoToken().mint(whale, vetoOverrideMock.quorum(0));
    vm.prank(whale);
    vetoOverrideMock.daoToken().delegate(whale);
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

    _assertProposalState(_proposalId, IGovernor.ProposalState.Pending);
  }

  function _submitAndCancelProposal(address _proposer, Proposal memory _proposal)
    internal
    returns (uint256 _proposalId)
  {
    vm.startPrank(_proposer);
    _proposalId = vetoOverrideMock.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
    vetoOverrideMock.cancel(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
    vm.stopPrank();

    _assertProposalState(_proposalId, IGovernor.ProposalState.Canceled);
  }

  function _submitAndPassProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposal(_proposer, _proposal);
    vm.warp(vetoOverrideMock.proposalSnapshot(_proposalId) + 1);

    vm.prank(whale);
    vetoOverrideMock.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.For));

    vm.warp(vetoOverrideMock.proposalDeadline(_proposalId) + 1);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  /// @notice Creates a defeated proposal by having a whale vote against it
  function _submitAndDefeatProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposal(_proposer, _proposal);
    vm.warp(block.timestamp + vetoOverrideMock.votingDelay() + 1);

    vm.prank(whale);
    vetoOverrideMock.castVote(_proposalId, 0);

    vm.warp(block.timestamp + vetoOverrideMock.votingPeriod() + 1);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function _queueProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitAndPassProposal(_proposer, _proposal);
    vetoOverrideMock.queue(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }

  function _queueAndExecuteProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _queueProposal(_proposer, _proposal);
    vetoOverrideMock.execute(
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
    vetoOverrideMock.exposed_setOverrideRole(_newVetoOverrideRole);

    assertEq(vetoOverrideMock.vetoOverrideRole(), _newVetoOverrideRole);
  }

  function testFuzz_EmitsVetoOverrideRoleSet(address _newVetoOverrideRole) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverrideRoleSet(
      vetoOverrideMock.vetoOverrideRole(), _newVetoOverrideRole
    );

    vetoOverrideMock.exposed_setOverrideRole(_newVetoOverrideRole);
  }
}

contract _setOverrideDuration is GovernorVetoOverrideTest {
  function testFuzz_UpdatesOverrideDuration(uint48 _newVetoOverrideDuration) public {
    vetoOverrideMock.exposed_setOverrideDuration(_newVetoOverrideDuration);

    assertEq(vetoOverrideMock.vetoOverrideDuration(), _newVetoOverrideDuration);
  }

  function testFuzz_EmitsVetoOverrideDurationSet(uint48 _newVetoOverrideDuration) public {
    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverrideDurationSet(
      vetoOverrideMock.vetoOverrideDuration(), _newVetoOverrideDuration
    );

    vetoOverrideMock.exposed_setOverrideDuration(_newVetoOverrideDuration);
  }
}

contract OverrideVeto is GovernorVetoOverrideTest {
  function testFuzz_OverridesVetoWhenProposalIsDefeated(address _proposer) public {
    uint256 _proposalId = _submitAndDefeatProposal(_proposer, _buildEmptyProposal());

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
    assertEq(vetoOverrideMock.isVetoOverridden(_proposalId), true);
  }

  function testFuzz_EmitsVetoOverridden(address _proposer) public {
    uint256 _proposalId = _submitAndDefeatProposal(_proposer, _buildEmptyProposal());

    vm.expectEmit();
    emit GovernorVetoOverride.VetoOverridden(_proposalId);
    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
  }

  function testFuzz_RevertIf_VetoAlreadyOverridden(address _proposer) public {
    uint256 _proposalId = _submitAndDefeatProposal(_proposer, _buildEmptyProposal());

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vm.expectRevert(
      abi.encodeWithSelector(
        GovernorVetoOverride.VetoOverrideUnexpectedState.selector,
        _proposalId,
        IGovernor.ProposalState.Succeeded
      )
    );
    vetoOverrideMock.overrideVeto(_proposalId);
  }

  function testFuzz_RevertIf_CallerIsNotVetoOverrideRole(address _proposer, address _caller)
    public
  {
    vm.assume(_caller != vetoOverrideMock.vetoOverrideRole());
    uint256 _proposalId = _submitAndDefeatProposal(_proposer, _buildEmptyProposal());

    vm.expectRevert(
      abi.encodeWithSelector(GovernorVetoOverride.VetoOverrideUnauthorizedAccount.selector, _caller)
    );
    vm.prank(_caller);
    vetoOverrideMock.overrideVeto(_proposalId);
  }

  function testFuzz_RevertIf_StateIsNotDefeated(address _proposer, uint8 _proposalState) public {
    _proposalState = uint8(
      bound(
        _proposalState,
        uint8(IGovernor.ProposalState.Pending),
        uint8(IGovernor.ProposalState.Executed)
      )
    );
    vm.assume(_proposalState != uint8(IGovernor.ProposalState.Defeated));
    vm.assume(_proposalState != uint8(IGovernor.ProposalState.Expired));

    uint256 _proposalId;

    // Create the proposal in the desired state
    if (_proposalState == uint8(IGovernor.ProposalState.Pending)) {
      _proposalId = _submitProposal(_proposer, _buildEmptyProposal());
    } else if (_proposalState == uint8(IGovernor.ProposalState.Canceled)) {
      _proposalId = _submitAndCancelProposal(_proposer, _buildEmptyProposal());
    } else if (_proposalState == uint8(IGovernor.ProposalState.Active)) {
      _proposalId = _submitProposal(_proposer, _buildEmptyProposal());
      vm.warp(block.timestamp + vetoOverrideMock.votingDelay() + 1);
    } else if (_proposalState == uint8(IGovernor.ProposalState.Succeeded)) {
      _proposalId = _submitAndPassProposal(_proposer, _buildEmptyProposal());
    } else if (_proposalState == uint8(IGovernor.ProposalState.Queued)) {
      _proposalId = _queueProposal(_proposer, _buildEmptyProposal());
    } else if (_proposalState == uint8(IGovernor.ProposalState.Executed)) {
      _proposalId = _queueAndExecuteProposal(_proposer, _buildEmptyProposal());
    }

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vm.expectRevert(
      abi.encodeWithSelector(
        GovernorVetoOverride.VetoOverrideUnexpectedState.selector,
        _proposalId,
        IGovernor.ProposalState(_proposalState)
      )
    );
    vetoOverrideMock.overrideVeto(_proposalId);
  }

  function testFuzz_RevertIf_OverrideVetoAfterOverrideWindow(
    address _proposer,
    uint256 _newTimepoint
  ) public {
    uint256 _proposalId = _submitAndDefeatProposal(_proposer, _buildEmptyProposal());

    _newTimepoint = bound(
      _newTimepoint,
      vetoOverrideMock.proposalDeadline(_proposalId) + vetoOverrideMock.vetoOverrideDuration() + 1,
      type(uint48).max
    );
    vm.warp(_newTimepoint);

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vm.expectRevert(
      abi.encodeWithSelector(
        GovernorVetoOverride.VetoOverrideOutsideWindow.selector, _proposalId, _newTimepoint
      )
    );
    vetoOverrideMock.overrideVeto(_proposalId);
  }
}

contract State is GovernorVetoOverrideTest {
  function testFuzz_StateRemainsDefeatedWhenVetoIsNotOverridden(
    address _proposer,
    uint48 _newTimepoint
  ) public {
    uint256 _proposalId = _submitAndDefeatProposal(_proposer, _buildEmptyProposal());
    _newTimepoint = uint48(bound(_newTimepoint, vetoOverrideMock.clock(), type(uint48).max));
    vm.warp(_newTimepoint);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_StateRemainsSucceededUponVetoOverride(address _proposer, uint48 _newTimepoint)
    public
  {
    uint256 _proposalId = _submitAndDefeatProposal(_proposer, _buildEmptyProposal());

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);

    uint256 _currentTimepoint = vetoOverrideMock.clock();
    _newTimepoint = uint48(bound(_newTimepoint, _currentTimepoint, type(uint48).max));
    vm.warp(_newTimepoint);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function testFuzz_StateRemainsQueuedUponVetoOverride(address _proposer, uint256 _newTimepoint)
    public
  {
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _submitAndDefeatProposal(_proposer, _proposal);

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);

    vetoOverrideMock.queue(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );

    _newTimepoint = bound(_newTimepoint, block.timestamp, type(uint48).max);
    vm.warp(_newTimepoint);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Queued);
  }

  function testFuzz_StateRemainsExecutedUponVetoOverride(address _proposer, uint256 _newTimepoint)
    public
  {
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _submitAndDefeatProposal(_proposer, _proposal);

    vm.prank(vetoOverrideMock.vetoOverrideRole());
    vetoOverrideMock.overrideVeto(_proposalId);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);

    vetoOverrideMock.queue(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );

    vetoOverrideMock.execute(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );

    _newTimepoint = bound(_newTimepoint, block.timestamp, type(uint48).max);
    vm.warp(_newTimepoint);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Executed);
  }
}
