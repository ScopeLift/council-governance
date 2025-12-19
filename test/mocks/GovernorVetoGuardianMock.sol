// SPDX-License-Identifier: AGPL-3.0-only

pragma solidity ^0.8.24;

// External Dependencies
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";

// Internal Dependencies
import {GovernorVetoGuardian} from "src/extensions/GovernorVetoGuardian.sol";

/// @title GovernorVetoGuardianMock
/// @dev Mock implementation of GovernorVetoGuardian for testing purposes.
contract GovernorVetoGuardianMock is GovernorVetoGuardian {
  mapping(uint256 => bool) internal _defeated;

  constructor(address _vetoGuardian)
    Governor("GovernorVetoOverrideMock")
    GovernorVetoGuardian(_vetoGuardian)
  {}

  /// @notice Test utility function that sets a given proposal to defeated.
  function setDefeated(uint256 proposalId) public {
    _defeated[proposalId] = true;
  }

  function exposed_setVetoGuardian(address _newVetoGuardian) public {
    _setVetoGuardian(_newVetoGuardian);
  }

  function COUNTING_MODE() external pure returns (string memory) {
    return "support=veto&quorum=veto";
  }

  function votingDelay() public pure override returns (uint256) {
    return 1 hours;
  }

  function votingPeriod() public pure override returns (uint256) {
    return 1 days;
  }

  function quorum(
    uint256 /*timepoint*/
  )
    public
    pure
    override
    returns (uint256)
  {
    return 0;
  }

  function clock() public view virtual override(Governor) returns (uint48) {
    return Time.blockNumber();
  }

  function CLOCK_MODE() public pure virtual override(Governor) returns (string memory) {
    return "mode=blocknumber&from=default";
  }

  function hasVoted(
    uint256, //proposalId
    address //account
  )
    public
    view
    virtual
    override
    returns (bool)
  {
    return false;
  }

  function state(uint256 proposalId) public view override returns (ProposalState) {
    return GovernorVetoGuardian.state(proposalId);
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

  function _countVote(
    uint256, // proposalId
    address, // account
    uint8, // support
    uint256, // totalWeight
    bytes memory // params
  )
    internal
    virtual
    override
    returns (uint256)
  {
    return 0;
  }

  function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    return !_defeated[proposalId];
  }

  function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    return !_defeated[proposalId];
  }

  function _queueOperations(
    uint256, /*proposalId*/
    address[] memory, /*targets*/
    uint256[] memory, /*values*/
    bytes[] memory, /*calldatas*/
    bytes32 /*descriptionHash*/
  )
    internal
    pure
    override
    returns (uint48)
  {
    return 1 days;
  }
}
