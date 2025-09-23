// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

abstract contract GovernorVetoCountingSimple is GovernorCountingSimple {
  function _vetoQuorumReached(uint256 proposalId) internal view virtual returns (bool) {
    (uint256 _againstVotes,,) = proposalVotes(proposalId);

    return vetoQuorum(proposalSnapshot(proposalId)) >= _againstVotes;
  }

  function vetoQuorum(uint256 /*timepoint*/ ) public view virtual returns (uint256);

  /// @inheritdoc GovernorCountingSimple
  function _quorumReached(uint256 proposalId) internal view virtual override returns (bool) {
    (, uint256 _forVotes, uint256 _abstainVotes) = proposalVotes(proposalId);

    // Don't care about quorum if the veto quorum is not reached
    if (!_vetoQuorumReached(proposalId)) return true;
    else return quorum(proposalSnapshot(proposalId)) <= _forVotes + _abstainVotes;
  }

  function _voteSucceeded(uint256 proposalId) internal view virtual override returns (bool) {
    (uint256 _againstVotes, uint256 _forVotes,) = proposalVotes(proposalId);

    // Vote succeeds if veto quorum is not reached
    if (!_vetoQuorumReached(proposalId)) return true;
    else return _forVotes > _againstVotes;
  }
}
