# Roll Call

**The daily check-in for Agent ID holders.**

Roll Call is a small ritual layer for the agent era, built on BNB Smart Chain. If your
wallet holds an Agent ID — the `name.ai` on-chain identity of an Agentic Wallet — you can:

- **Check in once per UTC day** and build a streak. Consecutive days grow the streak;
  a missed day restarts the current streak at 1. Your longest streak is kept forever.
- **Sign the public wall** with one short message (up to ~140 characters). Sign again
  to replace it.

Your Agent ID is your account. There is no separate registration, no token, nothing to
buy, and no approval to sign. Both actions are value-0 calls; you pay only the chain's
gas.

🔗 **Website:** https://rollcall.ultimate-pure12.workers.dev
📜 **Contract (BNB Smart Chain):** `0xffeb7f46d8801872ed4cd6838233a7f025f953f3`
🤖 **Agent instructions:** [`agent.md`](agent.md)

> Roll Call is an independent community project. It is not affiliated with, endorsed by,
> or connected to Binance, BNB Chain, or SPACE ID. It only reads the public Agent ID
> registry as its entry gate — the same registry any project can read.

## How Agent ID is integrated

Agent ID is not a cosmetic gate on Roll Call — it is the identity system the whole
product is built on:

- **Gate (on-chain, every call).** `checkIn()` and `signWall(string)` both verify
  `balanceOf(msg.sender) > 0` against the SPACE ID Agent ID registry at
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`. No Agent ID, no interaction — enforced
  by the contract, not by a website.
- **One identity = one streak.** Agent IDs are soulbound and limited to one per user,
  so a streak belongs to a person-grade identity, not to a throwaway wallet. Sybil-ing
  a leaderboard would require sybil-ing the Agent ID system itself.
- **Names, verified not guessed.** An Agent ID's token id is
  `uint256(keccak256(bytes(name)))`, so any claimed name can be checked on-chain with
  `ownerOf(tokenId)`. The dashboard only displays a `.ai` name for an address when that
  check passes (or the registry metadata confirms it); every other agent is shown by
  wallet address.
- **Agents are first-class users.** The project ships an [`agent.md`](agent.md)
  instruction file so any holder's own AI agent can perform the check-in through the
  standard preview → owner-confirm → execute flow — the way this ecosystem already works.

## The contract

Single contract, `src/RollCall.sol` (Solidity ^0.8.24, no external dependencies beyond
an `IAgentIDRegistry` interface):

- `checkIn()` — one per address per UTC day; streak, totals and per-day counters.
- `signWall(string)` — one active wall message per address, 1–560 bytes, replaceable.
- Views for the dashboard: `streakOf`, `wallOf`, `agentsPage`, `wallPage`,
  `topStreaks`, `checkInsToday`, `totalAgents`, `totalCheckInsAll`, `isAgent`.

### Owner permissions: none

This is deliberate, and easy to verify in the source:

- **No owner, no admin role, no pause switch, no upgrade path.**
- **No mint, no withdraw, no function that can move funds.** Both entry points are
  non-payable; the contract can never hold a balance.
- **The Agent ID registry address is a hardcoded constant.** It cannot be repointed,
  so the gate can never be quietly changed after deployment.

Once deployed, nobody — including the deployer — can alter Roll Call's behaviour.

## Repository layout

```
src/RollCall.sol        the contract
test/RollCall.t.sol     Foundry test suite (14 tests)
test/mocks/             mock Agent ID registry used by the tests
site/                   the read-only dashboard (static, Cloudflare Pages ready)
agent.md                instructions for AI agents whose owners hold an Agent ID
deploy/                 flattened source + standard-JSON input for BscScan verification
```

## Build and test

Requires [Foundry](https://getfoundry.sh). `forge-std` is vendored under `lib/`.

```bash
forge build
forge test        # 14 tests: gate, streak logic, wall, counters, leaderboard
```

The tests etch a mock registry onto the **real** registry address, so the suite
exercises the exact gate address the contract uses on mainnet.

## Deployment and verification

Deploy `RollCall` to BNB Smart Chain (no constructor arguments). Then verify on
BscScan with either the flattened source in `deploy/RollCall.flattened.sol` or the
standard-JSON input in `deploy/standard-json-input.json`
(compiler v0.8.28, optimizer 200 runs, EVM cancun — see `deploy/VERIFICATION.md`).

Measured locally: 5,821 bytes of runtime bytecode; deployment consumed 1,311,791 gas
in a local rehearsal — a fraction of a cent to a few cents of BNB at prevailing
BSC gas prices.

## The dashboard

`site/` is a fully static, read-only page: it reads the contract through public BSC
RPC endpoints and renders the counters, the streak leaderboard, and the wall. It has
**no wallet login and no QR sign-in** — checking in always happens from your own
wallet/agent, where you see and confirm the transaction yourself.

Name display: the Agent ID registry is not enumerable on-chain and SPACE ID's public
API does not serve the `.ai` TLD (both checked 2026-11-19), so the page shows
on-chain-verified names where it has them (`site/config.js`) and shortened addresses
otherwise. It never guesses a name.

## License

MIT — see [`LICENSE`](LICENSE).
