// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVetoCountingSimple} from "./extensions/GovernorVetoCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {GovernorVetoOverride} from "./extensions/GovernorVetoOverride.sol";
import {GovernorVetoGuardian} from "./extensions/GovernorVetoGuardian.sol";
import {GovernorAdmin} from "./extensions/GovernorAdmin.sol";
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
  GovernorAdmin,
  GovernorSettings,
  GovernorTimelockControl
{
  address public immutable COUNCIL;

  /**
   * @notice Data structure for deploying the `CouncilVetoGovernor`.
   * @param name The name of the council veto governor.
   * @param token The token used to veto governance proposals.
   * @param votingDelay The delay before voting on a proposal begins.
   * @param votingPeriod The period of time voting will take place.
   * @param proposalThreshold The number of tokens needed to create a proposal.
   * @param vetoGuardian The address authorized to veto proposals.
   * @param vetoOverrideRole The address authorized to override vetoed proposals.
   * @param vetoOverrideDuration Time window for overrides after proposal deadline.
   * @param timelock The timelock contract used for managing proposals.
   * @param governorAdmin The address authorized to change governance parameters.
   * @param council The address of the council governor.
   */
  struct ConstructorParams {
    string name;
    IERC5805 token;
    uint48 votingDelay;
    uint32 votingPeriod;
    uint256 proposalThreshold;
    address vetoGuardian;
    address vetoOverrideRole;
    uint48 vetoOverrideDuration;
    TimelockController timelock;
    address governorAdmin;
    address council;
  }

  modifier onlyCouncil() {
    require(msg.sender == COUNCIL, "Only council");
    _;
  }

  constructor(ConstructorParams memory _params)
    Governor(_params.name)
    GovernorVotes(_params.token)
    GovernorVetoGuardian(_params.vetoGuardian)
    GovernorSettings(_params.votingDelay, _params.votingPeriod, _params.proposalThreshold)
    GovernorVetoOverride(_params.vetoOverrideRole, _params.vetoOverrideDuration)
    GovernorTimelockControl(_params.timelock)
    GovernorAdmin(_params.governorAdmin)
  {
    COUNCIL = _params.council;
  }

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
    return 10_000e18;
  }

  function _checkGovernance() internal virtual override(Governor, GovernorAdmin) {
    GovernorAdmin._checkGovernance();
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

  /// @inheritdoc GovernorTimelockControl
  function _cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
    return super._cancel(targets, values, calldatas, descriptionHash);
  }

  /// @notice Returns the proposal state after applying the guardian and override extensions.
  /// @dev The override order is deliberate:
  /// 1. {GovernorVetoGuardian} marks guardian-vetoed proposals as `Defeated`.
  /// 2. {GovernorVetoOverride} can promote vetoed proposals back to `Succeeded`
  /// if the override role intervenes.
  /// @param proposalId Proposal identifier to evaluate.
  /// @return proposalState The current state after guardian and override logic.
  function state(uint256 proposalId)
    public
    view
    override(Governor, GovernorTimelockControl, GovernorVetoGuardian, GovernorVetoOverride)
    returns (ProposalState)
  {
    return GovernorVetoOverride.state(proposalId);
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
