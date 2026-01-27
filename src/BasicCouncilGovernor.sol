// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.30;

// External Dependencies
import {Governor, IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {
  GovernorCountingSimple
} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {
  GovernorSuperQuorum
} from "@openzeppelin/contracts/governance/extensions/GovernorSuperQuorum.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import {
  GovernorVotesQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {
  GovernorVotesSuperQuorumFraction
} from "@openzeppelin/contracts/governance/extensions/GovernorVotesSuperQuorumFraction.sol";

// Internal Dependencies
import {GovernorAdmin} from "src/extensions/GovernorAdmin.sol";
import {GovernorCouncilQueuing} from "src/extensions/GovernorCouncilQueuing.sol";

/// @title BasicCouncilGovernor
/// @author [ScopeLift](https://scopelift.co)
/// @notice A dual-governance council governor that manages proposals through a two-stage process:
/// council voting followed by veto governor review.
/// @dev This contract implements a council-based governance system with the following key features:
/// - Proposals are created and voted on by council members using an CouncilERC20 voting token.
/// - All proposals must pass through a two-stage process: council approval → veto governor
/// review.
/// - Uses simple vote counting (For/Against/Abstain) with dynamic quorum and super quorum.
/// - Proposals that reach super quorum can advance early without waiting for the deadline.
contract BasicCouncilGovernor is
  Governor,
  GovernorCountingSimple,
  GovernorCouncilQueuing,
  GovernorSettings,
  GovernorAdmin,
  GovernorVotesSuperQuorumFraction
{
  struct InitialCouncilParams {
    uint48 initialVotingDelay;
    uint32 initialVotingPeriod;
    uint256 initialProposalThreshold;
    uint256 initialQuorumFraction;
    uint256 initialSuperQuorumFraction;
  }

  /// @notice Constructor for the BasicCouncilGovernor contract.
  /// @param _name The name of the council governor.
  /// @param _token The IERC5805 compliant token (CouncilERC20) used to vote on proposals.
  /// @param _councilVetoGovernor The veto governor contract to which proposals are forwarded.
  /// @param _governorAdmin The address authorized to change council governor parameters.
  /// @param _params The initial parameters for the council governor.
  constructor(
    string memory _name,
    IERC5805 _token,
    IGovernor _councilVetoGovernor,
    address _governorAdmin,
    InitialCouncilParams memory _params
  )
    Governor(_name)
    GovernorVotes(_token)
    GovernorCouncilQueuing(_councilVetoGovernor)
    GovernorSettings(
      _params.initialVotingDelay, _params.initialVotingPeriod, _params.initialProposalThreshold
    )
    GovernorAdmin(_governorAdmin)
    GovernorVotesQuorumFraction(_params.initialQuorumFraction)
    GovernorVotesSuperQuorumFraction(_params.initialSuperQuorumFraction)
  {}

  /// @inheritdoc GovernorSettings
  function votingDelay()
    public
    view
    virtual
    override(Governor, GovernorSettings)
    returns (uint256)
  {
    return GovernorSettings.votingDelay();
  }

  /// @inheritdoc GovernorSettings
  function votingPeriod()
    public
    view
    virtual
    override(Governor, GovernorSettings)
    returns (uint256)
  {
    return GovernorSettings.votingPeriod();
  }

  /// @inheritdoc GovernorSettings
  function proposalThreshold()
    public
    view
    virtual
    override(Governor, GovernorSettings)
    returns (uint256)
  {
    return GovernorSettings.proposalThreshold();
  }

  /// @inheritdoc IGovernor
  /// @dev If proposal is queued on both council and veto governor, return the veto governor
  /// proposal ETA. Otherwise, return council governor ETA.
  function proposalEta(uint256 proposalId)
    public
    view
    virtual
    override(Governor, GovernorCouncilQueuing)
    returns (uint256)
  {
    return GovernorCouncilQueuing.proposalEta(proposalId);
  }

  /// @inheritdoc Governor
  function clock() public view virtual override(Governor, GovernorVotes) returns (uint48) {
    return uint48(block.timestamp);
  }

  /// @notice The clock mode is set to timestamp.
  /// @return The clock mode.
  function CLOCK_MODE()
    public
    pure
    virtual
    override(Governor, GovernorVotes)
    returns (string memory)
  {
    return "mode=timestamp";
  }

  /// @inheritdoc GovernorSettings
  function setVotingDelay(uint48 _newVotingDelay) public virtual override onlyGovernance {
    _setVotingDelay(_newVotingDelay);
  }

  /// @inheritdoc GovernorSettings
  function setVotingPeriod(uint32 _newVotingPeriod) public virtual override onlyGovernance {
    _setVotingPeriod(_newVotingPeriod);
  }

  /// @inheritdoc GovernorSettings
  function setProposalThreshold(uint256 _newProposalThreshold)
    public
    virtual
    override
    onlyGovernance
  {
    _setProposalThreshold(_newProposalThreshold);
  }

  /// @inheritdoc GovernorCouncilQueuing
  function proposalNeedsQueuing(uint256 _proposalId)
    public
    view
    virtual
    override(Governor, GovernorCouncilQueuing)
    returns (bool)
  {
    return GovernorCouncilQueuing.proposalNeedsQueuing(_proposalId);
  }

  /// @inheritdoc GovernorCouncilQueuing
  function propose(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) public virtual override(Governor, GovernorCouncilQueuing) returns (uint256) {
    return GovernorCouncilQueuing.propose(_targets, _values, _calldatas, _description);
  }

  /// @inheritdoc GovernorVotesSuperQuorumFraction
  function state(uint256 _proposalId)
    public
    view
    virtual
    override(Governor, GovernorCouncilQueuing, GovernorVotesSuperQuorumFraction)
    returns (ProposalState)
  {
    return GovernorVotesSuperQuorumFraction.state(_proposalId);
  }

  /// @inheritdoc GovernorCountingSimple
  function proposalVotes(uint256 _proposalId)
    public
    view
    virtual
    override(GovernorSuperQuorum, GovernorCountingSimple)
    returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
  {
    // GovernorSuperQuorum.proposalVotes is unimplemented.
    return GovernorCountingSimple.proposalVotes(_proposalId);
  }

  /// @inheritdoc GovernorAdmin
  function _checkGovernance() internal virtual override(Governor, GovernorAdmin) {
    GovernorAdmin._checkGovernance();
  }

  /// @inheritdoc GovernorCouncilQueuing
  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal virtual override(Governor, GovernorCouncilQueuing) returns (uint256) {
    return GovernorCouncilQueuing._cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  /// @inheritdoc GovernorCouncilQueuing
  function _executeOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal virtual override(Governor, GovernorCouncilQueuing) {
    GovernorCouncilQueuing._executeOperations(
      _proposalId, _targets, _values, _calldatas, _descriptionHash
    );
  }

  /// @inheritdoc GovernorCouncilQueuing
  function _executor()
    internal
    view
    virtual
    override(Governor, GovernorCouncilQueuing)
    returns (address)
  {
    return GovernorCouncilQueuing._executor();
  }

  /// @inheritdoc GovernorCouncilQueuing
  function _queueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal virtual override(Governor, GovernorCouncilQueuing) returns (uint48) {
    return GovernorCouncilQueuing._queueOperations(
      _proposalId, _targets, _values, _calldatas, _descriptionHash
    );
  }
}
