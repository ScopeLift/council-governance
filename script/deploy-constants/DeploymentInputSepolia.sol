// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Script Dependencies
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

contract DeploymentInputSepolia {
  // Address that controls council membership
  address public constant MAIN_DAO_GOVERNOR = 0x1111111111111111111111111111111111111111;
  // DAO token used by the veto governor for vote weight (placeholder)
  IERC5805 public constant MAIN_DAO_TOKEN = IERC5805(0x2222222222222222222222222222222222222222);
  // Admin account allowed to adjust governor settings (placeholder)
  address public constant GOVERNOR_ADMIN = MAIN_DAO_GOVERNOR;

  // Council token name
  string public constant COUNCIL_TOKEN_NAME = "Optimistic Council";
  // Council token symbol
  string public constant COUNCIL_TOKEN_SYMBOL = "OC";
  // Council token admin
  address public constant COUNCIL_TOKEN_ADMIN = MAIN_DAO_GOVERNOR;
  // Max tokens per council member needed to create a proposal
  uint256 public constant MAX_TOKENS_PER_MEMBER = 1;
  // Initial council membership roster used in scripts/tests
  address[] public COUNCIL_MEMBERS = [
    0x9848A0c9412caCA9DfdCDC2e543b681462F49de9,
    0x4882C0AD0E4999c1616B9E55292726bBE82c36a0,
    0x14440b5eA01380DD3276a7E1157266fEadf7a6Ab,
    0xb11D758A95f1070aAf6d65E81d86190ac3595E6d,
    0xdDe3FaEC9Dd75753f9411511140cD0a169568037,
    0xb7D72a7bB319E33804A28135b5f271F16Dc55917,
    0xCAb91b447839E9598f4Cf73baEB475D8d9De1aC5
  ];

  function COUNCIL_MEMBERS_LENGTH() public view returns (uint256) {
    return COUNCIL_MEMBERS.length;
  }

  // Delay enforced by the veto-governor timelock before execution
  uint256 public constant TIMELOCK_MIN_DELAY = 1 days;

  // Veto governor name
  string public constant VETO_GOVERNOR_NAME = "BasicCouncilVetoGovernor";
  // Veto governor voting delay
  uint48 public constant VETO_GOVERNOR_INITIAL_VOTING_DELAY = 1 hours;
  // Veto governor voting period
  uint32 public constant VETO_GOVERNOR_INITIAL_VOTING_PERIOD = 1 days;
  // Veto governor proposal threshold
  uint256 public constant VETO_GOVERNOR_INITIAL_PROPOSAL_THRESHOLD = 0;
  // Veto governor override role
  address public constant VETO_OVERRIDE_ROLE = MAIN_DAO_GOVERNOR;
  // Veto governor override duration
  uint48 public constant VETO_OVERRIDE_DURATION = 4 days;
  // Veto governor veto guardian
  address public VETO_GUARDIAN;

  // Council governor name
  string public constant COUNCIL_GOVERNOR_NAME = "BasicCouncilGovernor";
  // Council governor voting delay
  uint48 public constant COUNCIL_GOVERNOR_INITIAL_VOTING_DELAY = 1 days;
  // Council governor voting period
  uint32 public constant COUNCIL_GOVERNOR_INITIAL_VOTING_PERIOD = 1 weeks;
  // Council governor proposal threshold
  uint256 public constant COUNCIL_GOVERNOR_INITIAL_PROPOSAL_THRESHOLD = 1;
}
