# Pattern: Invariant Flow

## Purpose
Verify that system-wide properties remain true across modules when operations span
multiple contracts.

## Key Checks

1. Does a deposit in Contract A correctly update the accounting in Contract B?
2. If Contract A enforces an invariant and Contract B modifies the state A depends on,
   can B break A's invariant?
3. Are there race conditions where two contracts read the same state, both update it,
   and the final result is inconsistent?

## Example

```
Vault.deposit() → Accounting.addAssets() → Oracle.getPrice()
Invariant: Vault.totalAssets == sum(user deposits) * oracle price
Risk: If oracle price changes between Vault reading it and Accounting writing it
```
