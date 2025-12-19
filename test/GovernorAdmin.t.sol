// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// External Dependencies
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Test Dependencies
import {BasicCouncilGovernorTest} from "test/BasicCouncilGovernor.integration.t.sol";

contract GovernorAdminTest is BasicCouncilGovernorTest {
  function _proposeForwardAndQueueToVetoGovernor(string memory _description)
    internal
    returns (uint256 _proposalId, bytes32 _descriptionHash)
  {
    _descriptionHash = keccak256(bytes(_description));

    vm.prank(councilMembers[0]);
    uint256 _councilProposalId = councilGovernor.propose(targets, values, calldatas, _description);

    skip(councilGovernor.votingDelay() + 1);
    for (
      uint256 _i = 0;
      _i < councilGovernor.quorum(councilGovernor.proposalSnapshot(_councilProposalId));
      _i++
    ) {
      vm.prank(councilMembers[_i]);
      councilGovernor.castVote(_councilProposalId, 1);
    }
    skip(councilGovernor.votingPeriod() + 1);

    _proposalId = councilGovernor.queue(targets, values, calldatas, _descriptionHash);

    vm.roll(block.number + vetoGovernor.proposalDeadline(_proposalId) + 1);
    vetoGovernor.queue(targets, values, calldatas, _descriptionHash);
  }
}

contract VotingDelay is GovernorAdminTest {
  function test_MainDaoSetsCouncilGovernorVotingDelay(uint48 _newVotingDelay) public {
    vm.prank(deployer);
    councilGovernor.setVotingDelay(_newVotingDelay);

    assertEq(councilGovernor.votingDelay(), _newVotingDelay);
  }

  function test_RevertIf_CouncilSetsVotingDelay(uint48 _newVotingDelay) public {
    targets[0] = address(councilGovernor);
    calldatas[0] = abi.encodeCall(councilGovernor.setVotingDelay, _newVotingDelay);

    (uint256 _proposalId, bytes32 _descriptionHash) =
      _proposeForwardAndQueueToVetoGovernor("Set voting delay");

    assertEq(uint8(vetoGovernor.state(_proposalId)), uint8(IGovernor.ProposalState.Queued));
    skip(timelock.getMinDelay() + 1);

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(timelock))
    );
    councilGovernor.execute(targets, values, calldatas, _descriptionHash);
  }
}
