// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {
  GovernorCountingSimple
} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

import {BasicCouncilGovernor} from "src/BasicCouncilGovernor.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {CompoundCouncilVetoGovernor} from "src/CompoundCouncilVetoGovernor.sol";
import {CouncilERC20} from "src/CouncilERC20.sol";

import {
  DeployLegacyCompoundCouncilGovernanceTestConfig
} from "script/test/DeployLegacyCompoundCouncilGovernanceTestConfig.s.sol";

interface IComp is IERC20 {
  function delegate(address delegatee) external;
  function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
}

/// @notice Integration test using mainnet COMP token on a fork.
/// @dev Requires `MAINNET_RPC_URL` to be set for Foundry's `mainnet` RPC alias.
contract CompoundCouncilVetoGovernorIntegrationTest is Test {
  struct Proposal {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  IComp internal constant COMP = IComp(0xc00e94Cb662C3520282E6f5717214004A7f26888);

  address internal deployer = makeAddr("deployer");
  address internal councilMember = makeAddr("councilMember");
  address internal voter = makeAddr("voter");
  address internal nonCouncil = makeAddr("nonCouncil");

  TimelockController internal timelock;
  CouncilERC20 internal councilToken;
  BasicCouncilGovernor internal councilGovernor;
  CompoundCouncilVetoGovernor internal vetoGovernor;

  function setUp() public {
    string memory rpcUrl = vm.rpcUrl("mainnet");
    uint256 forkBlock = 23_810_240;
    vm.createSelectFork(rpcUrl, forkBlock);

    DeployLegacyCompoundCouncilGovernanceTestConfig _deploy =
      new DeployLegacyCompoundCouncilGovernanceTestConfig();
    _deploy.disableLogging();
    _deploy.run();
    vm.warp(block.timestamp + 1);

    councilToken = _deploy.councilToken();
    timelock = _deploy.timelock();
    councilGovernor = _deploy.councilGovernor();
    vetoGovernor = CompoundCouncilVetoGovernor(payable(address(_deploy.vetoGovernor())));
    deployer = tx.origin;
    councilMember = address(0x2001);
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

  function _queueProposalToVetoGovernor() internal returns (uint256 _proposalId) {
    Proposal memory _proposal = _buildEmptyProposal();

    vm.prank(councilMember);
    _proposalId = councilGovernor.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );

    vm.warp(councilGovernor.proposalSnapshot(_proposalId) + 1);
    for (uint256 i = 0; i < 3; i++) {
      vm.prank(address(uint160(0x2001 + i)));
      councilGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.For));
    }

    vm.warp(councilGovernor.proposalDeadline(_proposalId) + 1);

    vm.prank(councilMember);
    councilGovernor.queue(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }

  function _dealAndDelegateComp(address _voter, uint256 _amount) internal {
    deal(address(COMP), _voter, _amount);
    vm.prank(_voter);
    COMP.delegate(_voter);

    vm.roll(block.number + 1);
  }
}

contract CompoundCouncilVetoGovernorIntegrationSmokeTest is
  CompoundCouncilVetoGovernorIntegrationTest
{
  function test_TimestampProgressionDoesNotChangeState() public {
    _dealAndDelegateComp(voter, 1e18);

    uint256 _proposalId = _queueProposalToVetoGovernor();
    IGovernor.ProposalState _before = vetoGovernor.state(_proposalId);

    vm.warp(block.timestamp + vetoGovernor.votingDelay() + 1);
    IGovernor.ProposalState _after = vetoGovernor.state(_proposalId);

    assertEq(vetoGovernor.clock(), block.number);
    assertNotEq(vetoGovernor.clock(), block.timestamp);
    assertEq(uint8(_before), uint8(IGovernor.ProposalState.Pending));
    assertEq(uint8(_after), uint8(IGovernor.ProposalState.Pending));
  }

  function test_VoterCastVetoVoteWithCOMP() public {
    _dealAndDelegateComp(voter, 1e18);

    uint256 _proposalId = _queueProposalToVetoGovernor();

    uint256 snapshot = vetoGovernor.proposalSnapshot(_proposalId);
    vm.roll(vetoGovernor.proposalSnapshot(_proposalId) + 1);

    vm.expectCall(
      address(COMP), abi.encodeWithSelector(IComp.getPriorVotes.selector, voter, snapshot)
    );
    vm.prank(voter);
    vetoGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.Against));

    assertEq(vetoGovernor.proposalVotes(_proposalId), uint256(COMP.getPriorVotes(voter, snapshot)));
  }

  function testFuzz_StateIsSucceededWhenVetoVotesBelowVetoThreshold(uint256 _weight) public {
    _weight = bound(_weight, 0, vetoGovernor.vetoThreshold(0));
    _dealAndDelegateComp(voter, _weight);

    uint256 _proposalId = _queueProposalToVetoGovernor();

    uint256 snapshot = vetoGovernor.proposalSnapshot(_proposalId);
    vm.roll(snapshot + 1);
    vm.prank(voter);
    vetoGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.Against));

    vm.roll(vetoGovernor.proposalDeadline(_proposalId) + 1);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Succeeded));
  }

  function testFuzz_StateIsDefeatedWhenVetoVotesAboveVetoThreshold(uint256 _weight) public {
    uint256 _proposalId = _queueProposalToVetoGovernor();

    _weight = bound(
      _weight,
      vetoGovernor.vetoThreshold(vetoGovernor.proposalSnapshot(_proposalId)),
      COMP.totalSupply() - 1
    );
    _dealAndDelegateComp(voter, _weight);

    uint256 snapshot = vetoGovernor.proposalSnapshot(_proposalId);
    vm.roll(snapshot + 1);
    vm.prank(voter);
    vetoGovernor.castVote(_proposalId, uint8(GovernorCountingSimple.VoteType.Against));

    vm.roll(vetoGovernor.proposalDeadline(_proposalId) + 1);
    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Defeated));
  }
}
