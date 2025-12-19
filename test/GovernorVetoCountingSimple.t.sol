// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {Test} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

// Internal Dependencies
import {GovernorVetoCountingSimpleMock} from "test/mocks/GovernorVetoCountingSimpleMock.sol";

contract GovernorVetoCountingSimple_Test is Test {
  GovernorVetoCountingSimpleMock public governorVetoCountingSimple;
  uint256 public vetoThreshold;

  function setUp() public {
    governorVetoCountingSimple = new GovernorVetoCountingSimpleMock();
    vetoThreshold = governorVetoCountingSimple.vetoThreshold(0);
  }

  modifier castVetoVoteOnProposal(uint256 _proposalId, address _account, uint256 _weight) {
    castVoteOnProposal(_proposalId, _account, _weight);
    _;
  }

  function createProposal(address _target, uint256 _value, bytes memory _calldata)
    internal
    returns (uint256 _proposalId)
  {
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    bytes[] memory _calldatas = new bytes[](1);
    _targets[0] = _target;
    _values[0] = _value;
    _calldatas[0] = _calldata;

    _proposalId = governorVetoCountingSimple.propose(_targets, _values, _calldatas, "");
  }

  function castVoteOnProposal(uint256 _proposalId, address _account, uint256 _weight) public {
    vm.assume(_account != address(0));
    // GovernorVetoCountingSimple only accepts support = 0 (veto votes)
    governorVetoCountingSimple.exposed_countVote(_proposalId, _account, 0, _weight, "");
  }

  function createProposalAndCastVetoVote(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _account,
    uint256 _weight
  ) internal returns (uint256 _proposalId) {
    _proposalId = createProposal(_target, _value, _calldata);
    castVoteOnProposal(_proposalId, _account, _weight);
  }
}

contract COUNTING_MODE is GovernorVetoCountingSimple_Test {
  function test_COUNTING_MODE() public view {
    assertEq(governorVetoCountingSimple.COUNTING_MODE(), "support=veto&quorum=veto");
  }
}

contract HasVoted is GovernorVetoCountingSimple_Test {
  function testFuzz_HasVotedReturnsFalseIfProposalIdDoesNotExist(
    uint256 _proposalId,
    address _account
  ) public view {
    assertEq(governorVetoCountingSimple.hasVoted(_proposalId, _account), false);
  }

  function testFuzz_HasVotedReturnsFalseIAccountHasNotVoted(
    uint256 _proposalId,
    address _account,
    uint256 _weight
  ) public castVetoVoteOnProposal(_proposalId, msg.sender, _weight) {
    vm.assume(_account != msg.sender);
    assertEq(governorVetoCountingSimple.hasVoted(_proposalId, _account), false);
  }

  function testFuzz_HasVotedReturnsTrueIfAccountHasVoted(
    uint256 _proposalId,
    address _account,
    uint256 _weight
  ) public castVetoVoteOnProposal(_proposalId, _account, _weight) {
    assertEq(governorVetoCountingSimple.hasVoted(_proposalId, _account), true);
  }
}

contract ProposalVotes is GovernorVetoCountingSimple_Test {
  function testFuzz_ProposalVotesReturnsVetoVotes(uint256 _proposalId, uint256 _weight)
    public
    castVetoVoteOnProposal(_proposalId, msg.sender, _weight)
  {
    assertEq(governorVetoCountingSimple.proposalVotes(_proposalId), _weight);
  }

  function testFuzz_ProposalVotesReturns0IfNoVotesHaveBeenCast(uint256 _proposalId) public view {
    assertEq(governorVetoCountingSimple.proposalVotes(_proposalId), 0);
  }

  function testFuzz_ProposalVotesAccumulatesManyVotes(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint256 _numVoters,
    uint256[] memory _weights
  ) public {
    // Bound number of voters to a reasonable range
    _numVoters = bound(_numVoters, 2, 10);

    // Resize weights array to match _numVoters if needed
    if (_weights.length != _numVoters) {
      uint256[] memory _newWeights = new uint256[](_numVoters);
      for (uint256 _i = 0; _i < _numVoters && _i < _weights.length; _i++) {
        _newWeights[_i] = _weights[_i];
      }
      _weights = _newWeights;
    }

    uint256 _proposalId = createProposal(_target, _value, _calldata);
    uint256 _totalVotes;

    // Generate unique voters and bound weights to prevent overflow
    for (uint256 _i = 0; _i < _numVoters; _i++) {
      address _voter = makeAddr(string(abi.encodePacked("voter", _i)));

      // Bound each weight to prevent overflow when summing
      _weights[_i] = bound(_weights[_i], 0, type(uint256).max / _numVoters);

      // Cast vote and verify accumulation
      castVoteOnProposal(_proposalId, _voter, _weights[_i]);
      _totalVotes += _weights[_i];
      assertEq(governorVetoCountingSimple.proposalVotes(_proposalId), _totalVotes);
    }
  }
}

contract QuorumReached is GovernorVetoCountingSimple_Test {
  function testFuzz_QuorumReachedReturnsTrue(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint256 _weight,
    address _voter
  ) public {
    uint256 _proposalId = createProposalAndCastVetoVote(_target, _value, _calldata, _voter, _weight);
    assertEq(governorVetoCountingSimple.exposed_quorumReached(_proposalId), true);
  }
}

