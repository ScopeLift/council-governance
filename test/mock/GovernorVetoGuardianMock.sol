// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorVetoGuardian} from "src/extensions/GovernorVetoGuardian.sol";

/**
 * @title GovernorVetoGuardianMock
 * @dev Mock implementation of GovernorVetoGuardian for testing purposes.
 */
contract GovernorVetoGuardianMock is GovernorVetoGuardian {
  mapping(uint256 => bool) internal _defeated;

  constructor(address _vetoGuardian)
    Governor("GovernorVetoOverrideMock")
    GovernorVetoGuardian(_vetoGuardian)
  {}

  function votingDelay() public pure override returns (uint256) {
    return 1 hours;
  }

  function votingPeriod() public pure override returns (uint256) {
    return 1 days;
  }

  function quorum(uint256 /*timepoint*/ ) public pure override returns (uint256) {
    return 0;
  }

  function clock() public view override returns (uint48) {
    return uint48(block.timestamp);
  }

  function CLOCK_MODE() public pure override returns (string memory) {
    return "mode=timestamp";
  }

  function _getVotes(address, /* account */ uint256, /* timepoint */ bytes memory /* params */ )
    internal
    pure
    override
    returns (uint256)
  {
    return 1; // Return a default vote weight for testing
  }

  function COUNTING_MODE() external pure returns (string memory) {
    return "support=veto&quorum=veto";
  }

  function hasVoted(
    uint256, //proposalId
    address //account
  ) public view virtual override returns (bool) {
    return false;
  }

  function _countVote(
    uint256, // proposalId
    address, // account
    uint8, // support
    uint256, // totalWeight
    bytes memory // params
  ) internal virtual override returns (uint256) {
    return 0;
  }

  function setDefeated(uint256 proposalId) public {
    _defeated[proposalId] = true;
  }

  function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    return !_defeated[proposalId];
  }

  function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    return !_defeated[proposalId];
  }

  function state(uint256 proposalId) public view override returns (ProposalState) {
    return GovernorVetoGuardian.state(proposalId);
  }

  function _queueOperations(
    uint256, /*proposalId*/
    address[] memory, /*targets*/
    uint256[] memory, /*values*/
    bytes[] memory, /*calldatas*/
    bytes32 /*descriptionHash*/
  ) internal pure override returns (uint48) {
    return 1 days;
  }

  function exposed_SetVetoGuardian(address _newVetoGuardian) public {
    _setVetoGuardian(_newVetoGuardian);
  }
}
