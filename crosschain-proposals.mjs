import { writeFileSync } from "node:fs";

const API_URL = "https://api.tally.xyz/query";
const API_KEY = process.env.TALLY_API_KEY;
const ORGANIZATION_ID = "2206072050458560433";
const PRIMARY_CHAIN = "eip155:1";
const PAGE_LIMIT = 10;
const EXPECTED_TOTAL = 453;
const SORT = { sortBy: "id", isDescending: true };

const RATE_LIMIT_DELAY_MS = 1500;

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
            chainId
            executableCalls {
              chainId
              target
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
  const targetMap = new Map(); // target -> Set(chainIds)
  let cursor = null;
  let fetched = 0;

  while (true) {
    console.log(`Proposals Fetched Count: ${allProposalIds.length}`);
    const { nodes, pageInfo } = await fetchProposals(cursor);

    nodes.forEach((proposal) => {
      allProposalIds.push(proposal.id);

      const calls = proposal.executableCalls || [];

      calls.forEach((call) => {
        if (!call?.target) return;
        const normalizedTarget = call.target.toLowerCase();
        const entry = targetMap.get(normalizedTarget) || new Set();
        if (call.chainId) entry.add(call.chainId);
        targetMap.set(normalizedTarget, entry);
      });

      const nonMainnetCalls = calls.filter(
        (call) => call.chainId && call.chainId !== PRIMARY_CHAIN,
      );

    //   console.log(`Check the executable calls chain ids: ${proposal.executableCalls.map((call) => call.chainId).join(", ")}`);

      if (nonMainnetCalls.length > 0) {
        const record = {
          id: proposal.id,
          primaryChain: proposal.chainId,
          crosschainCalls: nonMainnetCalls,
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

  writeFileSync("crosschain-proposals.json", JSON.stringify(crossChain, null, 2));
  const targetsPayload = Array.from(targetMap.entries()).map(([target, chainIds]) => ({
    target,
    chainIds: Array.from(chainIds),
  }));
  writeFileSync("executable-call-targets.json", JSON.stringify(targetsPayload, null, 2));

  console.log(`Fetched ${fetched} proposals. IDs:`);
//   console.log(allProposalIds.join(", "));
  console.log(
    `Saved ${crossChain.length} cross-chain proposals to crosschain-proposals.json`,
  );
  console.log(
    `Saved ${targetsPayload.length} unique executable call targets to executable-call-targets.json`,
  );
}

findCrossChainProposals().catch((err) => {
  console.error("Error fetching proposals:", err);
  process.exit(1);
});

