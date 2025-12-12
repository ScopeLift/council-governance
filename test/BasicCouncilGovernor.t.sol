// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

// External Dependencies
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {
  GovernorCountingSimple
} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

// Internal Dependencies
import {CouncilERC20} from "src/CouncilERC20.sol";
import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";

// Test Dependencies
import {Test} from "forge-std/Test.sol";
import {BasicCouncilGovernorHarness} from "test/harnesses/BasicCouncilGovernorHarness.sol";

// Script Dependencies
import {DeploymentConfigurationTest} from "script/DeploymentConfigurationTest.sol";
import {
  DeploymentInputMainnetForkTest
} from "script/deploy-constants/DeploymentInputMainnetForkTest.sol";
import {DeployAndMintCouncilERC20} from "script/DeployAndMintCouncilERC20.s.sol";

contract BasicCouncilGovernorTest is Test {
  struct Proposal {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  CouncilERC20 internal councilToken;
  BasicCouncilGovernorHarness internal councilGovernor;
  address internal mockVetoGovernor = makeAddr("Veto governor");

  DeploymentInputMainnetForkTest public input;

  function setUp() public {
    input = new DeploymentInputMainnetForkTest();

    _deployCouncilTokenAndMint();
    _deployCouncilGovernor();
  }

  function _deployCouncilTokenAndMint() internal {
    DeploymentConfigurationTest.CouncilERC20DeploymentConfiguration memory _config =
      (new DeploymentConfigurationTest())._getCouncilERC20DeploymentConfiguration();

    DeployAndMintCouncilERC20 _script = new DeployAndMintCouncilERC20();
    councilToken = _script.run(input.MAIN_DAO_GOVERNOR(), _config);
    vm.warp(block.timestamp + 1);
  }

  function _deployCouncilGovernor() internal {
    councilGovernor = new BasicCouncilGovernorHarness(councilToken, mockVetoGovernor);
  }

  function _selectCouncilMember(uint256 _proposerIndex) internal view returns (address) {
    return input.COUNCIL_MEMBERS(_proposerIndex % input.COUNCIL_MEMBERS_LENGTH());
  }

  function _pickDistinctMembers(uint256 _seed)
    internal
    view
    returns (address _proposer, address _forVoter, address _againstVoter, address _abstainVoter)
  {
    uint256 _len = input.COUNCIL_MEMBERS_LENGTH();
    uint256 _base = _seed % _len;

    _proposer = input.COUNCIL_MEMBERS(_base);
    _forVoter = input.COUNCIL_MEMBERS((_base + 1) % _len);
    _againstVoter = input.COUNCIL_MEMBERS((_base + 2) % _len);
    _abstainVoter = input.COUNCIL_MEMBERS((_base + 3) % _len);
  }

  function _buildEmptyProposal(string memory _description)
    internal
    pure
    returns (Proposal memory _proposal)
  {
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    bytes[] memory _calldatas = new bytes[](1);
    _proposal = Proposal(_targets, _values, _calldatas, _description);
  }

  function _buildEmptyProposal() internal pure returns (Proposal memory _proposal) {
    _proposal = _buildEmptyProposal("Empty proposal");
  }

  function _submitProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    vm.prank(_proposer);
    _proposalId = councilGovernor.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
  }

  function _submitProposalAndWarpPastVotingDelay(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposal(_proposer, _proposal);
    vm.warp(block.timestamp + councilGovernor.votingDelay() + 1);
  }

  function _passSubmittedProposal(uint256 _proposalId) public {
    uint256 _quorumVotesNeeded =
      councilGovernor.quorum(councilGovernor.proposalSnapshot(_proposalId));
    uint256 _councilMembersLength = input.COUNCIL_MEMBERS_LENGTH();
    uint256 _votesCast;

    for (uint256 _i = 0; _i < _councilMembersLength; _i++) {
      address _councilMember = input.COUNCIL_MEMBERS(_i);
      vm.prank(_councilMember);
      councilGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.For));
      _votesCast += councilToken.balanceOf(_councilMember);
      if (_votesCast >= _quorumVotesNeeded) break;
    }
  }

  function _passSubmittedProposalWithSuperQuorum(uint256 _proposalId) public {
    uint256 _quorumVotesNeeded =
      councilGovernor.superQuorum(councilGovernor.proposalSnapshot(_proposalId));
    uint256 _councilMembersLength = input.COUNCIL_MEMBERS_LENGTH();
    uint256 _votesCast;
    for (uint256 _i = 0; _i < _councilMembersLength; _i++) {
      address _councilMember = input.COUNCIL_MEMBERS(_i);
      vm.prank(_councilMember);
      councilGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.For));
      _votesCast += councilToken.balanceOf(_councilMember);
      if (_votesCast >= _quorumVotesNeeded) break;
    }
  }

  function _failProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);

    vm.prank(_proposer);
    councilGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.Against));
    vm.warp(block.timestamp + councilGovernor.votingPeriod() + 1);
  }

  function _passProposal(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);
    _passSubmittedProposal(_proposalId);
    vm.warp(block.timestamp + councilGovernor.votingPeriod() + 1);
  }

  function _assertProposalState(uint256 _proposalId, IGovernor.ProposalState _expected)
    internal
    view
  {
    assertEq(uint8(councilGovernor.state(_proposalId)), uint8(_expected));
  }
}

