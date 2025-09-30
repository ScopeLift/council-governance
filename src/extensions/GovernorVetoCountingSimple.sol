// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

abstract contract GovernorVetoCountingSimple is GovernorCountingSimple {
  /**
   * @dev See {Governor-_quorumReached}. In this module, the quorum is reached if the againstVotes
   * are greater than or equal to the quorum.
   */
  function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    (uint256 _againstVotes,,) = proposalVotes(proposalId);
    return quorum(proposalSnapshot(proposalId)) <= _againstVotes;
  }

  /**
   * @dev See {Governor-_voteSucceeded}. In this module, the vote succeeds if the quorum has not
   * been reached.
   */
  function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    return !_quorumReached(proposalId);
  }

  function _castVote(
    uint256 proposalId,
    address account,
    uint8 support,
    string memory reason,
    bytes memory params
  ) internal virtual override returns (uint256) {
    require(
      support == uint8(VoteType.Against), "GovernorVetoCountingSimple: can only cast against vote"
    );
    return super._castVote(proposalId, account, support, reason, params);
  }
}
