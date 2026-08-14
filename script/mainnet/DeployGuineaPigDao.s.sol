// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DeployCouncilGovernanceBase} from "script/DeployCouncilGovernanceBase.s.sol";
import {DeployErc5805CouncilGovernance} from "script/DeployErc5805CouncilGovernance.s.sol";

contract DeployGuineaPigDao is DeployErc5805CouncilGovernance {
  address internal constant DAO_TOKEN = 0x1f3Bd01DdeDba455d7f8B617257c24d5eDA6dD67;
  address internal constant DAO_TIMELOCK = 0x514DBF5Fd3E347C06b8a734A3cBFEc1f6f040A19;
  address internal constant VETO_GUARDIAN = 0x9836c4EDd97FEc117bFB5a33AB46eF8dd965AD1C; // Marco
  address internal constant VETO_OVERRIDE_ROLE = 0x9836c4EDd97FEc117bFB5a33AB46eF8dd965AD1C; // Marco

  function run() public override {
    DeployCouncilGovernanceBase.run();
  }

  function _getCouncilTokenParams() internal pure override returns (CouncilTokenParams memory) {
    address[] memory _councilMembers = new address[](5);
    _councilMembers[0] = 0x16B57aeC1F9BB7F63686A87378Add160270C8f9D; // Ben
    _councilMembers[1] = 0x9836c4EDd97FEc117bFB5a33AB46eF8dd965AD1C; // Marco
    _councilMembers[2] = 0x510D84DC7a5dB3B49d4EED6a0C81ca64175E86bf; // Mike
    _councilMembers[3] = 0xfa594DAB003Ea167294e78B4aCEa5Bbef9de4eff; // Hugo
    _councilMembers[4] = 0xEAC5F0d4A9a45E1f9FdD0e7e2882e9f60E301156; // Alex
    return CouncilTokenParams({
      name: "Guinea Pig DAO Minters Council",
      symbol: "GPDMINTCOUNCIL",
      admin: DAO_TIMELOCK,
      maxTokensPerMember: 1,
      councilMembers: _councilMembers
    });
  }

  function _getTimelockParams() internal pure override returns (TimelockParams memory) {
    return TimelockParams({minDelay: 12 minutes});
  }

  function _getCouncilGovernorParams()
    internal
    pure
    override
    returns (CouncilGovernorParams memory)
  {
    return CouncilGovernorParams({
      name: "Guinea Pig DAO Minters Council Governor",
      votingDelay: 20 minutes,
      votingPeriod: 1 hours,
      proposalThreshold: 1,
      quorumNumerator: 50, // Two of four council members.
      superQuorumNumerator: 75, // Three of four council members.
      admin: DAO_TIMELOCK
    });
  }

  function _getVetoGovernorParams() internal pure override returns (VetoGovernorParams memory) {
    return VetoGovernorParams({
      name: "Guinea Pig DAO Minters Council Veto Governor",
      daoToken: DAO_TOKEN,
      votingDelay: 0,
      votingPeriod: 300, // Approximately one hour at 12 seconds per block.
      vetoGuardian: VETO_GUARDIAN,
      vetoOverrideRole: VETO_OVERRIDE_ROLE,
      vetoOverrideDuration: 100, // Approximately 20 minutes at 12 seconds per block.
      votingPeriodExtension: 150, // Approximately 30 minutes at 12 seconds per block.
      votingPeriodExtensionThresholdPct: 50, // Half the veto threshold, or 5% of GPDT supply.
      vetoThresholdNumerator: 10, // 10% of GPDT supply at the proposal snapshot.
      admin: DAO_TIMELOCK,
      acknowledgeBlockNumberFallback: false // The token explicitly reports a block-number clock.
    });
  }
}
