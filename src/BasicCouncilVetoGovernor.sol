// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External Dependencies
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVetoCountingSimple} from "src/extensions/GovernorVetoCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

// Internal Dependencies
import {GovernorVetoOverride} from "src/extensions/GovernorVetoOverride.sol";
import {GovernorVetoGuardian} from "src/extensions/GovernorVetoGuardian.sol";
import {GovernorAdmin} from "src/extensions/GovernorAdmin.sol";
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
    TimelockController timelock;
    address governorAdmin;
    address council;
  }

  address public immutable COUNCIL;

  /// @notice Thrown when an operation is not supported
  error BasicCouncilVetoGovernor_OperationNotSupported();

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

  function state(uint256 _proposalId)
    public
    view
    override(Governor, GovernorTimelockControl, GovernorVetoGuardian, GovernorVetoOverride)
    returns (ProposalState)
  {
    return super.state(_proposalId);
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

  /// @notice Cancel is disabled.
  /// @notice By design, a proposal queued to the veto governor cannot be canceled. Proposal can
  /// only be rejected through veto votes, or through the veto guardian.
  /// @dev This function always reverts to prevent confusion between cancellation and veto
  /// operations, which serve different purposes in the governance flow.
  function cancel(
    address[] memory, /* targets */
    uint256[] memory, /* values */
    bytes[] memory, /* calldadtas */
    bytes32 /* descriptionHash */
  ) public pure override returns (uint256) {
    revert BasicCouncilVetoGovernor_OperationNotSupported();
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
    return super._executor();
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
    return super._cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  function _queueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
    return super._queueOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }

  function _executeOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorTimelockControl) {
    super._executeOperations(_proposalId, _targets, _values, _calldatas, _descriptionHash);
  }
}
