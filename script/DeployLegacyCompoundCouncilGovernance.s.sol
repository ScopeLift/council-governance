// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {CompoundCouncilVetoGovernor} from "src/CompoundCouncilVetoGovernor.sol";
import {DeployCouncilGovernanceBase} from "script/DeployCouncilGovernanceBase.s.sol";

abstract contract DeployLegacyCompoundCouncilGovernance is DeployCouncilGovernanceBase {
  function run() public virtual override {
    DeployCouncilGovernanceBase.run();
  }

  function _deployVetoGovernor(BasicCouncilVetoGovernor.ConstructorParams memory _params)
    internal
    override
    returns (BasicCouncilVetoGovernor)
  {
    return new CompoundCouncilVetoGovernor(_params);
  }

  function _validateVetoToken(VetoGovernorParams memory _params) internal view override {
    if (_params.daoToken.code.length == 0) {
      revert("DeployLegacyCompoundCouncilGovernance: DAO token has no code");
    }
    uint256 _pastBlock;
    if (block.number > 0) _pastBlock = block.number - 1;
    (bool _votesOk, bytes memory _votesData) = _params.daoToken
      .staticcall(
        abi.encodeWithSignature("getPriorVotes(address,uint256)", address(this), _pastBlock)
      );
    if (!_votesOk || _votesData.length != 32) {
      revert("DeployLegacyCompoundCouncilGovernance: getPriorVotes is unavailable or malformed");
    }
    (bool _supplyOk, bytes memory _supplyData) =
      _params.daoToken.staticcall(abi.encodeWithSignature("totalSupply()"));
    if (!_supplyOk || _supplyData.length != 32) {
      revert("DeployLegacyCompoundCouncilGovernance: totalSupply is unavailable or malformed");
    }
  }

  function _logVetoClock(VetoGovernorParams memory _params) internal view override {
    _log(
      "WARNING: council governance uses timestamps, while legacy Compound veto voting uses blocks."
    );
    _log(string.concat("Veto voting delay (blocks): ", vm.toString(_params.votingDelay)));
    _log(string.concat("Veto voting period (blocks): ", vm.toString(_params.votingPeriod)));
    _log(
      string.concat("Veto override duration (blocks): ", vm.toString(_params.vetoOverrideDuration))
    );
    _log(string.concat("Veto extension (blocks): ", vm.toString(_params.votingPeriodExtension)));
  }
}
