// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

contract OptimisticGovernanceDeployInput {
  address public MAIN_DAO_GOVERNOR;
  IERC5805 public MAIN_DAO_TOKEN;
  address public GOVERNOR_ADMIN;
}

contract CouncilERC20DeployInput is OptimisticGovernanceDeployInput {
  string NAME;
  string SYMBOL;
  address ADMIN;
  uint256 MAX_TOKENS_PER_MEMBER;
  address[] councilMembers;
}

contract TimelockDeployInput {
  uint256 TIMELOCK_MIN_DELAY;
}

contract VetoGovernorDeployInput is OptimisticGovernanceDeployInput {
  string NAME;
  uint48 INITIAL_COUNCIL_VETO_VOTING_DELAY;
  uint32 INITIAL_COUNCIL_VETO_VOTING_PERIOD;
  uint256 INITIAL_COUNCIL_VETO_PROPOSAL_THRESHOLD;
  address VETO_OVERRIDE_ROLE;
  uint48 VETO_OVERRIDE_DURATION;
  address VETO_GUARDIAN;
}

contract CouncilGovernorDeployInput is OptimisticGovernanceDeployInput {
  uint48 INITIAL_COUNCIL_VOTING_DELAY;
  uint32 INITIAL_COUNCIL_VOTING_PERIOD;
  uint256 INITIAL_COUNCIL_PROPOSAL_THRESHOLD;
}
