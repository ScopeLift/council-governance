// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract GovernanceTestFixture {
  // Address that controls council membership
  address public constant MAIN_DAO_GOVERNOR = 0x309a862bbC1A00e45506cB8A802D1ff10004c8C0;
  // DAO token used by the veto governor for vote weight (placeholder)
  address public constant MAIN_DAO_TOKEN = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
  // Admin account allowed to adjust governor settings (placeholder)
  address public constant GOVERNOR_ADMIN = MAIN_DAO_GOVERNOR;

  // Council token name
  string public constant COUNCIL_TOKEN_NAME = "Optimistic Council";
  // Council token symbol
  string public constant COUNCIL_TOKEN_SYMBOL = "OC";
  // Council token admin
  address public constant COUNCIL_TOKEN_ADMIN = MAIN_DAO_GOVERNOR;
  // Max tokens per council member needed to create a proposal
  // NOTE: Quorum and super-quorum use integer math over total supply. If each member holds a very
  // small balance (e.g., 1 unit), rounding can reduce effective thresholds. Consider minting
  // per‑member balances in multiples of the quorum denominator (e.g., 100 units when the
  // denominator is 100), or minting per‑member balances with, say, 18 decimals (i.e. 1e18 = 1
  // vote).
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
  // Veto governor voting period extension duration
  uint48 public constant VOTING_PERIOD_EXTENSION = 3 days;
  // Veto governor voting period extension threshold in percent
  uint16 public constant VOTING_PERIOD_EXTENSION_THRESHOLD_PCT = 50;
  // Veto governor veto threshold in fraction
  uint256 public constant VETO_GOVERNOR_INITIAL_VETO_THRESHOLD_FRACTION = 10;
  // Veto governor veto guardian
  address public VETO_GUARDIAN;

  // Compound veto governor name (COMP-style `getPriorVotes`)
  string public constant COMPOUND_VETO_GOVERNOR_NAME = "CompoundCouncilVetoGovernor";
  // Compound veto governor voting delay (in blocks)
  uint48 public constant COMPOUND_VETO_GOVERNOR_INITIAL_VOTING_DELAY = 300;
  // Compound veto governor voting period (in blocks)
  uint32 public constant COMPOUND_VETO_GOVERNOR_INITIAL_VOTING_PERIOD = 7200;
  // Compound veto governor override duration (in blocks)
  uint48 public constant COMPOUND_VETO_OVERRIDE_DURATION = 28_800; // 4 days * 24 * 60 * 60 / 12
  // second blocks
  // Compound veto governor voting period extension duration (in blocks)
  uint48 public constant COMPOUND_VOTING_PERIOD_EXTENSION = 21_600; // 3 days * 24 * 60 * 60 / 12
  // second blocks

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
