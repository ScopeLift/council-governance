// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Dependencies
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal Dependencies
import {
  GovernorExtendVetoPeriod,
  GovernorExtendVetoPeriodMock
} from "test/mocks/GovernorExtendVetoPeriodMock.sol";

// Test Dependencies
import {Test} from "forge-std/Test.sol";

contract GovernorVetoExtensionTest is Test {
  GovernorExtendVetoPeriodMock internal vetoMock;

  uint48 internal constant INITIAL_VETO_PERIOD_EXTENSION = 3 days;
  uint16 internal constant INITIAL_VETO_PERIOD_EXTENSION_THRESHOLD_PCT = 50;

  function setUp() public {
    vetoMock = new GovernorExtendVetoPeriodMock(
      INITIAL_VETO_PERIOD_EXTENSION, INITIAL_VETO_PERIOD_EXTENSION_THRESHOLD_PCT
    );
  }

  function _createProposal(address _target, uint256 _value, bytes memory _calldata)
    internal
    returns (uint256 _proposalId)
  {
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    bytes[] memory _calldatas = new bytes[](1);
    _targets[0] = _target;
    _values[0] = _value;
    _calldatas[0] = _calldata;

    _proposalId = vetoMock.propose(_targets, _values, _calldatas, "");
  }

  function _castVoteOnProposal(uint256 _proposalId, address _account, uint256 _weight) public {
    vm.assume(_account != address(0));
    vetoMock.exposed_countVote(_proposalId, _account, 0, _weight, "");
  }

  function _createProposalAndCastVetoVote(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account,
    uint256 _weight
  ) internal returns (uint256 _proposalId) {
    _proposalId = _createProposal(_target, _value, _calldata);
    _castVoteOnProposal(_proposalId, _account, _weight);
  }

  function _minorThresholdAtProposal(uint256 _proposalId) internal view returns (uint256) {
    uint256 _snapshot = vetoMock.proposalSnapshot(_proposalId);
    return Math.mulDiv(
      vetoMock.vetoThreshold(_snapshot),
      vetoMock.minorVetoExtensionThresholdPct(_snapshot),
      vetoMock.minorVetoExtensionThresholdDenominator()
    );
  }

  function _triggerExtension(uint256 _proposalId) internal {
    vetoMock.forceTriggerVotingPeriodExtensionThreshold();
    vetoMock.exposed_TallyUpdated(_proposalId);
  }
}

contract Constructor is GovernorVetoExtensionTest {
  function testFuzz_SetsInitialParameters(
    uint48 _initialVotingPeriodExtension,
    uint16 _initialVotingPeriodExtensionThreshold
  ) public {
    _initialVotingPeriodExtension = uint48(
      bound(_initialVotingPeriodExtension, 0, type(uint48).max)
    );
    _initialVotingPeriodExtensionThreshold = uint16(
      bound(
        _initialVotingPeriodExtensionThreshold, 0, vetoMock.minorVetoExtensionThresholdDenominator()
      )
    );
    GovernorExtendVetoPeriodMock _vetoMock = new GovernorExtendVetoPeriodMock(
      _initialVotingPeriodExtension, _initialVotingPeriodExtensionThreshold
    );

    assertEq(_vetoMock.votingPeriodExtension(), _initialVotingPeriodExtension);
    assertEq(_vetoMock.minorVetoExtensionThresholdPct(), _initialVotingPeriodExtensionThreshold);
  }
}

contract ProposalDeadline is GovernorVetoExtensionTest {
  function testFuzz_PendingProposalUsesNewVotingPeriodExtension(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint48 _newExtension
  ) public {
    uint48 _oldExtension = uint48(vetoMock.votingPeriodExtension());
    vm.assume(_oldExtension != _newExtension);

    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _initialDeadline = vetoMock.proposalDeadline(_proposalId);
    vm.assume(_initialDeadline + _newExtension <= type(uint48).max);

    vm.prank(address(vetoMock));
    vetoMock.setVotingPeriodExtension(_newExtension);

    _triggerExtension(_proposalId);

    assertEq(vetoMock.proposalDeadline(_proposalId), _initialDeadline + _newExtension);
  }

  function testFuzz_ActiveProposalUsesCheckpointedVotingPeriodExtension(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint48 _newExtension
  ) public {
    uint48 _oldExtension = uint48(vetoMock.votingPeriodExtension());
    vm.assume(_oldExtension != _newExtension);

    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _initialDeadline = vetoMock.proposalDeadline(_proposalId);

    vm.warp(vetoMock.proposalSnapshot(_proposalId) + 1);

    vm.prank(address(vetoMock));
    vetoMock.setVotingPeriodExtension(_newExtension);
    _triggerExtension(_proposalId);

    assertEq(vetoMock.proposalDeadline(_proposalId), _initialDeadline + _oldExtension);
  }
}

