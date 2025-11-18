import { readFileSync, writeFileSync } from "node:fs";
import { createPublicClient, http, isAddress } from "viem";
import dotenv from "dotenv";

dotenv.config();

const TARGETS_FILE = "./executable-call-targets.json";
const OUTPUT_FILE = "./executable-call-contracts.json";

/**
 * Map of chainId -> environment variable that should contain the RPC URL.
 * Extend this map as you need additional chains.
 */
const CHAIN_RPC_ENV = {
  "eip155:1": "RPC_EIP155_1",
  "eip155:42161": "RPC_EIP155_42161",
  "eip155:8453": "RPC_EIP155_8453",
};

const chainClients = new Map();

function getClient(chainId) {
  if (!CHAIN_RPC_ENV[chainId]) {
    console.warn(`No RPC env mapping configured for chainId ${chainId}, skipping.`);
    return null;
  }

  if (!process.env[CHAIN_RPC_ENV[chainId]]) {
    console.warn(
      `Missing environment variable ${CHAIN_RPC_ENV[chainId]} for chainId ${chainId}, skipping.`
    );
    return null;
  }

  if (chainClients.has(chainId)) return chainClients.get(chainId);

  const client = createPublicClient({
    transport: http(process.env[CHAIN_RPC_ENV[chainId]]),
  });
  chainClients.set(chainId, client);
  return client;
}

async function main() {
  const targets = JSON.parse(readFileSync(TARGETS_FILE, "utf-8"));
  const results = [];
  const cache = new Map(); // `${chainId}:${target}` -> code

  for (const entry of targets) {
    const { target, chainIds } = entry;
    if (!isAddress(target)) {
      console.warn(`Skipping invalid address ${target}`);
      continue;
    }

    const chainsToCheck = chainIds?.length ? chainIds : [null];
    for (const chainId of chainsToCheck) {
      if (!chainId) continue;

      const cacheKey = `${chainId}:${target.toLowerCase()}`;
      if (cache.has(cacheKey)) continue;

      const client = getClient(chainId);
      if (!client) continue;

      try {
        const code = await client.getCode({ address: target });
        cache.set(cacheKey, code);

        if (code && code !== "0x") {
          results.push({ target, chainId, code });
        }
      } catch (err) {
        console.warn(`Failed to fetch code for ${target} on ${chainId}: ${err.message}`);
      }
    }
  }

  writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
  console.log(
    `Identified ${results.length} contract targets (out of ${targets.length} total) -> ${OUTPUT_FILE}`
  );
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

