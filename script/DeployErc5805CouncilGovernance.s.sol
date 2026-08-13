// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

import {BasicCouncilVetoGovernor} from "src/BasicCouncilVetoGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {DeployCouncilGovernance} from "script/DeployCouncilGovernance.s.sol";

abstract contract DeployErc5805CouncilGovernance is DeployCouncilGovernance {
  function _deployVetoGovernor(
    VetoGovernorParams memory _params,
    TimelockController _timelock,
    address _councilGovernor
  ) internal override returns (BasicCouncilVetoGovernor) {
    return new BasicCouncilVetoGovernor(
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

    IERC5805 _token = IERC5805(_params.token);

    try _token.clock() returns (uint48) {}
    catch {
      revert(
        "DeployErc5805CouncilGovernance: DAO token does not implement ERC-6372 clock(); "
        "use an ERC-5805 token with ERC-6372 support"
      );
    }

    try _token.CLOCK_MODE() returns (string memory) {}
    catch {
      revert(
        "DeployErc5805CouncilGovernance: DAO token does not implement ERC-6372 CLOCK_MODE(); "
        "use an ERC-5805 token with ERC-6372 support"
      );
    }
  }

  function _logConfiguration(
    CouncilTokenParams memory _tokenParams,
    TimelockParams memory _timelockParams,
    CouncilGovernorParams memory _councilParams,
    VetoGovernorParams memory _vetoParams
  ) internal view override {
    super._logConfiguration(_tokenParams, _timelockParams, _councilParams, _vetoParams);

    string memory _clockMode = _readClockMode(_vetoParams.token);
    _log(string.concat("  clock mode: ", _clockMode));
  }

  function _readClockMode(address _token) internal view returns (string memory) {
    try IERC5805(_token).CLOCK_MODE() returns (string memory _mode) {
      return _mode;
    } catch {
      return "unknown (ERC-6372 not supported)";
    }
  }

  function _validateDeployment(
    address _deployer,
    CouncilTokenParams memory _tokenParams,
    TimelockParams memory _timelockParams,
    CouncilGovernorParams memory _councilParams,
    VetoGovernorParams memory _vetoParams,
    address _predictedVetoGovernor
  ) internal view override {
    super._validateDeployment(
      _deployer, _tokenParams, _timelockParams, _councilParams, _vetoParams, _predictedVetoGovernor
    );

    try IERC5805(_vetoParams.token).clock() returns (uint48 _tokenClock) {
      try vetoGovernor.clock() returns (uint48 _govClock) {
        if (_tokenClock != _govClock) {
          revert(
            string.concat(
              "DeployErc5805CouncilGovernance: veto governor clock ",
              _toStr(_govClock),
              " does not match token clock ",
              _toStr(_tokenClock)
            )
          );
        }
      } catch {
        revert("DeployErc5805CouncilGovernance: veto governor clock() reverted");
      }
    } catch {
      revert("DeployErc5805CouncilGovernance: token clock() reverted during validation");
    }
  }
}
