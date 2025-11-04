// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BasicCouncilGovernorTest} from "./BasicCouncilGovernor.t.sol";
// import {GovernorAdmin} from "../src/extensions/GovernorAdmin.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Ownable} from "@openzeppelin/contracts/Access/Ownable.sol";

contract GovernorAdminTest is BasicCouncilGovernorTest {
  function _proposeForwardAndQueueToVetoGovernor(string memory _description)
    internal
    returns (uint256 proposalId, bytes32 _descriptionHash)
  {
    _descriptionHash = keccak256(bytes(_description));

    vm.prank(councilMembers[0]);
    uint256 councilProposalId = councilGovernor.propose(targets, values, calldatas, _description);

    skip(councilGovernor.votingDelay() + 1);
    for (uint256 i = 0; i < councilGovernor.quorum(0); i++) {
      vm.prank(councilMembers[i]);
      councilGovernor.castVote(councilProposalId, 1);
    }
    skip(councilGovernor.votingPeriod() + 1);

    proposalId = councilGovernor.queue(targets, values, calldatas, _descriptionHash);

    skip(vetoGovernor.proposalDeadline(proposalId) + 1);
    vetoGovernor.queue(targets, values, calldatas, _descriptionHash);
  }
}

contract VotingDelay is GovernorAdminTest {
  function test_MainDaoSetsCouncilGovernorVotingDelay(uint48 newVotingDelay) public {
    vm.prank(deployer);
    councilGovernor.setVotingDelay(newVotingDelay);

    assertEq(councilGovernor.votingDelay(), newVotingDelay);
  }

  function test_RevertIf_CouncilSetsVotingDelay(uint48 newVotingDelay) public {
    targets[0] = address(councilGovernor);
    calldatas[0] = abi.encodeCall(councilGovernor.setVotingDelay, newVotingDelay);

    (uint256 proposalId, bytes32 _descriptionHash) =
      _proposeForwardAndQueueToVetoGovernor("Set voting delay");

    assertEq(uint8(vetoGovernor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));
    skip(timelock.getMinDelay() + 1);

    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(timelock))
    );
    councilGovernor.execute(targets, values, calldatas, _descriptionHash);
  }
}
