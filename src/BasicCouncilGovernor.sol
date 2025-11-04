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
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {GovernorAdmin} from "./extensions/GovernorAdmin.sol";

contract BasicCouncilGovernor is
  Governor,
  GovernorVotes,
  GovernorCountingSimple,
  GovernorCouncilQueuing,
  GovernorSuperQuorum,
  GovernorSettings,
  GovernorAdmin
{
  constructor(
    IERC5805 _token,
    IGovernor _councilVetoGovernor,
    address _governorAdmin,
    uint48 initialVotingDelay,
    uint32 initialVotingPeriod,
    uint256 initialProposalThreshold
  )
    Governor("BasicCouncilGovernor")
    GovernorVotes(_token)
    GovernorCouncilQueuing(_councilVetoGovernor)
    GovernorSettings(initialVotingDelay, initialVotingPeriod, initialProposalThreshold)
    GovernorAdmin(_governorAdmin)
  {}

  function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
    return super.votingDelay();
  }

  function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
    return super.votingPeriod();
  }

  function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
    return super.proposalThreshold();
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


  function _checkGovernance() internal virtual override(Governor, GovernorAdmin) {
    GovernorAdmin._checkGovernance();
  }

  function setVotingDelay(uint48 newVotingDelay) public virtual override onlyGovernance {
    _setVotingDelay(newVotingDelay);
  }

  function setVotingPeriod(uint32 newVotingPeriod) public virtual override onlyGovernance {
    _setVotingPeriod(newVotingPeriod);
  }

  function setProposalThreshold(uint256 newProposalThreshold)
    public
    virtual
    override
    onlyGovernance
  {
    _setProposalThreshold(newProposalThreshold);
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
