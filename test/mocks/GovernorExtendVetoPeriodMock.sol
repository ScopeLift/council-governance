// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// Internal Dependencies
import {Governor, GovernorExtendVetoPeriod} from "src/extensions/GovernorExtendVetoPeriod.sol";
import {GovernorVetoCountingSimple} from "src/extensions/GovernorVetoCountingSimple.sol";

/// @title GovernorExtendVetoPeriodMock
/// @author [ScopeLift](https://scopelift.co)
contract GovernorExtendVetoPeriodMock is GovernorExtendVetoPeriod, GovernorVetoCountingSimple {
  constructor(uint48 _initialVotingPeriodExtension, uint16 _initialVotingPeriodExtensionThreshold)
    Governor("GovernorExtendVetoPeriodMock")
    GovernorExtendVetoPeriod(_initialVotingPeriodExtension, _initialVotingPeriodExtensionThreshold)
  {}

  bool private _triggerVotingPeriodExtensionThreshold;

  function forceTriggerVotingPeriodExtensionThreshold() external {
    _triggerVotingPeriodExtensionThreshold = true;
  }

  function votingDelay() public pure override returns (uint256) {
    return 1 hours;
  }

  function votingPeriod() public pure override returns (uint256) {
    return 10 days;
  }

  function vetoThreshold(
    uint256 /*timepoint*/
  )
    public
    pure
    override(GovernorVetoCountingSimple, GovernorExtendVetoPeriod)
    returns (uint256)
  {
    return 10e18;
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
    override(GovernorVetoCountingSimple, GovernorExtendVetoPeriod)
    returns (uint256 _againstVotes)
  {
    return GovernorVetoCountingSimple.proposalVotes(_proposalId);
  }

  function clock() public view override returns (uint48) {
    return uint48(block.timestamp);
  }

  function CLOCK_MODE() public pure override returns (string memory) {
    return "mode=timestamp";
  }

  function _getVotes(
    address,
    /* account */
    uint256,
    /* timepoint */
    bytes memory /* params */
  )
    internal
    pure
    override
    returns (uint256)
  {
    return 1; // Return a default vote weight for testing
  }

  function _votingPeriodExtensionThresholdTriggered(uint256 _proposalId)
    internal
    view
    override
    returns (bool)
  {
    if (_triggerVotingPeriodExtensionThreshold) return true;
    return super._votingPeriodExtensionThresholdTriggered(_proposalId);
  }

  function _tallyUpdated(uint256 _proposalId)
    internal
    virtual
    override(Governor, GovernorExtendVetoPeriod)
  {
    GovernorExtendVetoPeriod._tallyUpdated(_proposalId);
  }

  function exposed_countVote(
    uint256 proposalId,
    address account,
    uint8 support,
    uint256 weight,
    bytes memory params
  ) public returns (uint256) {
    return _countVote(proposalId, account, support, weight, params);
  }

  function exposed_VotingPeriodExtensionThresholdTriggered(uint256 _proposalId)
    public
    view
    returns (bool)
  {
    return _votingPeriodExtensionThresholdTriggered(_proposalId);
  }

  function exposed_TallyUpdated(uint256 _proposalId) public {
    _tallyUpdated(_proposalId);
  }

  function exposed_SetVotingPeriodExtension(uint48 _newVotingPeriodExtension) public {
    _setVotingPeriodExtension(_newVotingPeriodExtension);
  }

  function exposed_setMinorVetoExtensionThresholdPct(uint16 _newVetoPeriodExtensionThresholdPct)
    public
  {
    _setMinorVetoExtensionThresholdPct(_newVetoPeriodExtensionThresholdPct);
  }
}
