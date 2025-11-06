// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

/**
 * @dev Minimal fake implementation of Governor for testing GovernorCouncilQueuing.
 * This fake inherits from Governor and only overrides what's needed for testing.
 */
// !! Should we inherit GovernorTimelockControl just to add timelock to it
contract BasicCouncilVetoGovernorFake is Governor, GovernorVotes {
  // Storage for controlling fake behavior
  mapping(uint256 proposalId => ProposalState) private _fakeStates;

  // Track function calls for testing
  address[] public lastProposeTargets;
  uint256[] public lastProposeValues;
  bytes[] public lastProposeCalldatas;
  string public lastProposeDescription;

  uint256 public proposeCallCount;
  uint256 public executeCallCount;
  uint256 public lastProposedId;

  constructor(IERC5805 _token) Governor("BasicCouncilVetoGovernorFake") GovernorVotes(_token) {}

  /**
   * @dev Manually set the state of a proposal for testing.
   */
  function setProposalState(uint256 proposalId, ProposalState newState) external {
    _fakeStates[proposalId] = newState;
  }

  /// @dev Override state to return fake state if set, otherwise use parent.
  function state(uint256 proposalId) public view override returns (ProposalState) {
    if (_fakeStates[proposalId] != ProposalState(0)) return _fakeStates[proposalId];
    return super.state(proposalId);
  }

  /**
   * @dev Override propose to track calls.
   */
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) public override returns (uint256) {
    delete lastProposeTargets;
    delete lastProposeValues;
    delete lastProposeCalldatas;
    delete lastProposeDescription;

    for (uint256 i = 0; i < targets.length; i++) {
      lastProposeTargets.push(targets[i]);
      lastProposeValues.push(values[i]);
      lastProposeCalldatas.push(calldatas[i]);
    }
    lastProposeDescription = description;

    proposeCallCount++;
    uint256 proposalId = super.propose(targets, values, calldatas, description);
    lastProposedId = proposalId;
    return proposalId;
  }

  /**
   * @dev Override execute to track calls.
   */
  function execute(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) public payable override returns (uint256) {
    executeCallCount++;
    return super.execute(targets, values, calldatas, descriptionHash);
  }

  /**
   * @dev Helper to reset call counts between tests.
   */
  function reset() external {
    proposeCallCount = 0;
    executeCallCount = 0;
    lastProposedId = 0;
  }
  /// Required overrides

  function votingDelay() public pure override returns (uint256) {
    return 1 days;
  }

  /// Required overrides
  function votingPeriod() public pure override returns (uint256) {
    return 1 weeks;
  }

  /// Required overrides
  function quorum(uint256) public pure override returns (uint256) {
    return 100;
  }

  /// Required overrides
  function COUNTING_MODE() public pure override returns (string memory) {
    return "support=bravo&quorum=for,abstain";
  }

  /// Required overrides
  function _countVote(uint256, address, uint8, uint256, bytes memory)
    internal
    pure
    override
    returns (uint256)
  {
    return 1; // Simple counting for testing
  }

  /// Required overrides
  function _quorumReached(uint256) internal pure override returns (bool) {
    return true; // Always reached for testing
  }

  /// Required overrides
  function _voteSucceeded(uint256) internal pure override returns (bool) {
    return true; // Always succeeds for testing
  }

  /// Required overrides
  function hasVoted(uint256, address) public pure override returns (bool) {
    return false; // No one has voted for testing
  }
}
