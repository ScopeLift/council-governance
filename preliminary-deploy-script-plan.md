# Preliminary Deploy Script Refactor Plan

## Objective

Replace the current parameterized component scripts with convention-compliant Foundry scripts that
deploy the complete council-governance system through one no-argument `run()` entrypoint.

This preliminary plan preserves the production contracts and their current clock behavior:

- The council token and council governor use timestamps.
- `BasicCouncilVetoGovernor` supports timestamp-clock ERC-5805 DAO tokens.
- `CompoundCouncilVetoGovernor` supports legacy Compound tokens using `getPriorVotes`, current
  `totalSupply`, and block numbers.

Support for block-clock ERC-5805 DAO tokens requires a production-contract change and is tracked in
[issue #89](https://github.com/ScopeLift/council-governance/issues/89). The deploy refactor should
make that later capability easy to add, but should not silently claim to support it now.

## Architecture

Use one shared full-system deployment base with two narrow veto-token adapters:

```text
DeployCouncilGovernance
├── DeployErc5805CouncilGovernance
└── DeployLegacyCompoundCouncilGovernance
```

`DeployCouncilGovernance` owns the common deployment mechanics, logging, validation, deployed
contract state, timelock role assignment, and address prediction. It defines component-specific
parameter structs and internal configuration getters:

- `CouncilTokenParams` and `_getCouncilTokenParams()`
- `TimelockParams` and `_getTimelockParams()`
- `CouncilGovernorParams` and `_getCouncilGovernorParams()`
- `VetoGovernorParams` and `_getVetoGovernorParams()`

The two adapters implement only the genuinely different behavior:

- `DeployErc5805CouncilGovernance` validates the ERC-5805 token and deploys
  `BasicCouncilVetoGovernor`. The veto governor transparently adopts the token's clock mode, so
  both timestamp-clock and block-clock ERC-5805 tokens are accepted.
- `DeployLegacyCompoundCouncilGovernance` validates `getPriorVotes` and `totalSupply`, treats veto
  timing parameters as block counts, and deploys `CompoundCouncilVetoGovernor`.

The common base exposes these public deployment outputs:

```solidity
CouncilERC20 public councilToken;
TimelockController public timelock;
BasicCouncilGovernor public councilGovernor;
BasicCouncilVetoGovernor public vetoGovernor;
```

Using `BasicCouncilVetoGovernor` as the common veto output is valid because
`CompoundCouncilVetoGovernor` inherits it. Calls dynamically dispatch to the Compound overrides.

The shared logging implementation provides public `disableLogging()` and routes all output through
internal `_log(...)` helpers.

## Concrete Configurations and Public Entrypoint

Each concrete deployment configuration inherits the appropriate adapter and implements only the
internal parameter getters. Its only deployment entrypoint is:

```solidity
function run() public override {
  DeployCouncilGovernance.run();
}
```

The base `run()` is `public virtual`, takes no arguments, returns nothing, and records outputs in
the public state variables. Broadcasting uses the account selected by the Foundry command line via
bare `vm.startBroadcast()`.

Initially add only test configurations:

- A local timestamp-clock ERC-5805 configuration using an ERC-5805 mock DAO token.
- A pinned-mainnet-fork legacy Compound configuration using COMP.

Do not create a production Sepolia or mainnet configuration until all real addresses and role
holders are known. Remove the placeholder Sepolia configuration rather than preserving a script
that appears deployable. Future production concrete scripts and their successful broadcast
artifacts must be committed as deployment records.

## Deployment Flow

Before broadcasting, load all parameter structs, validate them, build the governor constructor
structs, identify the broadcaster, and log the complete configuration.

Use two broadcast regions so address computation and other non-transaction work remain outside an
open broadcast.

### First broadcast region

1. Deploy `CouncilERC20`.
2. Mint `maxTokensPerMember` to every configured council member.
3. Deploy `TimelockController` with empty proposer and executor arrays and the broadcaster as its
   temporary admin.

After stopping the broadcast, read the broadcaster's current nonce. The council governor will be
the next deployment, so predict the veto governor at `currentNonce + 1`.

### Second broadcast region

1. Deploy `BasicCouncilGovernor` with the predicted veto-governor address.
2. Invoke the adapter hook to deploy the appropriate veto governor.
3. Grant the veto governor `PROPOSER_ROLE` on the timelock.
4. Grant the veto governor `EXECUTOR_ROLE` on the timelock.
5. Renounce the broadcaster's `DEFAULT_ADMIN_ROLE`.

Do not grant `CANCELLER_ROLE`. With `N` council members, the expected transaction count is
`N + 7`.

Every state-changing call must have an immediately preceding `// BROADCAST:` annotation and a
matching log message. The member-mint loop should log each recipient and clearly state that it
produces one transaction per member.

## Validation

Perform input validation before the first broadcast and revert with descriptive script strings.

Common validation rejects:

- Empty council token name or symbol and empty governor names.
- Zero council token admin, governor admin, or DAO-token address.
- An empty council member list.
- Zero or duplicate council member addresses.
- Zero `maxTokensPerMember`.
- Zero council or veto voting period.
- Council quorum or super-quorum above 100.
- Super-quorum below quorum.
- Veto threshold numerator above 100.
- Voting-period extension threshold above 100.

Permit zero values where they can intentionally disable or relax behavior: voting delays, proposal
thresholds, timelock delay, veto guardian, veto override role, veto override duration, and voting
period extension.

Variant validation additionally checks:

- ERC-5805: `clock()` and `CLOCK_MODE()` are callable, confirming the token implements ERC-6372.
  The governor adopts the token's clock mode transparently.
- Legacy Compound: `getPriorVotes` and `totalSupply` are callable with the expected return shapes.

After deployment, validate:

- The actual veto-governor address equals the prediction.
- All token and governor constructor values match the supplied parameters.
- The council governor points to the council token and veto governor.
- The veto governor points to the council governor, DAO token, and timelock.
- The veto governor's `clock()` matches the DAO token's `clock()`. For tokens without ERC-6372,
  the veto governor must report a block-number clock via `GovernorVotes`'s fallback.
- Every initial member has the expected token balance and delegation.
- Total council-token supply equals `memberCount * maxTokensPerMember`.
- The veto governor has `PROPOSER_ROLE` and `EXECUTOR_ROLE`.
- The timelock retains its own `DEFAULT_ADMIN_ROLE`.
- The broadcaster no longer has `DEFAULT_ADMIN_ROLE`.
- The broadcaster and both governors do not have `CANCELLER_ROLE`.

## Logging and Clock Semantics

Log all configuration values before broadcasting and every deployed address afterward. Label all
timing units explicitly:

- Council token and council governor values are timestamp/second based.
- ERC-5805 veto-governor values adopt the DAO token's clock mode — timestamp/seconds or block
  number — and the log must state which mode the token reports.
- Legacy Compound veto-governor values are block counts.
- Timelock delay and execution ETA are timestamp/second based.

The legacy Compound script must print a concise warning that the council stage uses timestamps while
veto voting uses blocks. Deployment documentation should reference
[issue #88](https://github.com/ScopeLift/council-governance/issues/88) and warn integrators that the
council governor's `proposalEta()` changes meaning—and, for the Compound path, units—during the
proposal lifecycle.

## Migration from Current Scripts

Remove the component-style deployment entrypoints and duplicated configuration inheritance:

- Token deployment/minting helper.
- Timelock deployment helper.
- Basic and Compound governor/role helpers.
- Multiple-inheritance deployment configuration contracts.
- `councilMembersLength`; always use `councilMembers.length`.

Move reusable test values into test-only fixtures instead of exposing deployment configuration
getters publicly. Update contract unit tests that currently depend on deployment configuration types
to use dedicated test parameter builders.

Leave `GetWallets.s.sol` unchanged because it is a utility script, not part of system deployment.

## Test Plan

Update deployment integration tests to instantiate one concrete script, call `disableLogging()`,
invoke `run()`, and read all four deployed contracts from public state variables.

Cover:

- Complete timestamp/ERC-5805 deployment and wiring.
- Complete legacy Compound deployment against the pinned mainnet fork.
- Veto-governor address prediction.
- Council membership minting, balances, delegation, and total supply.
- Constructor parameters and cross-contract references.
- Timelock proposer, executor, and admin roles.
- Explicit absence of assigned cancellers.
- Every input-validation category.
- Acceptance of a block-clock ERC-5805 token: the veto governor adopts the token's block-number
  clock and all timing parameters are interpreted as blocks.
- Acceptance of an ERC-20Votes token without ERC-6372: the veto governor falls back to a
  block-number clock via `GovernorVotes`'s `try`/`catch` handler.
- Rejection of a token that does not implement the expected legacy Compound interface.
- Timestamp progression for the council stage and block progression for the Compound veto stage.

Once dependencies are initialized, require `forge fmt --check`, `forge build`, the complete test
suite, and `scopelint check` to pass. Before any production deployment, run without `--broadcast`
and review the generated transaction list for count, order, sender, targets, arguments, and value.
