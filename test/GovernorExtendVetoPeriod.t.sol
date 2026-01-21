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

  function _getMinorThreshold(uint256 _timestamp) internal view returns (uint256) {
    return Math.mulDiv(
      vetoMock.vetoThreshold(_timestamp),
      vetoMock.minorVetoExtensionThresholdPct(),
      vetoMock.minorVetoExtensionThresholdDenominator()
    );
  }

  function _assumeVetoVoteBelowMinorThreshold(uint256 _timestamp, uint256 _weight)
    internal
    view
    returns (uint256)
  {
    return bound(_weight, 0, _getMinorThreshold(_timestamp) - 1);
  }

  function _assumeVetoVoteAboveMinorThreshold(uint256 _timestamp, uint256 _weight)
    internal
    view
    returns (uint256)
  {
    return bound(_weight, _getMinorThreshold(_timestamp), type(uint256).max);
  }

  function _boundToIncreaseExtendedDeadline(uint256 _proposalId, uint256 _timestamp)
    internal
    view
    returns (uint256)
  {
    return bound(
      _timestamp,
      vetoMock.proposalDeadline(_proposalId) - vetoMock.votingPeriodExtension() + 1,
      vetoMock.proposalDeadline(_proposalId)
    );
  }

  function _boundBeforeExtensionWindow(uint256 _proposalId, uint256 _timestamp)
    internal
    view
    returns (uint256)
  {
    return bound(
      _timestamp,
      vetoMock.clock(),
      vetoMock.proposalDeadline(_proposalId) - vetoMock.votingPeriodExtension()
    );
  }

  function _warpAndTriggerExtension(uint256 _proposalId, uint256 _timestamp) internal {
    vm.warp(_timestamp);
    vetoMock.forceTriggerVotingPeriodExtensionThreshold();
    vetoMock.exposed_TallyUpdated(_proposalId);
  }

  function _triggerExtensionInWindow(uint256 _proposalId, uint48 _oldExtension)
    internal
    returns (uint256 _timestamp)
  {
    uint256 _deadline = vetoMock.proposalDeadline(_proposalId);
    _timestamp = bound(block.timestamp, _deadline - _oldExtension + 1, _deadline);
    vm.warp(_timestamp);
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

contract VotingPeriodExtension is GovernorVetoExtensionTest {
  function test_ReturnsVotingPeriodExtension() public view {
    assertEq(vetoMock.votingPeriodExtension(), INITIAL_VETO_PERIOD_EXTENSION);
  }
}

contract VotingPeriodExtensionThreshold is GovernorVetoExtensionTest {
  function test_ReturnsvotingPeriodExtensionThresholdPct() public view {
    assertEq(vetoMock.minorVetoExtensionThresholdPct(), INITIAL_VETO_PERIOD_EXTENSION_THRESHOLD_PCT);
  }
}

contract ProposalDeadline is GovernorVetoExtensionTest {
  function testFuzz_ProposalDeadlineUnchangedBeforeExtensionWindow(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint48 _timestamp
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _oldDeadline = vetoMock.proposalDeadline(_proposalId);
    _timestamp = uint48(_boundBeforeExtensionWindow(_proposalId, _timestamp));
    _warpAndTriggerExtension(_proposalId, _timestamp);

    assertEq(vetoMock.proposalDeadline(_proposalId), _oldDeadline);
  }

  function testFuzz_ProposalDeadlineExtendedInsideExtensionWindow(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint48 _timestamp
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _oldDeadline = vetoMock.proposalDeadline(_proposalId);
    _timestamp = uint48(_boundToIncreaseExtendedDeadline(_proposalId, _timestamp));
    _warpAndTriggerExtension(_proposalId, _timestamp);

    uint256 _expectedDeadline = _timestamp + vetoMock.votingPeriodExtension();

    assertGt(_expectedDeadline, _oldDeadline);
    assertEq(vetoMock.proposalDeadline(_proposalId), _expectedDeadline);
  }
}

contract _propose is GovernorVetoExtensionTest {
  function testFuzz_ProposalUsesSnapshotExtension(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint48 _oldExtension,
    uint48 _newExtension
  ) public {
    _oldExtension = uint48(
      bound(_oldExtension, 1, vetoMock.votingDelay() + vetoMock.votingPeriod())
    );
    _newExtension =
      uint48(bound(_newExtension, 1, vetoMock.votingDelay() + vetoMock.votingPeriod()));
    vm.assume(_oldExtension != _newExtension);

    vetoMock.exposed_SetVotingPeriodExtension(_oldExtension);
    uint256 _proposalId = _createProposal(_target, _value, _calldata);

    vetoMock.exposed_SetVotingPeriodExtension(_newExtension);

    uint256 _timestamp = _triggerExtensionInWindow(_proposalId, _oldExtension);
    assertEq(vetoMock.proposalDeadline(_proposalId), _timestamp + _oldExtension);
    assertNotEq(vetoMock.proposalDeadline(_proposalId), _timestamp + _newExtension);
  }

  function testFuzz_ProposalWithHighSnapshotThresholdDoesNotTriggerExtension(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint16 _hightThresholdPct,
    uint16 _lowThresholdPct,
    address _voter
  ) public {
    _hightThresholdPct = uint16(
      bound(_hightThresholdPct, 51, vetoMock.minorVetoExtensionThresholdDenominator())
    );
    _lowThresholdPct = uint16(bound(_lowThresholdPct, 1, 50));

    vetoMock.exposed_setMinorVetoExtensionThresholdPct(_hightThresholdPct);
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _proposalSnapshot = vetoMock.proposalSnapshot(_proposalId);

    vetoMock.exposed_setMinorVetoExtensionThresholdPct(_lowThresholdPct);

    uint256 _highMinorThreshold = Math.mulDiv(
      vetoMock.vetoThreshold(_proposalSnapshot),
      _hightThresholdPct,
      vetoMock.minorVetoExtensionThresholdDenominator()
    );
    uint256 _lowMinorThreshold = Math.mulDiv(
      vetoMock.vetoThreshold(_proposalSnapshot),
      _lowThresholdPct,
      vetoMock.minorVetoExtensionThresholdDenominator()
    );

    uint256 _weight = (_highMinorThreshold + _lowMinorThreshold) / 2;
    _castVoteOnProposal(_proposalId, _voter, _weight);

    assertFalse(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }
}

contract _votingPeriodExtensionThresholdTriggered is GovernorVetoExtensionTest {
  function testFuzz_VotingPeriodNotExtendedWhenThresholdNotReached(
    uint256 _timestamp,
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account,
    uint256 _weight
  ) public {
    _weight = _assumeVetoVoteBelowMinorThreshold(_timestamp, _weight);
    uint256 _proposalId =
      _createProposalAndCastVetoVote(_target, _value, _calldata, _account, _weight);

    assertFalse(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }

  function testFuzz_VotingPeriodExtendedWhenVetoVotesAtThreshold(
    uint256 _timestamp,
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account
  ) public {
    uint256 _proposalId = _createProposalAndCastVetoVote(
      _target, _value, _calldata, _account, _getMinorThreshold(_timestamp)
    );

    assertTrue(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }

  function testFuzz_VotingPeriodExtendedWhenVetoVotesAboveThreshold(
    uint256 _timestamp,
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account,
    uint256 _weight
  ) public {
    _weight = _assumeVetoVoteAboveMinorThreshold(_timestamp, _weight);

    uint256 _proposalId =
      _createProposalAndCastVetoVote(_target, _value, _calldata, _account, _weight);

    assertTrue(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }

  function test_ExtensionDisabledWhenThresholdIsZero(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account,
    uint256 _weight
  ) public {
    vetoMock.exposed_setMinorVetoExtensionThresholdPct(0);
    uint256 _proposalId =
      _createProposalAndCastVetoVote(_target, _value, _calldata, _account, _weight);

    assertFalse(vetoMock.exposed_VotingPeriodExtensionThresholdTriggered(_proposalId));
  }
}

contract _setVotingPeriodExtension is GovernorVetoExtensionTest {
  function testFuzz_SetVotingPeriodExtension(uint48 _newVotingPeriodExtension) public {
    vetoMock.exposed_SetVotingPeriodExtension(_newVotingPeriodExtension);

    assertEq(vetoMock.votingPeriodExtension(), _newVotingPeriodExtension);
  }

  function testFuzz_EmitsVotingPeriodExtensionSet(uint48 _newVotingPeriodExtension) public {
    vm.expectEmit();
    emit GovernorExtendVetoPeriod.VotingPeriodExtensionSet(
      vetoMock.votingPeriodExtension(), _newVotingPeriodExtension
    );

    vetoMock.exposed_SetVotingPeriodExtension(_newVotingPeriodExtension);
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
    vetoMock.exposed_setMinorVetoExtensionThresholdPct(_newVotingPeriodExtensionThreshold);

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
    vetoMock.exposed_setMinorVetoExtensionThresholdPct(_newVetoPeriodExtensionThresholdPct);
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
    vetoMock.exposed_setMinorVetoExtensionThresholdPct(_newVetoPeriodExtensionThresholdPct);
  }
}

contract _tallyUpdated is GovernorVetoExtensionTest {
  function testFuzz_DeadlineExtendedWhenVetoExtensionTriggered(
    uint256 _timestamp,
    address _target,
    uint256 _value,
    bytes memory _calldata
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _oldDeadline = vetoMock.proposalDeadline(_proposalId);
    _timestamp = _boundToIncreaseExtendedDeadline(_proposalId, _timestamp);
    _warpAndTriggerExtension(_proposalId, _timestamp);

    uint256 _expectedDeadline = _timestamp + vetoMock.votingPeriodExtension();
    assertGt(_expectedDeadline, _oldDeadline);
    assertEq(vetoMock.proposalDeadline(_proposalId), _expectedDeadline);
  }

  function testFuzz_EmitsProposalDeadlineExtended(
    uint256 _timestamp,
    address _target,
    uint256 _value,
    bytes memory _calldata
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    _timestamp = _boundToIncreaseExtendedDeadline(_proposalId, _timestamp);
    uint256 _expectedDeadline = _timestamp + vetoMock.votingPeriodExtension();
    vm.warp(_timestamp);
    vetoMock.forceTriggerVotingPeriodExtensionThreshold();

    vm.expectEmit();
    emit GovernorExtendVetoPeriod.ProposalExtended(_proposalId, uint64(_expectedDeadline));
    vetoMock.exposed_TallyUpdated(_proposalId);
  }

  function testFuzz_DeadlineNotExtendedWhenVetoExtensionAlreadyTriggered(
    uint256 _timestamp,
    address _target,
    uint256 _value,
    bytes memory _calldata
  ) public {
    uint256 _proposalId = _createProposal(_target, _value, _calldata);
    uint256 _oldDeadline = vetoMock.proposalDeadline(_proposalId);
    _timestamp = _boundToIncreaseExtendedDeadline(_proposalId, _timestamp);
    _warpAndTriggerExtension(_proposalId, _timestamp);
    uint256 _expectedDeadline = _timestamp + vetoMock.votingPeriodExtension();
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