contract VotingPeriodExtension is GovernorVetoExtensionTest {
  function testFuzz_ReturnsCheckpointedVotingPeriodExtension(
    uint48 _newVotingPeriodExtension,
    uint48 _newTimepoint
  ) public {
    vm.assume(_newTimepoint > vetoMock.clock());

    uint48 _oldVotingPeriodExtension = uint48(vetoMock.votingPeriodExtension(vetoMock.clock()));

    vm.warp(_newTimepoint);
    vm.prank(address(vetoMock));
    vetoMock.setVotingPeriodExtension(_newVotingPeriodExtension);

    assertEq(vetoMock.votingPeriodExtension(_newTimepoint - 1), _oldVotingPeriodExtension);
    assertEq(vetoMock.votingPeriodExtension(_newTimepoint), _newVotingPeriodExtension);
  }
}

contract MinorVetoExtensionThresholdPct is GovernorVetoExtensionTest {
  function testFuzz_ReturnsCheckpointedMinorVetoExtensionThresholdPct(
    uint16 _newMinorThreshold,
    uint48 _newTimepoint
  ) public {
    vm.assume(_newMinorThreshold <= vetoMock.minorVetoExtensionThresholdDenominator());
    vm.assume(_newTimepoint > vetoMock.clock());

    uint16 _oldMinorThreshold = uint16(vetoMock.minorVetoExtensionThresholdPct());
    vm.warp(_newTimepoint);

    vm.prank(address(vetoMock));
    vetoMock.setMinorVetoExtensionThresholdPct(_newMinorThreshold);

    assertEq(vetoMock.minorVetoExtensionThresholdPct(_newTimepoint - 1), _oldMinorThreshold);
    assertEq(vetoMock.minorVetoExtensionThresholdPct(_newTimepoint), _newMinorThreshold);
  }
}

contract VotingPeriodExtensionThreshold is GovernorVetoExtensionTest {
  function test_ReturnsvotingPeriodExtensionThresholdPct() public view {
    assertEq(vetoMock.minorVetoExtensionThresholdPct(), INITIAL_VETO_PERIOD_EXTENSION_THRESHOLD_PCT);
  }
}

