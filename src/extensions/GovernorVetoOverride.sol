// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";

// TODO: `onlyGovernance` prob the right modifier for these fns, go with `onlyAdmin`
abstract contract GovernorVetoOverride is Governor {
  mapping(uint256 proposalId => bool) public isVetoOverridden;
  uint48 public vetoOverrideDuration;

  event VetoOverridden(uint256 proposalId);
  event VetoOverrideDurationSet(uint48 oldVetoOverrideDuration, uint48 newVetoOverrideDuration);
  event VetoOverrideRoleSet(
    address indexed oldVetoOverrideRole, address indexed newVetoOverrideRole
  );

  address public vetoOverrideRole;

  modifier onlyVetoOverrideRole() {
    require(
      _msgSender() == vetoOverrideRole, "GovernorVetoOverride: caller is not the veto override role"
    );
    _;
  }

  constructor(address _vetoOverrideRole, uint48 _vetoOverrideDuration) {
    vetoOverrideRole = _vetoOverrideRole;
    vetoOverrideDuration = _vetoOverrideDuration;
  }

  function setVetoOverrideRole(address _vetoOverrideRole) public virtual onlyGovernance {
    _setVetoOverrideRole(_vetoOverrideRole);
  }

  function setVetoOverrideDuration(uint48 _vetoOverrideDuration) public virtual onlyGovernance {
    _setVetoOverrideDuration(_vetoOverrideDuration);
  }

  function _setVetoOverrideRole(address _vetoOverrideRole) internal virtual {
    emit VetoOverrideRoleSet(vetoOverrideRole, _vetoOverrideRole);
    vetoOverrideRole = _vetoOverrideRole;
  }

  function _setVetoOverrideDuration(uint48 _vetoOverrideDuration) internal virtual {
    emit VetoOverrideDurationSet(vetoOverrideDuration, _vetoOverrideDuration);
    vetoOverrideDuration = _vetoOverrideDuration;
  }

  function overrideVeto(uint256 proposalId) public virtual onlyVetoOverrideRole {
    isVetoOverridden[proposalId] = true;
    emit VetoOverridden(proposalId);
  }

  function state(uint256 proposalId) public view virtual override returns (ProposalState) {
    ProposalState _state = super.state(proposalId);
    if (
      isVetoOverridden[proposalId] && _state == ProposalState.Defeated
        && clock() - proposalDeadline(proposalId) < vetoOverrideDuration
    ) return ProposalState.Succeeded;
    return _state;
  }
}
