// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC6372} from "@openzeppelin/contracts/interfaces/IERC6372.sol";
import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {DeployCouncilGovernanceBase} from "script/DeployCouncilGovernanceBase.s.sol";

abstract contract DeployErc5805CouncilGovernance is DeployCouncilGovernanceBase {
  function run() public virtual override {
    DeployCouncilGovernanceBase.run();
  }

  function _deployVetoGovernor(BasicCouncilVetoGovernor.ConstructorParams memory _params)
    internal
    override
    returns (BasicCouncilVetoGovernor)
  {
    return new BasicCouncilVetoGovernor(_params);
  }

  function _validateVetoToken(VetoGovernorParams memory _params) internal view override {
    if (_params.daoToken.code.length == 0) {
      revert("DeployErc5805CouncilGovernance: DAO token has no code");
    }
    uint256 _timepoint;
    try IERC6372(_params.daoToken).clock() returns (uint48 _clock) {
      if (_clock > 0) _timepoint = uint256(_clock) - 1;
      try IERC6372(_params.daoToken).CLOCK_MODE() returns (string memory) {}
      catch {
        revert("DeployErc5805CouncilGovernance: CLOCK_MODE call failed while clock succeeded");
      }
    } catch {
      if (!_params.acknowledgeBlockNumberFallback) {
        revert(
          "DeployErc5805CouncilGovernance: token lacks ERC-6372; acknowledge block-number checkpoints"
        );
      }
      if (block.number > 0) _timepoint = block.number - 1;
    }
    (bool _votesOk, bytes memory _votesData) = _params.daoToken
      .staticcall(abi.encodeWithSignature("getPastVotes(address,uint256)", tx.origin, _timepoint));
    if (!_votesOk || _votesData.length != 32) {
      revert("DeployErc5805CouncilGovernance: getPastVotes is unavailable or malformed");
    }
    (bool _supplyOk, bytes memory _supplyData) = _params.daoToken
      .staticcall(abi.encodeWithSignature("getPastTotalSupply(uint256)", _timepoint));
    if (!_supplyOk || _supplyData.length != 32) {
      revert("DeployErc5805CouncilGovernance: getPastTotalSupply is unavailable or malformed");
    }
  }

  function _logVetoClock(VetoGovernorParams memory _params) internal view override {
    try IERC6372(_params.daoToken).CLOCK_MODE() returns (string memory _mode) {
      _log(string.concat("ERC-5805 veto timing adopts token clock: ", _mode));
    } catch {
      _log(
        "ERC-5805 token has no ERC-6372 clock; veto timing uses block numbers (fallback acknowledged)"
      );
    }
    _log(string.concat("Veto voting delay (token clock units): ", vm.toString(_params.votingDelay)));
    _log(
      string.concat("Veto voting period (token clock units): ", vm.toString(_params.votingPeriod))
    );
  }
}