contract Constructor is Test {
  function test_ConstructorSetsParamsCorrectly(
    string memory _name,
    IERC5805 _token,
    IGovernor _councilVetoGovernor,
    address _owner,
    uint48 _votingDelay,
    uint32 _votingPeriod,
    uint256 _proposalThreshold,
    uint256 _quorumFraction,
    uint256 _superQuorumFraction
  ) public {
    vm.assume(_owner != address(0));
    vm.assume(_votingPeriod != 0);
    _quorumFraction = bound(_quorumFraction, 0, 100);
    _superQuorumFraction = bound(_superQuorumFraction, _quorumFraction, 100);

    BasicCouncilGovernor.InitialCouncilParams memory _params =
      BasicCouncilGovernor.InitialCouncilParams({
        initialVotingDelay: _votingDelay,
        initialVotingPeriod: _votingPeriod,
        initialProposalThreshold: _proposalThreshold,
        initialQuorumFraction: _quorumFraction,
        initialSuperQuorumFraction: _superQuorumFraction
      });

    BasicCouncilGovernor _councilGovernor =
      new BasicCouncilGovernor(_name, _token, _councilVetoGovernor, _owner, _params);

    assertEq(_councilGovernor.name(), _name);
    assertEq(address(_councilGovernor.token()), address(_token));
    assertEq(address(_councilGovernor.councilVetoGovernor()), address(_councilVetoGovernor));
    assertEq(_councilGovernor.votingDelay(), _votingDelay);
    assertEq(_councilGovernor.votingPeriod(), _votingPeriod);
    assertEq(_councilGovernor.proposalThreshold(), _proposalThreshold);
    assertEq(_councilGovernor.owner(), _owner);
    assertEq(_councilGovernor.quorumNumerator(), _quorumFraction);
    assertEq(_councilGovernor.superQuorumNumerator(), _superQuorumFraction);
  }
}

contract VotingDelay is BasicCouncilGovernorTest {
  function test_ReturnsVotingDelay() public view {
    assertEq(councilGovernor.votingDelay(), input.COUNCIL_GOVERNOR_INITIAL_VOTING_DELAY());
  }
}

contract VotingPeriod is BasicCouncilGovernorTest {
  function test_ReturnsVotingPeriod() public view {
    assertEq(councilGovernor.votingPeriod(), input.COUNCIL_GOVERNOR_INITIAL_VOTING_PERIOD());
  }
}

contract ProposalThreshold is BasicCouncilGovernorTest {
  function test_ReturnsProposalThreshold() public view {
    assertEq(
      councilGovernor.proposalThreshold(), input.COUNCIL_GOVERNOR_INITIAL_PROPOSAL_THRESHOLD()
    );
  }
}

contract Quorum is BasicCouncilGovernorTest {
  function test_ReturnsQuorum() public {
    // Advance time to ensure quorum checkpoint (created at deployment, t=2) is visible
    vm.warp(block.timestamp + 1);
    assertEq(
      councilGovernor.quorum(block.timestamp - 1),
      input.COUNCIL_GOVERNOR_INITIAL_QUORUM_FRACTION() * input.COUNCIL_MEMBERS_LENGTH() / 100
    );
  }
}

contract SuperQuorum is BasicCouncilGovernorTest {
  function test_ReturnsSuperQuorum() public {
    // Advance time to ensure super quorum checkpoint (created at deployment, t=2) is visible
    vm.warp(block.timestamp + 1);

    // 7 members, 100% super quorum -> 7 votes
    assertEq(
      councilGovernor.superQuorum(block.timestamp - 1),
      input.COUNCIL_GOVERNOR_INITIAL_SUPER_QUORUM_FRACTION() * input.COUNCIL_MEMBERS_LENGTH() / 100
    );
  }
}

contract Clock is BasicCouncilGovernorTest {
  function testFuzz_ReturnsCurrentTimestamp(uint256 _timestamp) public {
    vm.warp(_timestamp);
    assertEq(councilGovernor.clock(), uint48(_timestamp));
  }
}

