// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

abstract contract GovernorVetoCountingSimple is GovernorCountingSimple {
  /// @inheritdoc GovernorCountingSimple
  function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    (uint256 _againstVotes,,) = proposalVotes(proposalId);
    return quorum(proposalSnapshot(proposalId)) <= _againstVotes;
  }

  /// @inheritdoc GovernorCountingSimple
  function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    return _quorumReached(proposalId);
  }
}
