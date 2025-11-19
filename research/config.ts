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
    address: "0x72ce9c846789fdb6fc1f34ac4ad25dd9ef7031ef",
    label: "Arbitrum L1 ERC20 Gateway",
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
  {
    address: "0x99c9fc46f92e8a1c0dec1b1747d010903e884be1",
    label: "Optimism Portal (L1 Standard Bridge)",
    destinationChains: ["eip155:10"],
  },
  {
    address: "0xa0c68c638235ee32657e8f720a23cec1bfc77c77",
    label: "Optimism L1 CrossDomainMessenger",
    destinationChains: ["eip155:10"],
  },
  {
    address: "0x3154cf16ccdb4c6d922629664174b904d80f2c35",
    label: "Base L1 Standard Bridge (Proxy)",
    destinationChains: ["eip155:8453"],
  },
  {
    address: "0xd19d4b5d358258f05d7b411e21a1460d11b0876f",
    label: "Linea L1 Message Service",
    destinationChains: ["eip155:59144"],
  },
  {
    address: "0x051f1d88f0af5763fb888ec4378b4d8b29ea3319",
    label: "Linea L1 Token Bridge",
    destinationChains: ["eip155:59144"],
  },
  {
    address: "0x6774bcbd5cecef1336b5300fb5186a12ddd8b367",
    label: "Scroll L1 Messenger Proxy",
    destinationChains: ["eip155:534352"],
  },
  {
    address: "0xf1af3b23de0a5ca3cab7261cb0061c0d779a5c7b",
    label: "Scroll L1 USDC Gateway",
    destinationChains: ["eip155:534352"],
  },
  {
    address: "0x95fc37a27a2f68e3a647cdc081f0a89bb47c3012",
    label: "Mantle L1 Standard Bridge",
    destinationChains: ["eip155:5000"],
  },
  {
    address: "0x64192819ac13ef72bf6b5ae239ac672b43a9af08",
    label: "Ronin Bridge V2",
    destinationChains: ["eip155:2020"],
  },
  {
    address: "0x81014f44b0a345033bb2b3b21c7a1a308b35feea",
    label: "Unichain L1 Standard Bridge",
    destinationChains: ["eip155:130"],
  },
];

export const DEFAULT_PRIMARY_CHAIN = "eip155:1";

export const RPC_ENV_BY_CHAIN = {
  "eip155:1": "RPC_EIP155_1",
  "eip155:42161": "RPC_EIP155_42161",
  "eip155:8453": "RPC_EIP155_8453",
  "eip155:10": "RPC_EIP155_10",
};

