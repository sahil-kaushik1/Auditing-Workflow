# Benchmark: Safe ERC4626 with Virtual Offset (False-Positive Case)

## What This Tests
The harness must NOT flag this contract as having a share inflation vulnerability.

## Why It Is Safe
The `VIRTUAL_SHARES = 1e3` and `VIRTUAL_ASSETS = 1e3` offset makes inflation attacks
require a donation of `1e3 * initial_deposit` to manipulate the share price by even 1%.
At realistic deposit sizes, this is economically irrational.

## What the Harness Should Say
- `verdict: REFUTED` or no finding at all
- If it says anything, max severity should be `Low` (informational)

## FP Pattern Reference
This corresponds to `FP-SEED-001` in `memory/negative/false-positives.jsonl`.
