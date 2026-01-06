// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

// External Dependencies
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
  GovernorTimelockControl,
  TimelockController
} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";

// Internal Dependencies
import {GovernorVetoCountingSimple} from "src/extensions/GovernorVetoCountingSimple.sol";
import {GovernorVetoOverride} from "src/extensions/GovernorVetoOverride.sol";
import {GovernorVetoGuardian} from "src/extensions/GovernorVetoGuardian.sol";
import {GovernorAdmin} from "src/extensions/GovernorAdmin.sol";
import {GovernorExtendVetoPeriod} from "src/extensions/GovernorExtendVetoPeriod.sol";
import {GovernorVotesComp} from "src/extensions/GovernorVotesComp.sol";

/// @title CompoundCouncilVetoGovernor
/// @author [ScopeLift](https://scopelift.co)
/// @notice Veto governor variant for COMP-style tokens (legacy `getPriorVotes` snapshots).
/// @dev This governor uses a block-number clock. `votingDelay`, `votingPeriod`, and all timepoints
/// are expressed in blocks (not seconds).
contract CompoundCouncilVetoGovernor is
  Governor,
  GovernorVotesComp,
  GovernorAdmin,
  GovernorSettings,
  GovernorVetoCountingSimple,
  GovernorVetoGuardian,
  GovernorVetoOverride,
  GovernorExtendVetoPeriod,
  GovernorTimelockControl
{
  /// @notice Data structure for deploying the `CouncilVetoGovernor`.
  /// @param name The name of the council veto governor.
  /// @param token The token used to veto governance proposals.
  /// @param votingDelay The delay before voting on a proposal begins (in blocks).
  /// @param votingPeriod The period of time voting will take place (in blocks).
  /// @param proposalThreshold The number of tokens needed to create a proposal.
  /// @param vetoGuardian The address authorized to veto proposals.
  /// @param vetoOverrideRole The address authorized to override vetoed proposals.
  /// @param vetoOverrideDuration Time window for overrides after proposal deadline (in blocks).
  /// @param votingPeriodExtension Voting period extension amount (in blocks).
  /// @param votingPeriodExtensionThresholdPct Minor threshold percentage for extension.
  /// @param timelock The timelock contract used for managing proposals.
  /// @param governorAdmin The address authorized to change governance parameters.
  /// @param council The address of the council governor.
  struct ConstructorParams {
    string name;
    IERC20 token;
    uint48 votingDelay;
    uint32 votingPeriod;
    uint256 proposalThreshold;
    address vetoGuardian;
    address vetoOverrideRole;
    uint48 vetoOverrideDuration;
    uint48 votingPeriodExtension;
    uint16 votingPeriodExtensionThresholdPct;
    TimelockController timelock;
    address governorAdmin;
    address council;
  }

  address public immutable COUNCIL;

  modifier onlyCouncil() virtual {
    require(_msgSender() == COUNCIL, "Only council");
    _;
  }

  constructor(ConstructorParams memory _params)
    Governor(_params.name)
    GovernorVotesComp(_params.token)
    GovernorVetoGuardian(_params.vetoGuardian)
    GovernorSettings(_params.votingDelay, _params.votingPeriod, _params.proposalThreshold)
    GovernorVetoOverride(_params.vetoOverrideRole, _params.vetoOverrideDuration)
    GovernorExtendVetoPeriod(
      _params.votingPeriodExtension, _params.votingPeriodExtensionThresholdPct
    )
    GovernorTimelockControl(_params.timelock)
    GovernorAdmin(_params.governorAdmin)
  {
    COUNCIL = _params.council;
  }

  function votingDelay()
    public
    view
    virtual
    override(Governor, GovernorSettings)
    returns (uint256)
  {
    return GovernorSettings.votingDelay();
  }

  function votingPeriod()
    public
    view
    virtual
    override(Governor, GovernorSettings)
    returns (uint256)
  {
    return GovernorSettings.votingPeriod();
  }

  function proposalThreshold()
    public
    view
    virtual
    override(Governor, GovernorSettings)
    returns (uint256)
  {
    return GovernorSettings.proposalThreshold();
  }

  function state(uint256 _proposalId)
    public
    view
    virtual
    override(Governor, GovernorTimelockControl, GovernorVetoGuardian, GovernorVetoOverride)
    returns (ProposalState)
  {
    return GovernorVetoOverride.state(_proposalId);
  }

  function proposalDeadline(uint256 _proposalId)
    public
    view
    virtual
    override(Governor, GovernorExtendVetoPeriod)
    returns (uint256)
  {
    return GovernorExtendVetoPeriod.proposalDeadline(_proposalId);
  }

  function proposalVotes(uint256 _proposalId)
    public
    view
    virtual
    override(GovernorExtendVetoPeriod, GovernorVetoCountingSimple)
    returns (uint256)
  {
    return GovernorVetoCountingSimple.proposalVotes(_proposalId);
  }

  function vetoThreshold(uint256)
    public
    view
    virtual
    override(GovernorVetoCountingSimple, GovernorExtendVetoPeriod)
    returns (uint256)
  {
    return 400_000e18;
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

  function propose(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) public virtual override onlyCouncil returns (uint256) {
    return super.propose(_targets, _values, _calldatas, _description);
  }

  function execute(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) public payable virtual override onlyCouncil returns (uint256) {
    return super.execute(_targets, _values, _calldatas, _descriptionHash);
  }

  function _checkGovernance() internal virtual override(Governor, GovernorAdmin) {
    GovernorAdmin._checkGovernance();
  }

  function _executor()
    internal
    view
    virtual
    override(Governor, GovernorTimelockControl)
    returns (address)
  {
    return GovernorTimelockControl._executor();
  }

  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal virtual override(Governor, GovernorTimelockControl) returns (uint256) {
    return GovernorTimelockControl._cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  function _queueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal virtual override(Governor, GovernorTimelockControl) returns (uint48) {
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
  ) internal virtual override(Governor, GovernorTimelockControl) {
    GovernorTimelockControl._executeOperations(
      _proposalId, _targets, _values, _calldatas, _descriptionHash
    );
  }

  function _tallyUpdated(uint256 _proposalId)
    internal
    virtual
    override(Governor, GovernorExtendVetoPeriod)
  {
    GovernorExtendVetoPeriod._tallyUpdated(_proposalId);
  }
}
