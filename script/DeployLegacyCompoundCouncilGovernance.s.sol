// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {CompoundCouncilVetoGovernor, ICompVotes} from "src/CompoundCouncilVetoGovernor.sol";
import {DeployCouncilGovernance} from "script/DeployCouncilGovernance.s.sol";

abstract contract DeployLegacyCompoundCouncilGovernance is DeployCouncilGovernance {
  function _deployVetoGovernor(
    VetoGovernorParams memory _params,
    TimelockController _timelock,
    address _councilGovernor
  ) internal override returns (BasicCouncilVetoGovernor) {
    return new CompoundCouncilVetoGovernor(
      BasicCouncilVetoGovernor.ConstructorParams({
          name: _params.name,
          token: _params.token,
          votingDelay: _params.votingDelay,
          votingPeriod: _params.votingPeriod,
          proposalThreshold: _params.proposalThreshold,
          vetoGuardian: _params.vetoGuardian,
          vetoOverrideRole: _params.vetoOverrideRole,
          vetoOverrideDuration: _params.vetoOverrideDuration,
          votingPeriodExtension: _params.votingPeriodExtension,
          votingPeriodExtensionThresholdPct: _params.votingPeriodExtensionThresholdPct,
          vetoThresholdNumerator: _params.vetoThresholdNumerator,
          timelock: _timelock,
          governorAdmin: _params.governorAdmin,
          council: _councilGovernor
        })
    );
  }

  function _validateVetoGovernorParams(VetoGovernorParams memory _params)
    internal
    view
    virtual
    override
  {
    super._validateVetoGovernorParams(_params);

    ICompVotes _compToken = ICompVotes(_params.token);

    try _compToken.getPriorVotes(address(0), 0) returns (uint96) {}
    catch {
      revert(
        "DeployLegacyCompoundCouncilGovernance: DAO token does not support getPriorVotes; "
        "use a COMP-style token with getPriorVotes(address,uint256)"
      );
    }

    try _compToken.totalSupply() returns (uint256) {}
    catch {
      revert(
        "DeployLegacyCompoundCouncilGovernance: DAO token does not support totalSupply; "
        "use a COMP-style token with totalSupply()"
      );
    }
  }

  function run() public virtual override {
    _log(
      "WARNING: Council stage uses timestamps while veto voting uses blocks. "
      "See https://github.com/ScopeLift/council-governance/issues/88"
    );

    super.run();
  }

  function _logConfiguration(
    CouncilTokenParams memory _tokenParams,
    TimelockParams memory _timelockParams,
    CouncilGovernorParams memory _councilParams,
    VetoGovernorParams memory _vetoParams
  ) internal view override {
    _log(
      "WARNING: Council stage uses timestamps while veto voting uses blocks. "
      "proposalEta() changes meaning and units during the proposal lifecycle. "
      "See https://github.com/ScopeLift/council-governance/issues/88"
    );

    super._logConfiguration(_tokenParams, _timelockParams, _councilParams, _vetoParams);

    _log("  (all veto timing values are block counts)");
  }
}
