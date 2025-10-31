// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVetoCountingSimple} from "./extensions/GovernorVetoCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {GovernorVetoOverride} from "./extensions/GovernorVetoOverride.sol";
import {GovernorVetoGuardian} from "./extensions/GovernorVetoGuardian.sol";
import {
  GovernorTimelockControl,
  TimelockController
} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

contract BasicCouncilVetoGovernor is
  Governor,
  GovernorVotes,
  GovernorVetoCountingSimple,
  GovernorVetoGuardian,
  GovernorVetoOverride,
  GovernorTimelockControl
{
  address public immutable COUNCIL;

  modifier onlyCouncil() {
    require(msg.sender == COUNCIL, "Only council");
    _;
  }

  constructor(
    IERC5805 _token,
    address _council,
    address _vetoGuardian,
    address _vetoOverrideRole,
    uint48 _vetoOverrideDuration,
    TimelockController _timelock
  )
    Governor("BasicVetoGovernor")
    GovernorVotes(_token)
    GovernorVetoGuardian(_vetoGuardian)
    GovernorVetoOverride(_vetoOverrideRole, _vetoOverrideDuration)
    GovernorTimelockControl(_timelock)
  {
    COUNCIL = _council;
  }

  function votingDelay() public pure override returns (uint256) {
    return 1 hours;
  }

  function votingPeriod() public pure override returns (uint256) {
    return 1 days;
  }

  function proposalThreshold() public pure override returns (uint256) {
    return 0;
  }

  function quorum(uint256 /*timepoint*/ ) public pure override returns (uint256) {
    return 10_000e18;
  }

  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override onlyCouncil returns (uint256) {
    return super.propose(targets, values, calldatas, description);
  }

  function execute(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public payable override onlyCouncil returns (uint256) {
    return super.execute(targets, values, calldatas, descriptionHash);
  }

  function _executeOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) {
    super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
    return super._executor();
  }

  function cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public override onlyCouncil returns (uint256) {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  function state(uint256 proposalId)
    public
    view
    override(Governor, GovernorTimelockControl, GovernorVetoGuardian, GovernorVetoOverride)
    returns (ProposalState)
  {
    return super.state(proposalId);
  }

  function _queueOperations(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
    return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
  }

  function proposalNeedsQueuing(uint256 proposalId)
    public
    view
    virtual
    override(Governor, GovernorTimelockControl)
    returns (bool)
  {
    return GovernorTimelockControl.proposalNeedsQueuing(proposalId);
  }

  function clock() public view override(Governor, GovernorVotes) returns (uint48) {
    return uint48(block.timestamp);
  }

  function CLOCK_MODE() public pure override(Governor, GovernorVotes) returns (string memory) {
    return "mode=timestamp";
  }
}
