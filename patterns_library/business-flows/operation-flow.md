# Pattern: Operation Flow Analysis

## Purpose
Analyze whether a single user's complete operation (e.g., deposit → earn → withdraw)
remains correct end-to-end across multiple contracts.

## Protocol

1. Identify the main user operations (deposit, borrow, swap, stake, claim)
2. For each operation, trace the FULL path across all contracts
3. Check: does the user end up with the correct result?

## Key Questions

- Does the operation handle partial failures gracefully?
- Can the operation be front-run at any step?
- Does the operation work correctly with edge case amounts (0, 1 wei, max)?
- If the operation spans multiple transactions, can it be interrupted?
- Does the operation handle fees/slippage correctly?
