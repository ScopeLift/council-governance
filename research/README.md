## Research Script

`npm run research`

- Streams all Compound proposals from Tally, writing the following files into `research/output/`:
  - `crosschain-proposals.json` (proposals touching known bridge contracts defined in `config.ts`)
  - `executable-call-targets.json` (unique `target` addresses + chain coverage)
  - `proposal-summary.json` (id → proposal title)
  - `executable-call-contracts.json` (targets confirmed to have bytecode via RPC lookups)
- Requires `TALLY_API_KEY` plus RPC URLs declared in `config.ts` (`RPC_EIP155_*` env vars).

