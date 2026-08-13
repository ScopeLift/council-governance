// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

import {DeployErc5805CouncilGovernance} from "script/DeployErc5805CouncilGovernance.s.sol";
import {DeployCouncilGovernance} from "script/DeployCouncilGovernance.s.sol";

contract DeployCouncilGovernanceTest is DeployErc5805CouncilGovernance {
  IERC5805 internal immutable _daoToken;
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

  constructor(IERC5805 _daoToken_, address _admin_) {
    _daoToken = _daoToken_;
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
      name: "BasicCouncilVetoGovernor",
      token: address(_daoToken),
      votingDelay: 1 hours,
      votingPeriod: 1 days,
      proposalThreshold: 0,
      vetoGuardian: address(0),
      vetoOverrideRole: _admin,
      vetoOverrideDuration: 4 days,
      votingPeriodExtension: 3 days,
      votingPeriodExtensionThresholdPct: 50,
      vetoThresholdNumerator: 10,
      governorAdmin: _admin
    });
  }
}