contract CLOCK_MODE is BasicCouncilGovernorTest {
  function test_ReturnsTimestamp() public view {
    assertEq(
      abi.encodePacked(keccak256(bytes(councilGovernor.CLOCK_MODE()))),
      abi.encodePacked(keccak256("mode=timestamp"))
    );
  }
}

contract SetVotingDelay is BasicCouncilGovernorTest {
  function testFuzz_GovernanceSetsVotingDelay(uint48 _newVotingDelay) public {
    vm.prank(councilGovernor.owner());
    councilGovernor.setVotingDelay(_newVotingDelay);

    assertEq(councilGovernor.votingDelay(), _newVotingDelay);
  }

  function testFuzz_EmitVotingDelaySet(uint48 _newVotingDelay) public {
    vm.expectEmit();
    emit GovernorSettings.VotingDelaySet(councilGovernor.votingDelay(), uint48(_newVotingDelay));
    vm.prank(councilGovernor.owner());
    councilGovernor.setVotingDelay(_newVotingDelay);
  }

  function testFuzz_RevertIf_NonAdminSetsVotingDelay(address _caller, uint48 _newVotingDelay)
    public
  {
    vm.assume(_caller != councilGovernor.owner());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    councilGovernor.setVotingDelay(_newVotingDelay);
  }
}

contract SetVotingPeriod is BasicCouncilGovernorTest {
  function testFuzz_GovernanceSetsVotingPeriod(uint32 _newVotingPeriod) public {
    vm.assume(_newVotingPeriod != 0);

    vm.prank(councilGovernor.owner());
    councilGovernor.setVotingPeriod(_newVotingPeriod);

    assertEq(councilGovernor.votingPeriod(), _newVotingPeriod);
  }

  function testFuzz_EmitVotingPeriodSet(uint32 _newVotingPeriod) public {
    vm.assume(_newVotingPeriod != 0);

    vm.expectEmit();
    emit GovernorSettings.VotingPeriodSet(councilGovernor.votingPeriod(), uint32(_newVotingPeriod));
    vm.prank(councilGovernor.owner());
    councilGovernor.setVotingPeriod(_newVotingPeriod);
  }

  function testFuzz_RevertIf_NonAdminSetsVotingPeriod(address _caller, uint32 _newVotingPeriod)
    public
  {
    vm.assume(_newVotingPeriod != 0);
    vm.assume(_caller != councilGovernor.owner());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    councilGovernor.setVotingPeriod(_newVotingPeriod);
  }
}

contract SetProposalThreshold is BasicCouncilGovernorTest {
  function testFuzz_GovernanceSetsVotingPeriod(uint256 _newProposalThreshold) public {
    vm.prank(councilGovernor.owner());
    councilGovernor.setProposalThreshold(_newProposalThreshold);

    assertEq(councilGovernor.proposalThreshold(), _newProposalThreshold);
  }

  function testFuzz_EmitVotingPeriodSet(uint256 _newProposalThreshold) public {
    vm.expectEmit();
    emit GovernorSettings.ProposalThresholdSet(
      councilGovernor.proposalThreshold(), _newProposalThreshold
    );
    vm.prank(councilGovernor.owner());
    councilGovernor.setProposalThreshold(_newProposalThreshold);
  }

  function testFuzz_RevertIf_NonAdminSetsVotingDelay(address _caller, uint256 _newProposalThreshold)
    public
  {
    vm.assume(_caller != councilGovernor.owner());

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    councilGovernor.setProposalThreshold(_newProposalThreshold);
  }
}

contract ProposalNeedsQueuing is BasicCouncilGovernorTest {
  function testFuzz_ProposalNeedsQueuingReturnsTrue(uint256 _proposalId) public view {
    assertTrue(councilGovernor.proposalNeedsQueuing(_proposalId));
  }
}

