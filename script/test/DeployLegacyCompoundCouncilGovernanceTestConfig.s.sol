// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DeployCouncilGovernanceBase} from "script/DeployCouncilGovernanceBase.s.sol";
import {
  DeployLegacyCompoundCouncilGovernance
} from "script/DeployLegacyCompoundCouncilGovernance.s.sol";

contract DeployLegacyCompoundCouncilGovernanceTestConfig is DeployLegacyCompoundCouncilGovernance {
  address internal constant COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;

  function run() public override {
    DeployCouncilGovernanceBase.run();
  }

  function _getCouncilTokenParams() internal pure override returns (CouncilTokenParams memory) {
    address[] memory _members = new address[](3);
    _members[0] = address(0x2001);
    _members[1] = address(0x2002);
    _members[2] = address(0x2003);
    return CouncilTokenParams({
      name: "Test Compound Council",
      symbol: "TCOMP",
      admin: address(0xA11CE),
      maxTokensPerMember: 1e18,
      councilMembers: _members
    });
  }

  function _getTimelockParams() internal pure override returns (TimelockParams memory) {
    return TimelockParams({minDelay: 1 days});
  }

  function _getCouncilGovernorParams()
    internal
    pure
    override
    returns (CouncilGovernorParams memory)
  {
    return CouncilGovernorParams({
      name: "Test Compound Council Governor",
      votingDelay: 1 days,
      votingPeriod: 7 days,
      proposalThreshold: 1e18,
      quorumNumerator: 60,
      superQuorumNumerator: 100,
      admin: DEFAULT_SENDER
    });
  }

  function _getVetoGovernorParams() internal pure override returns (VetoGovernorParams memory) {
    return VetoGovernorParams({
      name: "Test Compound Veto Governor",
      daoToken: COMP,
      votingDelay: 300,
      votingPeriod: 7200,
      vetoGuardian: address(0),
      vetoOverrideRole: DEFAULT_SENDER,
      vetoOverrideDuration: 28_800,
      votingPeriodExtension: 21_600,
      votingPeriodExtensionThresholdPct: 50,
      vetoThresholdNumerator: 10,
      admin: DEFAULT_SENDER,
      acknowledgeBlockNumberFallback: false
    });
  }
}
