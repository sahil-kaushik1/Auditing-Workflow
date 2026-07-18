# SAW Benchmark Suite

Three categories of benchmark cases for measuring harness quality.

## Categories

### `known-bugs/` — True Positive Cases
Contracts with confirmed, deliberate vulnerabilities.
The harness MUST find these. If it doesn't, it's a false negative.

| Case | Vulnerability | Expected Severity |
|------|--------------|------------------|
| `erc4626-share-inflation` | First-depositor share inflation | High |
| `reentrancy-eth` | Classic ETH reentrancy (CEI violation) | Critical |

### `false-positive-cases/` — True Negative Cases  
Contracts that are SAFE. The harness must NOT flag them.

| Case | What It Tests | Why It's Safe |
|------|--------------|---------------|
| `erc4626-with-virtual-offset` | ERC4626 donation attack | Virtual shares protect against inflation |

### `synthetic-bugs/` — Differential Cases
Clean + deliberately buggy pairs for regression testing.
(To be added.)

## Scoring

| Metric | Formula |
|--------|---------|
| True Positive Rate | `TP / (TP + FN)` — did we find real bugs? |
| True Negative Rate | `TN / (TN + FP)` — did we avoid false alarms? |
| Overall Score | `(TP + TN) / total` |

## Running

```bash
# All cases
bash scripts/run-benchmark.sh --mode fast_triage

# Specific category
bash scripts/run-benchmark.sh --category known-bugs

# Write results to DB
bash scripts/run-benchmark.sh --write-db
```

## Ground Truth is Immutable
Never edit `expected_finding.json` or `expected_verdict.json`.
The harness must evolve to match the truth, not the other way around.
