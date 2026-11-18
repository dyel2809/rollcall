# BscScan verification — Roll Call

Everything needed to verify the deployed contract. No constructor arguments.

## Compiler settings

| Setting | Value |
|---|---|
| Compiler | Solidity v0.8.28+commit.7893614a (the standard v0.8.28 release; this is the exact version string Sourcify accepted for the full match on 2026-11-19 — see `BSCSCAN-MANUAL.md`) |
| Language | Solidity |
| EVM version | cancun |
| Optimizer | enabled, 200 runs |
| Metadata | bytecodeHash: none, appendCBOR: false |
| License | MIT |

## Two ready-to-paste routes

1. **Standard JSON input** — `deploy/standard-json-input.json`
   Contains the single source file `src/RollCall.sol` with the exact settings above.
   Proven locally (2026-11-19): a clean-room rebuild from this input produces
   byte-identical creation and runtime bytecode to the project build.

2. **Flattened source** — `deploy/RollCall.flattened.sol`
   Paste as a single file with the settings from the table.

## Expected measurements (from the final build)

| Measurement | Value |
|---|---|
| Creation bytecode | 5,849 bytes |
| Runtime (deployed) bytecode | 5,821 bytes (limit 24,576 — OK) |
| Deployment gas (local anvil rehearsal, 2026-11-19) | 1,311,791 gas |

## Deployment cost estimate

Gas price on BNB Smart Chain is the only variable:

| Gas price assumption | Deploy cost |
|---|---|
| 0.05 gwei (observed on BSC, 2026-11-17) | ≈ 0.000066 BNB |
| 1 gwei | ≈ 0.00131 BNB |
| 3 gwei | ≈ 0.00394 BNB |
| 5 gwei (historical standard) | ≈ 0.00656 BNB |

Recommendation: have **at least 0.007 BNB** in the deploying wallet so the
deployment succeeds at any plausible gas price, with margin left over.
