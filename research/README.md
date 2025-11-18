## Research Scripts

1. `npm run fetch:proposals` – pulls all Compound proposals via Tally, producing `crosschain-proposals.json` and `executable-call-targets.json`
2. `npm run filter:targets` – reads `executable-call-targets.json`, checks bytecode via RPC, and writes unique contract targets to `executable-call-contracts.json`

