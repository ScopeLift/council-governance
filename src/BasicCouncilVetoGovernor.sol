// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

// External Dependencies
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVetoCountingSimple} from "src/extensions/GovernorVetoCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {
  GovernorTimelockControl,
  TimelockController
} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

// Internal Dependencies
import {GovernorVetoOverride} from "src/extensions/GovernorVetoOverride.sol";
import {GovernorVetoGuardian} from "src/extensions/GovernorVetoGuardian.sol";
import {GovernorAdmin} from "src/extensions/GovernorAdmin.sol";
import {
  GovernorVotesVetoThresholdFraction
} from "src/extensions/GovernorVotesVetoThresholdFraction.sol";
import {GovernorExtendVetoPeriod} from "src/extensions/GovernorExtendVetoPeriod.sol";

contract BasicCouncilVetoGovernor is
  Governor,
  GovernorVotes,
  GovernorVetoCountingSimple,
  GovernorVetoGuardian,
  GovernorVetoOverride,
  GovernorVotesVetoThresholdFraction,
  GovernorExtendVetoPeriod,
  GovernorAdmin,
  GovernorSettings,
  GovernorTimelockControl
{
  /// @notice Data structure for deploying the `CouncilVetoGovernor`.
  /// @param name The name of the council veto governor.
  /// @param token The token used to veto governance proposals.
  /// @param votingDelay The delay before voting on a proposal begins.
  /// @param votingPeriod The period of time voting will take place.
  /// @param proposalThreshold The number of tokens needed to create a proposal.
  /// @param vetoGuardian The address authorized to veto proposals.
  /// @param vetoOverrideRole The address authorized to override vetoed proposals.
  /// @param vetoOverrideDuration Time window for overrides after proposal deadline.
  /// @param timelock The timelock contract used for managing proposals.
  /// @param governorAdmin The address authorized to change governance parameters.
  /// @param council The address of the council governor.
  struct ConstructorParams {
    string name;
    IERC5805 token;
    uint48 votingDelay;
    uint32 votingPeriod;
    uint256 proposalThreshold;
    address vetoGuardian;
    address vetoOverrideRole;
    uint48 vetoOverrideDuration;
    uint48 votingPeriodExtension;
    uint16 votingPeriodExtensionThresholdPct;
    uint256 vetoThresholdNumerator;
    TimelockController timelock;
    address governorAdmin;
    address council;
  }

  address public immutable COUNCIL;

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
    GovernorVotesVetoThresholdFraction(_params.vetoThresholdNumerator)
    GovernorExtendVetoPeriod(
      _params.votingPeriodExtension, _params.votingPeriodExtensionThresholdPct
    )
    GovernorTimelockControl(_params.timelock)
    GovernorAdmin(_params.governorAdmin)
  {
    COUNCIL = _params.council;
  }

  function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
    return GovernorSettings.votingDelay();
  }

  function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
    return GovernorSettings.votingPeriod();
  }

  function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
    return GovernorSettings.proposalThreshold();
  }

  /// @notice Returns the proposal state after applying the guardian and override extensions.
  /// @dev The override order is deliberate:
  /// 1. {GovernorVetoGuardian} marks guardian-vetoed proposals as `Defeated`.
  /// 2. {GovernorVetoOverride} can promote vetoed proposals back to `Succeeded`
  /// if the override role intervenes.
  /// @param _proposalId Proposal identifier to evaluate.
  /// @return proposalState The current state after guardian and override logic.
  function state(uint256 _proposalId)
    public
    view
    override(Governor, GovernorTimelockControl, GovernorVetoGuardian, GovernorVetoOverride)
    returns (ProposalState)
  {
    return GovernorVetoOverride.state(_proposalId);
  }

  function proposalDeadline(uint256 _proposalId)
    public
    view
    override(Governor, GovernorExtendVetoPeriod)
    returns (uint256)
  {
    return GovernorExtendVetoPeriod.proposalDeadline(_proposalId);
  }

  function proposalVotes(uint256 _proposalId)
    public
    view
    override(GovernorExtendVetoPeriod, GovernorVetoCountingSimple)
    returns (uint256)
  {
    // GovernorExtendVetoPeriod doesn't implement `proposalVotes`
    return GovernorVetoCountingSimple.proposalVotes(_proposalId);
  }

  function _tallyUpdated(uint256 _proposalId)
    internal
    override(Governor, GovernorExtendVetoPeriod)
  {
    GovernorExtendVetoPeriod._tallyUpdated(_proposalId);
  }

  function proposalNeedsQueuing(uint256 _proposalId)
    public
    view
    virtual
    override(Governor, GovernorTimelockControl)
    returns (bool)
  {
    return GovernorTimelockControl.proposalNeedsQueuing(_proposalId);
  }

  function clock() public view override(Governor, GovernorVotes) returns (uint48) {
    return uint48(block.timestamp);
  }

  function CLOCK_MODE() public pure override(Governor, GovernorVotes) returns (string memory) {
    return "mode=timestamp";
  }

  function propose(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) public override onlyCouncil returns (uint256) {
    return super.propose(_targets, _values, _calldatas, _description);
  }

  function execute(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) public payable override onlyCouncil returns (uint256) {
    return super.execute(_targets, _values, _calldatas, _descriptionHash);
  }

  function _checkGovernance() internal virtual override(Governor, GovernorAdmin) {
    GovernorAdmin._checkGovernance();
  }

  function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
    return GovernorTimelockControl._executor();
  }

  /// @inheritdoc GovernorTimelockControl
  /// @dev We override this function to resolve ambiguity between inherited contracts.
  /// @notice This internal function maintains the inheritance chain but should not be called
  /// because the public cancel function is disabled.
  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
    return GovernorTimelockControl._cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  function _queueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
    return GovernorTimelockControl._queueOperations(
      _proposalId, _targets, _values, _calldatas, _descriptionHash
    );
  }

  function _executeOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) {
    GovernorTimelockControl._executeOperations(
      _proposalId, _targets, _values, _calldatas, _descriptionHash
    );
  }

  function vetoThreshold(uint256 timepoint)
    public
    view
    virtual
    override(
      GovernorVetoCountingSimple,
      GovernorExtendVetoPeriod,
      GovernorVotesVetoThresholdFraction
    )
    returns (uint256)
  {
    // Neither GovernorVetoCountingSimple nor GovernorExtendVetoPeriod implement `vetoThreshold`
    return GovernorVotesVetoThresholdFraction.vetoThreshold(timepoint);
  }
}
