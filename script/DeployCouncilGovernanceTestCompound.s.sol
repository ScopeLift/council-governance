// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
  DeployLegacyCompoundCouncilGovernance
} from "script/DeployLegacyCompoundCouncilGovernance.s.sol";
import {DeployCouncilGovernance} from "script/DeployCouncilGovernance.s.sol";

contract DeployCouncilGovernanceTestCompound is DeployLegacyCompoundCouncilGovernance {
  address constant COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
  address internal immutable _admin;

  address[] _councilMembers = [
    address(bytes20("council member 0")),
    address(bytes20("council member 1")),
    address(bytes20("council member 2")),
    address(bytes20("council member 3")),
    address(bytes20("council member 4")),
    address(bytes20("council member 5")),
    address(bytes20("council member 6"))
  ];

  constructor(address _admin_) {
    _admin = _admin_;
  }

  function run() public override {
    DeployCouncilGovernance.run();
  }

  function _getCouncilTokenParams() internal view override returns (CouncilTokenParams memory) {
    return CouncilTokenParams({
      name: "Optimistic Council",
      symbol: "OC",
      admin: _admin,
      maxTokensPerMember: 1,
      members: _councilMembers
    });
  }

  function _getTimelockParams() internal pure override returns (TimelockParams memory) {
    return TimelockParams({minDelay: 1 days});
  }

  function _getCouncilGovernorParams()
    internal
    view
    override
    returns (CouncilGovernorParams memory)
  {
    return CouncilGovernorParams({
      name: "BasicCouncilGovernor",
      votingDelay: 1 days,
      votingPeriod: 1 weeks,
      proposalThreshold: 1,
      quorumFraction: 60,
      superQuorumFraction: 100,
      admin: _admin
    });
  }

  function _getVetoGovernorParams() internal view override returns (VetoGovernorParams memory) {
    return VetoGovernorParams({
      name: "CompoundCouncilVetoGovernor",
      token: COMP,
      votingDelay: 300,
      votingPeriod: 7200,
      proposalThreshold: 0,
      vetoGuardian: address(0),
      vetoOverrideRole: _admin,
      vetoOverrideDuration: 28_800,
      votingPeriodExtension: 21_600,
      votingPeriodExtensionThresholdPct: 50,
      vetoThresholdNumerator: 10,
      governorAdmin: _admin
    });
  }
}
