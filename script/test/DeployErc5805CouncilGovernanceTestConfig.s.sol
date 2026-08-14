// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
  ERC20VotesTimestampMock
} from "@openzeppelin/contracts/mocks/token/ERC20VotesTimestampMock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import {DeployCouncilGovernanceBase} from "script/DeployCouncilGovernanceBase.s.sol";
import {DeployErc5805CouncilGovernance} from "script/DeployErc5805CouncilGovernance.s.sol";

contract DeployErc5805CouncilGovernanceTestToken is ERC20VotesTimestampMock {
  constructor() ERC20("Test DAO Token", "TDAO") EIP712("Test DAO Token", "1") {}
}

contract DeployErc5805CouncilGovernanceTestConfig is DeployErc5805CouncilGovernance {
  DeployErc5805CouncilGovernanceTestToken internal immutable DAO_TOKEN;

  constructor() {
    DAO_TOKEN = new DeployErc5805CouncilGovernanceTestToken();
  }

  function run() public override {
    DeployCouncilGovernanceBase.run();
  }

  function _getCouncilTokenParams() internal pure override returns (CouncilTokenParams memory) {
    address[] memory _members = new address[](3);
    _members[0] = address(0x1001);
    _members[1] = address(0x1002);
    _members[2] = address(0x1003);
    return CouncilTokenParams({
      name: "Test Council",
      symbol: "TCOUNCIL",
      admin: address(0xA11CE),
      maxTokensPerMember: 100,
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
      name: "Test Council Governor",
      votingDelay: 1 days,
      votingPeriod: 7 days,
      proposalThreshold: 100,
      quorumNumerator: 60,
      superQuorumNumerator: 100,
      admin: DEFAULT_SENDER
    });
  }

  function _getVetoGovernorParams() internal view override returns (VetoGovernorParams memory) {
    return VetoGovernorParams({
      name: "Test Veto Governor",
      daoToken: address(DAO_TOKEN),
      votingDelay: 1 hours,
      votingPeriod: 1 days,
      proposalThreshold: 0,
      vetoGuardian: address(0),
      vetoOverrideRole: DEFAULT_SENDER,
      vetoOverrideDuration: 4 days,
      votingPeriodExtension: 3 days,
      votingPeriodExtensionThresholdPct: 50,
      vetoThresholdNumerator: 10,
      admin: DEFAULT_SENDER,
      acknowledgeBlockNumberFallback: false
    });
  }
}
