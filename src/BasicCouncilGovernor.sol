// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import {Governor, IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {GovernorCouncilQueuing} from "./extensions/GovernorCouncilQueuing.sol";
import {GovernorSuperQuorum} from
  "@openzeppelin/contracts/governance/extensions/GovernorSuperQuorum.sol";

contract BasicCouncilGovernor is
  Governor,
  GovernorVotes,
  GovernorCountingSimple,
  GovernorCouncilQueuing,
  GovernorSuperQuorum
{
  constructor(IERC5805 _token, IGovernor _councilVetoGovernor)
    Governor("BasicCouncilGovernor")
    GovernorVotes(_token)
    GovernorCouncilQueuing(_councilVetoGovernor)
  {}

  function votingDelay() public pure override returns (uint256) {
    return 1 days;
  }

  function votingPeriod() public pure override returns (uint256) {
    return 1 weeks;
  }

  function proposalThreshold() public pure override returns (uint256) {
    return 1;
  }

  function quorum(uint256 /*timepoint*/ ) public pure override returns (uint256) {
    return 4;
  }

  function superQuorum(uint256 /*timepoint*/ ) public view virtual override returns (uint256) {
    return 7;
  }

  function clock() public view override(Governor, GovernorVotes) returns (uint48) {
    return uint48(block.timestamp);
  }

  /// forge-lint: disable-next-line(mixed-case-function)
  function CLOCK_MODE() public pure override(Governor, GovernorVotes) returns (string memory) {
    return "mode=timestamp";
  }

  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorCouncilQueuing) returns (uint256) {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  function _executeOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorCouncilQueuing) {
    super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function _executor() internal view override(Governor, GovernorCouncilQueuing) returns (address) {
    return address(councilVetoGovernor);
  }

  function proposalNeedsQueuing(uint256 proposalId)
    public
    view
    override(Governor, GovernorCouncilQueuing)
    returns (bool)
  {
    return GovernorCouncilQueuing.proposalNeedsQueuing(proposalId);
  }

  function _queueOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorCouncilQueuing) returns (uint48) {
    return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override(Governor, GovernorCouncilQueuing) returns (uint256) {
    return super.propose(targets, values, calldatas, description);
  }

  function state(uint256 proposalId)
    public
    view
    override(Governor, GovernorCouncilQueuing, GovernorSuperQuorum)
    returns (ProposalState)
  {
    return GovernorSuperQuorum.state(proposalId);
  }

  function proposalVotes(uint256 proposalId)
    public
    view
    override(GovernorSuperQuorum, GovernorCountingSimple)
    returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
  {
    // GovernorSuperQuorum.proposalVotes is unimplemented.
    return GovernorCountingSimple.proposalVotes(proposalId);
  }
}