contract State is BasicCouncilGovernorTest {
  function testFuzz_StatePendingBeforeVotingDelay(uint256 _proposerIndex) public {
    address _proposer = _selectCouncilMember(_proposerIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _submitProposal(_proposer, _proposal);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Pending);
  }

  function testFuzz_StateActiveDuringVotingPeriodWithoutSuperQuorum(uint256 _proposerIndex) public {
    address _proposer = _selectCouncilMember(_proposerIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);
    _passSubmittedProposal(_proposalId);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Active);
  }

  function testFuzz_StateSucceededDuringVotingPeriodWithSuperQuorum(uint256 _proposerIndex) public {
    address _proposer = _selectCouncilMember(_proposerIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);
    _passSubmittedProposalWithSuperQuorum(_proposalId);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function testFuzz_StateDefeatedAfterVotingPeriodWithoutQuorumOrMajority(uint256 _proposerIndex)
    public
  {
    address _proposer = _selectCouncilMember(_proposerIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _failProposal(_proposer, _proposal);
    vm.warp(block.timestamp + councilGovernor.votingPeriod() + 1);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Defeated);
  }

  function testFuzz_StateSucceededAfterVotingPeriodWithQuorumAndMajority(uint256 _proposerIndex)
    public
  {
    address _proposer = _selectCouncilMember(_proposerIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _passProposal(_proposer, _proposal);

    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }

  function testFuzz_StateSucceededAfterVotingPeriodWithSuperQuorum(uint256 _proposerIndex) public {
    address _proposer = _selectCouncilMember(_proposerIndex);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);
    _passSubmittedProposalWithSuperQuorum(_proposalId);

    vm.warp(block.timestamp + councilGovernor.votingPeriod() + 1);
    _assertProposalState(_proposalId, IGovernor.ProposalState.Succeeded);
  }
}

contract ProposalVotes is BasicCouncilGovernorTest {
  function testFuzz_ProposalVotesMatchesCountingSimple(uint256 _seed) public {
    (address _proposer, address _forVoter, address _againstVoter, address _abstainVoter) =
      _pickDistinctMembers(_seed);
    Proposal memory _proposal = _buildEmptyProposal();
    uint256 _proposalId = _submitProposalAndWarpPastVotingDelay(_proposer, _proposal);

    uint256 _expectedFor = councilToken.balanceOf(_forVoter);
    uint256 _expectedAgainst = councilToken.balanceOf(_againstVoter);
    uint256 _expectedAbstain = councilToken.balanceOf(_abstainVoter);

    vm.prank(_forVoter);
    councilGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.For));
    vm.prank(_againstVoter);
    councilGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.Against));
    vm.prank(_abstainVoter);
    councilGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.Abstain));

    (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes) =
      councilGovernor.proposalVotes(_proposalId);

    assertEq(forVotes, _expectedFor);
    assertEq(againstVotes, _expectedAgainst);
    assertEq(abstainVotes, _expectedAbstain);
  }
}

contract Propose is BasicCouncilGovernorTest {
  function test_ProposeStoresProposalDescription(uint256 _proposerIndex, string memory _description)
    public
  {
    Proposal memory _proposal = _buildEmptyProposal(_description);
    address _proposer = _selectCouncilMember(_proposerIndex);
    uint256 _proposalId = _submitProposal(_proposer, _proposal);

    assertEq(councilGovernor.exposed_ProposalDescriptions(_proposalId), _description);
  }
}

contract UpdateCouncilVetoGovernor is BasicCouncilGovernorTest {
  function testFuzz_AdminUpdatesCouncilVetoGovernor(IGovernor _newCouncilVetoGovernor) public {
    vm.prank(councilGovernor.owner());
    councilGovernor.updateCouncilVetoGovernor(_newCouncilVetoGovernor);

    assertEq(address(councilGovernor.councilVetoGovernor()), address(_newCouncilVetoGovernor));
  }

  function testFuzz_RevertIf_NonAdminUpdatesCouncilVetoGovernor(
    address _caller,
    IGovernor _newCouncilVetoGovernor
  ) public {
    vm.assume(_caller != councilGovernor.owner());
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    councilGovernor.updateCouncilVetoGovernor(_newCouncilVetoGovernor);
  }
}

contract _checkGovernance is BasicCouncilGovernorTest {
  function test_CheckGovernanceAllowsOwner() public {
    vm.prank(councilGovernor.owner());
    councilGovernor.exposed_CheckGovernance();
  }

  function testFuzz_RevertIf_CheckGovernanceCalledByNonOwner(address _caller) public {
    vm.assume(_caller != councilGovernor.owner());
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _caller));
    vm.prank(_caller);
    councilGovernor.exposed_CheckGovernance();
  }
}

contract _cancel is BasicCouncilGovernorTest {
  function test_CancelDeletesProposalDescriptions(uint256 _proposerIndex) public {
    Proposal memory _proposal = _buildEmptyProposal();
    address _proposer = _selectCouncilMember(_proposerIndex);
    uint256 _proposalId = _submitProposal(_proposer, _proposal);

    assertEq(councilGovernor.exposed_ProposalDescriptions(_proposalId), "Empty proposal");

    vm.prank(_proposer);
    councilGovernor.cancel(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );

    assertEq(councilGovernor.exposed_ProposalDescriptions(_proposalId), "");
  }
}

contract _executor is BasicCouncilGovernorTest {
  function test_ExecutorReturnsVetoGovernor() public view {
    assertEq(councilGovernor.exposed_Executor(), address(councilGovernor.councilVetoGovernor()));
  }
}
