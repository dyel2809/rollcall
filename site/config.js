// Roll Call — dashboard configuration.
//
// After the contract is deployed, replace CONTRACT_ADDRESS with the deployed
// address. Until then the page runs in "awaiting deployment" mode and does
// not make any contract calls.
window.ROLLCALL_CONFIG = {
  // TODO(after deploy): paste the Roll Call contract address here.
  CONTRACT_ADDRESS: "0xffeb7f46d8801872ed4cd6838233a7f025f953f3",

  CHAIN_ID: 56,
  RPC_URLS: [
    "https://bsc-rpc.publicnode.com",
    "https://bsc-dataseed.bnbchain.org",
    "https://bsc-dataseed1.defibit.io",
  ],
  EXPLORER: "https://bscscan.com",

  // The SPACE ID Agent ID registry on BNB Smart Chain.
  AGENT_ID_REGISTRY: "0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F",

  LEADERBOARD_SIZE: 25,
  WALL_PAGE_SIZE: 20,

  // Names verified on-chain: for each entry, the registry's
  // ownerOf(uint256(keccak256(bytes(name)))) equals the address.
  // Verified 2026-11-19 for the entry below. The page never guesses names —
  // any address not listed here (and not resolvable) is shown shortened.
  VERIFIED_NAMES: {
    "0x4ffdb6dfe02e86c0e97e36e2104717abd46d56b7": "dyel2809.ai",
  },
};

// Minimal ABI — only the view functions this page calls.
window.ROLLCALL_ABI = [
  "function totalAgents() view returns (uint256)",
  "function totalCheckInsAll() view returns (uint256)",
  "function checkInsToday() view returns (uint256)",
  "function currentDay() view returns (uint256)",
  "function topStreaks(uint256 limit) view returns (address[] addrs, uint32[] streaks, uint64[] totals)",
  "function wallPage(uint256 offset, uint256 limit) view returns (address[] signers, string[] messages, uint64[] times)",
  "function streakOf(address agent) view returns (uint32 current, uint32 longest, uint64 total, uint64 lastDay)",
];
