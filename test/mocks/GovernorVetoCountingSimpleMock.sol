// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVetoCountingSimple} from "src/extensions/GovernorVetoCountingSimple.sol";

/**
 * @title GovernorVetoCountingSimpleMock
 * @dev Mock implementation of GovernorVetoCountingSimple for testing purposes.
 */
contract GovernorVetoCountingSimpleMock is GovernorVetoCountingSimple {
  constructor() Governor("GovernorVetoCountingSimpleMock") {}

  function votingDelay() public pure override returns (uint256) {
    return 1 hours;
  }

  function votingPeriod() public pure override returns (uint256) {
    return 1 days;
  }

  function quorum(
    uint256 /* timepoint */
  )
    public
    pure
    override
    returns (uint256)
  {
    return 100; // Return a fixed quorum value for unit tests
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

  /// @notice Exposes _countVote for unit testing purposes
  function countVote(
    uint256 proposalId,
    address account,
    uint8 support,
    uint256 weight,
    bytes memory params
  ) public returns (uint256) {
    return _countVote(proposalId, account, support, weight, params);
  }

  /// @notice Exposes _quorumReached for unit testing purposes
  function getQuorumReached(uint256 proposalId) public view returns (bool) {
    return _quorumReached(proposalId);
  }

  /// @notice Exposes _voteSucceeded for unit testing purposes
  function getVoteSucceeded(uint256 proposalId) public view returns (bool) {
    return _voteSucceeded(proposalId);
  }
}
