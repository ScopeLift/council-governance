import { writeFileSync, mkdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createPublicClient, http, isAddress } from "viem";
import dotenv from "dotenv";
import {
  KNOWN_CROSSCHAIN_TARGETS,
  DEFAULT_PRIMARY_CHAIN,
  RPC_ENV_BY_CHAIN,
} from "./config.js";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const OUTPUT_DIR = path.join(__dirname, "output");
mkdirSync(OUTPUT_DIR, { recursive: true });

const API_URL = "https://api.tally.xyz/query";
const API_KEY = process.env.TALLY_API_KEY;
const ORGANIZATION_ID = "2206072050458560433";
const PRIMARY_CHAIN = DEFAULT_PRIMARY_CHAIN;
const PAGE_LIMIT = 10;
const EXPECTED_TOTAL = 453;
const SORT = { sortBy: "id", isDescending: true };

const RATE_LIMIT_DELAY_MS = 1500;

const bridgeTargetMap = new Map();
KNOWN_CROSSCHAIN_TARGETS.forEach((entry) => {
  if (!entry?.address) return;
  bridgeTargetMap.set(entry.address.toLowerCase(), entry);
});

const chainClients = new Map();

function getClient(chainId) {
  const envVar = RPC_ENV_BY_CHAIN[chainId];
  if (!envVar) {
    console.warn(`No RPC env configured for chainId ${chainId}. Skipping lookups.`);
    return null;
  }
  const rpcUrl = process.env[envVar];
  if (!rpcUrl) {
    console.warn(`Missing RPC URL env ${envVar} for chainId ${chainId}. Skipping lookups.`);
    return null;
  }
  if (chainClients.has(chainId)) return chainClients.get(chainId);

  const client = createPublicClient({ transport: http(rpcUrl) });
  chainClients.set(chainId, client);
  return client;
}

async function detectContractTargets(targetsPayload) {
  const results = [];
  const cache = new Map();

  for (const entry of targetsPayload) {
    const { target, chainIds, proposals } = entry;
    if (!isAddress(target)) {
      console.warn(`Skipping invalid address ${target}`);
      continue;
    }

    const chainsToCheck = chainIds?.length ? chainIds : [PRIMARY_CHAIN];
    for (const chainId of chainsToCheck) {
      const cacheKey = `${chainId}:${target.toLowerCase()}`;
      if (cache.has(cacheKey)) continue;

      const client = getClient(chainId);
      if (!client) continue;

      try {
        const code = await client.getCode({ address: target });
        cache.set(cacheKey, code);
        if (code && code !== "0x") {
          results.push({ target, chainId, code, proposals: proposals || [] });
        }
      } catch (err) {
        console.warn(`Failed getCode for ${target} on ${chainId}: ${err.message}`);
      }
    }
  }

  return results;
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function fetchProposals(afterCursor, attempt = 0) {
  const query = `
    query Proposals($after: String, $sort: ProposalsSortInput) {
      proposals(
        input: {
          filters: { organizationId: "${ORGANIZATION_ID}" }
          sort: $sort
          page: { limit: ${PAGE_LIMIT}, afterCursor: $after }
        }
      ) {
        nodes {
          ... on Proposal {
            id
            onchainId
            chainId
            executableCalls {
              chainId
              target
            }
            metadata {
              title
            }
          }
        }
        pageInfo {
          lastCursor
          count
        }
      }
    }
  `;

  const response = await fetch(API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Api-Key": API_KEY,
    },
    body: JSON.stringify({
      query,
      variables: { after: afterCursor, sort: SORT },
    }),
  });

  if (!response.ok) {
    if (response.status === 429 && attempt < 5) {
      const delay = RATE_LIMIT_DELAY_MS * (attempt + 1);
      console.warn(`Rate limited (429). Retrying in ${delay}ms...`);
      await sleep(delay);
      return fetchProposals(afterCursor, attempt + 1);
    }
    throw new Error(`HTTP ${response.status}: ${await response.text()}`);
  }

  const result = await response.json();
  if (result.errors) {
    console.error(JSON.stringify(result.errors, null, 2));
    throw new Error("GraphQL returned errors");
  }

  return result.data.proposals;
}

async function findCrossChainProposals() {
  const crossChain = [];
  const allProposalIds = [];
  const targetMap = new Map(); // target -> { chainIds: Set, proposals: Set<{id, onchainId}> }
  const summaries = [];
  let cursor = null;
  let fetched = 0;

  while (true) {
    console.log(`Proposals Fetched Count: ${allProposalIds.length}`);
    const { nodes, pageInfo } = await fetchProposals(cursor);

    nodes.forEach((proposal) => {
      allProposalIds.push(proposal.id);
      const title = proposal.metadata?.title ?? null;
      summaries.push({ 
        id: proposal.id, 
        onchainId: proposal.onchainId ?? null,
        title 
      });

      const calls = proposal.executableCalls || [];

      calls.forEach((call) => {
        if (!call?.target) return;
        const normalizedTarget = call.target.toLowerCase();
        const entry = targetMap.get(normalizedTarget) || { chainIds: new Set(), proposals: new Set() };
        if (call.chainId) entry.chainIds.add(call.chainId);
        entry.proposals.add(JSON.stringify({ id: proposal.id, onchainId: proposal.onchainId ?? null }));
        targetMap.set(normalizedTarget, entry);
      });

      const matchedBridgeCalls = calls
        .map((call) => {
          if (!call?.target) return null;
          const meta = bridgeTargetMap.get(call.target.toLowerCase());
          if (!meta) return null;
          return {
            target: call.target,
            callChainId: call.chainId,
            bridge: meta.label,
            destinationChains: meta.destinationChains,
          };
        })
        .filter(Boolean);

      if (matchedBridgeCalls.length > 0) {
        const record = {
          id: proposal.id,
          onchainId: proposal.onchainId ?? null,
          primaryChain: proposal.chainId,
          matchedBridgeCalls,
        };
        crossChain.push(record);

        console.log("Cross-chain proposal found:");
        console.log(JSON.stringify(record, null, 2));
        console.log("-------------------------------------------");
      }
    });

    fetched += nodes.length;

    if (fetched >= EXPECTED_TOTAL) break;

    const nextCursor = pageInfo.lastCursor;
    if (!nextCursor || nextCursor === cursor) break;
    cursor = nextCursor;
  }

  const writeOutput = (filename: string, data: unknown) => {
    writeFileSync(path.join(OUTPUT_DIR, filename), JSON.stringify(data, null, 2));
  };

  writeOutput("crosschain-proposals.json", crossChain);
  const targetsPayload = Array.from(targetMap.entries()).map(([target, entry]) => ({
    target,
    chainIds: Array.from(entry.chainIds),
    proposals: Array.from(entry.proposals).map((str) => JSON.parse(str)),
  }));
  writeOutput("executable-call-targets.json", targetsPayload);
  writeOutput("proposal-summary.json", summaries);

  const contractTargets = await detectContractTargets(targetsPayload);
  writeOutput("executable-call-contracts.json", contractTargets);

  console.log(`Fetched ${fetched} proposals. IDs:`);
//   console.log(allProposalIds.join(", "));
  console.log(
    `Saved ${crossChain.length} cross-chain proposals to crosschain-proposals.json`,
  );
  console.log(
    `Saved ${targetsPayload.length} unique executable call targets to executable-call-targets.json`,
  );
  console.log(
    `Saved proposal summaries to proposal-summary.json and contract targets to executable-call-contracts.json`,
  );
}

findCrossChainProposals().catch((err) => {
  console.error("Error fetching proposals:", err);
  process.exit(1);
});