contract _votingPeriodExtensionThresholdTriggered is GovernorVetoExtensionTest {
  function testFuzz_VotingPeriodNotExtendedWhenThresholdNotReached(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account,
    uint256 _weight
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _threshold = _minorThresholdAtProposal(_proposalId);
    vm.assume(_threshold > 0);

    _weight = bound(_weight, 0, _threshold - 1);
    _castVoteOnProposal(_proposalId, _account, _weight);

    assertFalse(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }

  function testFuzz_VotingPeriodExtendedWhenVetoVotesAtThreshold(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _threshold = _minorThresholdAtProposal(_proposalId);
    vm.assume(_threshold > 0);
    _castVoteOnProposal(_proposalId, _account, _threshold);

    assertTrue(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }

  function testFuzz_VotingPeriodExtendedWhenVetoVotesAboveThreshold(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account,
    uint256 _weight
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _threshold = _minorThresholdAtProposal(_proposalId);
    vm.assume(_threshold > 0);

    _weight = bound(_weight, _threshold, type(uint256).max);
    _castVoteOnProposal(_proposalId, _account, _weight);

    assertTrue(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }

  function testFuzz_PendingProposalUseNewVetoExtensionThresholdPct(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint16 _lowThresholdPct,
    address _voter,
    uint256 _voteWeight
  ) public {
    uint256 _highThresholdPct = vetoMock.minorVetoExtensionThresholdPct();
    _lowThresholdPct = uint16(bound(_lowThresholdPct, 1, _highThresholdPct - 1));

    vm.prank(address(vetoMock));
    vetoMock.setMinorVetoExtensionThresholdPct(_lowThresholdPct);
    uint256 _proposalId = _createProposal(_target, _value, _calldata);

    uint256 _lowMinorThreshold = Math.mulDiv(
      vetoMock.vetoThreshold(vetoMock.proposalSnapshot(_proposalId)),
      _lowThresholdPct,
      vetoMock.minorVetoExtensionThresholdDenominator()
    );

    uint256 _highMinorThreshold = Math.mulDiv(
      vetoMock.vetoThreshold(vetoMock.proposalSnapshot(_proposalId)),
      _highThresholdPct,
      vetoMock.minorVetoExtensionThresholdDenominator()
    );

    _voteWeight = bound(_voteWeight, _lowMinorThreshold, _highMinorThreshold - 1);
    _castVoteOnProposal(_proposalId, _voter, _voteWeight);

    assertTrue(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }

  function testFuzz_UseCheckpointedValueWhenCalculatingVetoExtensionThresholdPct(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint16 _highThresholdPct,
    uint16 _lowThresholdPct,
    address _voter,
    uint256 _voteWeight
  ) public {
    _highThresholdPct = uint16(
      bound(_highThresholdPct, 51, vetoMock.minorVetoExtensionThresholdDenominator())
    );
    _lowThresholdPct = uint16(bound(_lowThresholdPct, 1, _highThresholdPct - 1));

    vm.prank(address(vetoMock));
    vetoMock.setMinorVetoExtensionThresholdPct(_highThresholdPct);
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _proposalSnapshot = vetoMock.proposalSnapshot(_proposalId);

    vm.warp(_proposalSnapshot + 1);

    vm.prank(address(vetoMock));
    vetoMock.setMinorVetoExtensionThresholdPct(_lowThresholdPct);

    uint256 _lowMinorThreshold = Math.mulDiv(
      vetoMock.vetoThreshold(_proposalSnapshot),
      _lowThresholdPct,
      vetoMock.minorVetoExtensionThresholdDenominator()
    );

    uint256 _highMinorThreshold = Math.mulDiv(
      vetoMock.vetoThreshold(_proposalSnapshot),
      _highThresholdPct,
      vetoMock.minorVetoExtensionThresholdDenominator()
    );

    _voteWeight = bound(_voteWeight, _lowMinorThreshold, _highMinorThreshold - 1);
    _castVoteOnProposal(_proposalId, _voter, _voteWeight);

    assertFalse(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }

  function test_ExtensionDisabledWhenThresholdIsZero(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account,
    uint256 _weight
  ) public {
    vm.prank(address(vetoMock));
    vetoMock.setMinorVetoExtensionThresholdPct(0);
    uint256 _proposalId =
      _createProposalAndCastVetoVote(_target, _value, _calldata, _account, _weight);

    assertFalse(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }
}

contract _setVotingPeriodExtension is GovernorVetoExtensionTest {
  function testFuzz_SetVotingPeriodExtension(uint48 _newVotingPeriodExtension) public {
    vm.prank(address(vetoMock));
    vetoMock.setVotingPeriodExtension(_newVotingPeriodExtension);

    assertEq(vetoMock.votingPeriodExtension(), _newVotingPeriodExtension);
  }

  function testFuzz_EmitsVotingPeriodExtensionSet(uint48 _newVotingPeriodExtension) public {
    vm.expectEmit();
    emit GovernorExtendVetoPeriod.VotingPeriodExtensionSet(
      vetoMock.votingPeriodExtension(), _newVotingPeriodExtension
    );

    vm.prank(address(vetoMock));
    vetoMock.setVotingPeriodExtension(_newVotingPeriodExtension);
  }
}

contract _setMinorVetoExtensionThreshold is GovernorVetoExtensionTest {
  function testFuzz_setMinorVetoExtensionThresholdPct(uint16 _newVotingPeriodExtensionThreshold)
    public
  {
    _newVotingPeriodExtensionThreshold = uint16(
      bound(
        _newVotingPeriodExtensionThreshold, 0, vetoMock.minorVetoExtensionThresholdDenominator()
      )
    );
    vm.prank(address(vetoMock));
    vetoMock.setMinorVetoExtensionThresholdPct(_newVotingPeriodExtensionThreshold);

    assertEq(vetoMock.minorVetoExtensionThresholdPct(), _newVotingPeriodExtensionThreshold);
  }

  function testFuzz_EmitsvotingPeriodExtensionThresholdPctSet(uint16 _newVetoPeriodExtensionThresholdPct)
    public
  {
    _newVetoPeriodExtensionThresholdPct = uint16(
      bound(
        _newVetoPeriodExtensionThresholdPct, 0, vetoMock.minorVetoExtensionThresholdDenominator()
      )
    );

    vm.expectEmit();
    emit GovernorExtendVetoPeriod.MinorVetoExtensionThresholdPctSet(
      vetoMock.minorVetoExtensionThresholdPct(), _newVetoPeriodExtensionThresholdPct
    );
    vm.prank(address(vetoMock));
    vetoMock.setMinorVetoExtensionThresholdPct(_newVetoPeriodExtensionThresholdPct);
  }

  function testFuzz_RevertIf_SetVotingPeriodExtensionAbovePercentDenominator(uint16 _newVetoPeriodExtensionThresholdPct)
    public
  {
    _newVetoPeriodExtensionThresholdPct = uint16(
      bound(
        _newVetoPeriodExtensionThresholdPct,
        vetoMock.minorVetoExtensionThresholdDenominator() + 1,
        type(uint16).max
      )
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        GovernorExtendVetoPeriod.GovernorExtendVetoPeriod_InvalidThreshold.selector,
        _newVetoPeriodExtensionThresholdPct
      )
    );

    vm.prank(address(vetoMock));
    vetoMock.setMinorVetoExtensionThresholdPct(_newVetoPeriodExtensionThresholdPct);
  }
}

contract _tallyUpdated is GovernorVetoExtensionTest {
  function testFuzz_ProposalDeadlineExtendedWhenVetoExtensionTriggered(
    address _target,
    uint256 _value,
    bytes memory _calldata
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _oldDeadline = vetoMock.proposalDeadline(_proposalId);

    _triggerExtension(_proposalId);

    uint256 _expectedDeadline = _oldDeadline + vetoMock.votingPeriodExtension();
    assertGt(_expectedDeadline, _oldDeadline);
    assertEq(vetoMock.proposalDeadline(_proposalId), _expectedDeadline);
  }

  function testFuzz_EmitsProposalDeadlineExtended(
    address _target,
    uint256 _value,
    bytes memory _calldata
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _expectedDeadline =
      vetoMock.proposalDeadline(_proposalId) + vetoMock.votingPeriodExtension();
    vetoMock.forceTriggerVotingPeriodExtensionThreshold();

    vm.expectEmit();
    emit GovernorExtendVetoPeriod.ProposalExtended(_proposalId, _expectedDeadline);
    vetoMock.exposed_TallyUpdated(_proposalId);
  }

  function testFuzz_DeadlineNotExtendedWhenVetoExtensionAlreadyTriggered(
    address _target,
    uint256 _value,
    bytes memory _calldata
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _oldDeadline = vetoMock.proposalDeadline(_proposalId);
    _triggerExtension(_proposalId);
    uint256 _expectedDeadline = _oldDeadline + vetoMock.votingPeriodExtension();
    assertGt(_expectedDeadline, _oldDeadline);

    vetoMock.exposed_TallyUpdated(_proposalId);

    assertEq(vetoMock.proposalDeadline(_proposalId), _expectedDeadline);
  }

  function testFuzz_DeadlineNotExtendedWhenVotingPeriodExtensionThresholdIsFalse(
    address _target,
    uint256 _value,
    bytes memory _calldata
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _expectedProposalDeadline = vetoMock.proposalDeadline(_proposalId);
    assertFalse(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));

    vetoMock.exposed_TallyUpdated(_proposalId);

    assertEq(vetoMock.proposalDeadline(_proposalId), _expectedProposalDeadline);
  }
}
