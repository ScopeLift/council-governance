// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.30;

// Script Dependencies
import {IERC5805} from "@openzeppelin/contracts/interfaces/IERC5805.sol";

contract DeploymentInputMainnetForkTest {
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
    address(bytes20("council member 0")),
    address(bytes20("council member 1")),
    address(bytes20("council member 2")),
    address(bytes20("council member 3")),
    address(bytes20("council member 4")),
    address(bytes20("council member 5")),
    address(bytes20("council member 6"))
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
  // Council governor quorum fraction (percentage)
  uint256 public constant COUNCIL_GOVERNOR_INITIAL_QUORUM_FRACTION = 60; // 60% of 7 is 4.2 -> 4
  // votes
  // Council governor super quorum fraction (percentage)
  uint256 public constant COUNCIL_GOVERNOR_INITIAL_SUPER_QUORUM_FRACTION = 100; // 100% of 7 is 7
  // votes
}
