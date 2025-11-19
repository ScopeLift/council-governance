export const KNOWN_CROSSCHAIN_TARGETS = [
  {
    address: "0x4dbd4fc535ac27206064b68ffcf827b0a60bab3f",
    label: "Arbitrum Inbox (ArbOne)",
    destinationChains: ["eip155:42161"],
  },
  {
    address: "0xa3a7b6f88361f48403514059f1f16c8e78d60eec",
    label: "Arbitrum L1 Gateway Router",
    destinationChains: ["eip155:42161"],
  },
  {
    address: "0x289b424687b49b177c1e17c1f94d19e188d983d8",
    label: "Base L1 Standard Bridge",
    destinationChains: ["eip155:8453"],
  },
  {
    address: "0x25ace71c97b33cc4729cf772ae268934f7ab5fa1",
    label: "Optimism L1 Standard Bridge",
    destinationChains: ["eip155:10"],
  },
];

export const DEFAULT_PRIMARY_CHAIN = "eip155:1";

export const RPC_ENV_BY_CHAIN = {
  "eip155:1": "RPC_EIP155_1",
  "eip155:42161": "RPC_EIP155_42161",
  "eip155:8453": "RPC_EIP155_8453",
  "eip155:10": "RPC_EIP155_10",
};