contract VoteSucceeded is GovernorVetoCountingSimple_Test {
  function testFuzz_VoteSucceededReturnsTrueWhenVetoVotesBelowThreshold(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint256 _weight,
    address _voter
  ) public {
    _weight = bound(_weight, 0, vetoThreshold - 1);
    uint256 _proposalId = createProposalAndCastVetoVote(_target, _value, _calldata, _voter, _weight);
    assertEq(governorVetoCountingSimple.exposed_voteSucceeded(_proposalId), true);
  }

  function testFuzz_VoteSucceededReturnsFalseWhenVetoVotesAtThreshold(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    address _voter
  ) public {
    uint256 _proposalId = createProposalAndCastVetoVote(
      _target, _value, _calldata, _voter, vetoThreshold
    );
    assertEq(governorVetoCountingSimple.exposed_voteSucceeded(_proposalId), false);
  }

  function testFuzz_VoteSucceededReturnsFalseWhenVetoVotesAboveThreshold(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint256 _weight,
    address _voter
  ) public {
    _weight = bound(_weight, vetoThreshold + 1, type(uint256).max);
    uint256 _proposalId = createProposalAndCastVetoVote(_target, _value, _calldata, _voter, _weight);
    assertEq(governorVetoCountingSimple.exposed_voteSucceeded(_proposalId), false);
  }

  function testFuzz_VoteSucceededIsInverseOfIsVetoed(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint256 _weight,
    address _voter
  ) public {
    uint256 _proposalId = createProposalAndCastVetoVote(_target, _value, _calldata, _voter, _weight);

    assertEq(
      governorVetoCountingSimple.exposed_voteSucceeded(_proposalId),
      !governorVetoCountingSimple.exposed_isVetoed(_proposalId)
    );
  }
}

contract State is GovernorVetoCountingSimple_Test {
  function testFuzz_StateIsSucceededWhenVetoNotReached(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint256 _weight,
    address _voter
  ) public {
    _weight = bound(_weight, 0, vetoThreshold - 1);
    uint256 _proposalId = createProposalAndCastVetoVote(_target, _value, _calldata, _voter, _weight);

    // Fast forward past voting period to check final state
    vm.roll(
      block.number + governorVetoCountingSimple.votingDelay()
        + governorVetoCountingSimple.votingPeriod() + 1
    );

    assertEq(
      uint8(governorVetoCountingSimple.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded)
    );
  }

  function testFuzz_StateIsDefeatedWhenVetoReached(
    address _target,
    uint256 _value,
    bytes memory _calldata,
    uint256 _weight,
    address _voter
  ) public {
    _weight = bound(_weight, vetoThreshold, type(uint256).max);
    uint256 _proposalId = createProposalAndCastVetoVote(_target, _value, _calldata, _voter, _weight);

    // Fast forward past voting period to check final state
    vm.roll(
      block.number + governorVetoCountingSimple.votingDelay()
        + governorVetoCountingSimple.votingPeriod() + 1
    );

    assertEq(
      uint8(governorVetoCountingSimple.state(_proposalId)), uint8(IGovernor.ProposalState.Defeated)
    );
  }
}

contract CountVote is GovernorVetoCountingSimple_Test {
  function testFuzz_UpdatesVoteWeightOnVoting(
    uint256 _proposalId,
    address _account,
    uint256 _weight
  ) public {
    // Check to ensure vetoVotes is initally 0
    assertEq(governorVetoCountingSimple.proposalVotes(_proposalId), 0);

    castVoteOnProposal(_proposalId, _account, _weight);

    assertEq(governorVetoCountingSimple.proposalVotes(_proposalId), _weight);
  }

  function testFuzz_UpdatesHasVotedFlagOnVoting(
    uint256 _proposalId,
    address _account,
    uint256 _weight
  ) public {
    assertEq(governorVetoCountingSimple.hasVoted(_proposalId, _account), false);

    castVoteOnProposal(_proposalId, _account, _weight);

    assertEq(governorVetoCountingSimple.hasVoted(_proposalId, _account), true);
  }

  function testFuzz_RevertIf_AccountHasAlreadyVoted(
    uint256 _proposalId,
    address _account,
    uint256 _weight
  ) public castVetoVoteOnProposal(_proposalId, _account, _weight) {
    vm.expectRevert(abi.encodeWithSelector(IGovernor.GovernorAlreadyCastVote.selector, _account));
    governorVetoCountingSimple.exposed_countVote(_proposalId, _account, 0, _weight, "");
  }

  function testFuzz_RevertIf_AccountPassesInvalidSupport(
    uint256 _proposalId,
    address _account,
    uint256 _weight,
    uint8 _support
  ) public {
    vm.assume(_account != address(0));
    vm.assume(_support != 0);

    vm.expectRevert(IGovernor.GovernorInvalidVoteType.selector);
    governorVetoCountingSimple.exposed_countVote(_proposalId, _account, _support, _weight, "");
  }
}
