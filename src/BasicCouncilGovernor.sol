// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External Dependencies
import {Governor, IGovernor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";
import {GovernorSuperQuorum} from
  "@openzeppelin/contracts/governance/extensions/GovernorSuperQuorum.sol";
import {GovernorSettings} from "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";

// Internal Dependencies
import {GovernorAdmin} from "src/extensions/GovernorAdmin.sol";
import {GovernorCouncilQueuing} from "src/extensions/GovernorCouncilQueuing.sol";

/// @title BasicCouncilGovernor
/// @author [ScopeLift](https://scopelift.co)
/// @notice A dual-governance council governor that manages proposals through a two-stage process:
/// council voting followed by veto governor review.
///
/// @dev This contract implements a council-based governance system with the following key features:
///
/// **Core Functionality:**
/// - Proposals are created and voted on by council members using an CouncilERC20 voting token
/// - All proposals must pass through a two-stage process: council approval → veto governor review
/// - Uses simple vote counting (For/Against/Abstain) with fixed quorum and super quorum
/// - Proposals that reach super quorum can advance early without waiting for the deadline
///
/// **Parent Contracts & Their Roles:**
///
/// 1. **Governor** (base): Core governance lifecycle management
///    - Manages proposal creation, voting, queuing, execution, and cancellation
///    - Tracks proposal states (Pending → Active → Succeeded → Queued → Executed)
///
/// 2. **GovernorVotes**: Voting power integration
///    - Sources voting power from an CouncilERC20 token
///
/// 3. **GovernorCountingSimple**: Vote counting mechanism
///    - Tracks three vote types: Against, For, Abstain
///    - Counts votes per proposal and tracks which accounts have voted
///
/// 4. **GovernorCouncilQueuing**: Dual-governance integration
///    - **Critical**: All proposals are automatically forwarded to a veto governor
/// (`councilVetoGovernor`)
///    - When a council proposal reaches `Queued` state, it creates a corresponding proposal on the
/// veto governor
///    - Proposal state depends on both council and veto governor states
///    - Execution is delegated to the veto governor (which executes through a timelock)
///    - Cancellation cancels both the council proposal and the corresponding veto governor proposal
///
/// 5. **GovernorSuperQuorum**: Early proposal advancement
///    - Allows proposals to advance from `Active` to `Succeeded` before the deadline
///
/// 6. **GovernorSettings**: Configurable governance parameters
///    - Manages `votingDelay`, `votingPeriod`, and `proposalThreshold`
///    - These can be updated via governance proposals (restricted to admin via `GovernorAdmin`)
///
/// 7. **GovernorAdmin**: Admin-restricted governance operations
///    - Allows an external admin to maintain control over the council governor settings
///
/// **Proposal Lifecycle:**
/// 1. **Propose**: Council member creates a proposal (requires `proposalThreshold` tokens)
/// 2. **Pending**: Proposal waits for `votingDelay` period
/// 3. **Active**: Voting period begins, council members can cast votes
///    - If `superQuorum` (7) FOR votes reached → advance to `Succeeded` early
///    - Otherwise wait until deadline
/// 4. **Succeeded**: Proposal passed council vote (quorum reached, FOR > AGAINST)
/// 5. **Queued**: Proposal forwarded to veto governor, creating a corresponding proposal there
///    - Council proposal state now depends on veto governor's proposal state
///    - Remains `Queued` while veto governor proposal is Pending/Active/Queued/Succeeded
///    - Becomes `Executed` if veto governor proposal is Executed
///    - Becomes `Canceled` if veto governor proposal is Canceled/Defeated/Expired
/// 6. **Executed**: Proposal executed through the veto governor (typically via timelock)
///
/// **Security Model:**
/// - Council can create and vote on proposals
/// - Council cannot modify governance parameters (restricted to admin)
/// - All proposals must pass through veto governor for execution
/// - Veto governor can reject proposals through its own voting mechanism
contract BasicCouncilGovernor is
  Governor,
  GovernorVotes,
  GovernorCountingSimple,
  GovernorCouncilQueuing,
  GovernorSuperQuorum,
  GovernorSettings,
  GovernorAdmin
{
  /*///////////////////////////////////////////////////////////////
                          Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Constructor for the BasicCouncilGovernor contract.
  /// @param _token The IERC5805 compliant token (CouncilERC20) used to vote on proposals.
  /// @param _councilVetoGovernor The veto governor contract to which proposals are forwarded.
  /// @param _governorAdmin The address authorized to change council governor parameters.
  /// @param _initialVotingDelay The initial voting delay.
  /// @param _initialVotingPeriod The initial voting period.
  /// @param _initialProposalThreshold The initial proposal threshold.
  constructor(
    IERC5805 _token,
    IGovernor _councilVetoGovernor,
    address _governorAdmin,
    uint48 _initialVotingDelay,
    uint32 _initialVotingPeriod,
    uint256 _initialProposalThreshold
  )
    Governor("BasicCouncilGovernor")
    GovernorVotes(_token)
    GovernorCouncilQueuing(_councilVetoGovernor)
    GovernorSettings(_initialVotingDelay, _initialVotingPeriod, _initialProposalThreshold)
    GovernorAdmin(_governorAdmin)
  {}

  /*///////////////////////////////////////////////////////////////
                        Public Functions
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc Governor
  function votingDelay() public view override(Governor, GovernorSettings) returns (uint256) {
    return GovernorSettings.votingDelay();
  }

  /// @inheritdoc Governor
  function votingPeriod() public view override(Governor, GovernorSettings) returns (uint256) {
    return GovernorSettings.votingPeriod();
  }

  /// @inheritdoc Governor
  function proposalThreshold() public view override(Governor, GovernorSettings) returns (uint256) {
    return GovernorSettings.proposalThreshold();
  }

  /// @inheritdoc Governor
  function quorum(uint256 /*timepoint*/ ) public pure override returns (uint256) {
    return 4;
  }

  /// @inheritdoc GovernorSuperQuorum
  function superQuorum(uint256 /*timepoint*/ ) public view virtual override returns (uint256) {
    return 7;
  }

  /// @inheritdoc Governor
  function clock() public view override(Governor, GovernorVotes) returns (uint48) {
    return uint48(block.timestamp);
  }

  /// @notice The clock mode is set to timestamp.
  /// @return The clock mode.
  function CLOCK_MODE() public pure override(Governor, GovernorVotes) returns (string memory) {
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
  ) public override(Governor, GovernorCouncilQueuing) returns (uint256) {
    return GovernorCouncilQueuing.propose(_targets, _values, _calldatas, _description);
  }

  /// @inheritdoc GovernorSuperQuorum
  function state(uint256 _proposalId)
    public
    view
    override(Governor, GovernorCouncilQueuing, GovernorSuperQuorum)
    returns (ProposalState)
  {
    return GovernorSuperQuorum.state(_proposalId);
  }

  /// @inheritdoc GovernorCountingSimple
  function proposalVotes(uint256 _proposalId)
    public
    view
    override(GovernorSuperQuorum, GovernorCountingSimple)
    returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)
  {
    // GovernorSuperQuorum.proposalVotes is unimplemented.
    return GovernorCountingSimple.proposalVotes(_proposalId);
  }

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

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
  ) internal override(Governor, GovernorCouncilQueuing) returns (uint256) {
    return GovernorCouncilQueuing._cancel(_targets, _values, _calldatas, _descriptionHash);
  }

  /// @inheritdoc GovernorCouncilQueuing
  function _executeOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorCouncilQueuing) {
    GovernorCouncilQueuing._executeOperations(
      _proposalId, _targets, _values, _calldatas, _descriptionHash
    );
  }

  /// @inheritdoc GovernorCouncilQueuing
  function _executor() internal view override(Governor, GovernorCouncilQueuing) returns (address) {
    return address(councilVetoGovernor);
  }

  /// @inheritdoc GovernorCouncilQueuing
  function _queueOperations(
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal override(Governor, GovernorCouncilQueuing) returns (uint48) {
    return GovernorCouncilQueuing._queueOperations(
      _proposalId, _targets, _values, _calldatas, _descriptionHash
    );
  }
}
