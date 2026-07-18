# Pattern: Asset Lifecycle Flow

## Purpose
Verify that assets preserve quantity, value, and ownership throughout their lifecycle
across multiple contracts.

## Key Checks

1. **Quantity conservation**: tokens_in == tokens_out (accounting for fees)
2. **Value conservation**: value_at_deposit ≈ value_at_withdrawal (accounting for yield/loss)
3. **Ownership integrity**: only the rightful owner can move/claim the asset
4. **No phantom assets**: assets can't be created from nothing
5. **No trapped assets**: assets can always be retrieved (no permanent lock)

## Task Generation

For each asset type, create tasks that test the full lifecycle:
- Deposit → wait → withdraw (happy path)
- Deposit → protocol state change → withdraw (edge case)
- Deposit → emergency shutdown → withdraw (failure mode)
