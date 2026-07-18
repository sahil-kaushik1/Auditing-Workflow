# Pattern: State Delta Check

## Purpose
Compare protocol state before and after an operation to verify invariants hold.

## Protocol

```solidity
// 1. Snapshot state BEFORE
uint256 totalAssetsBefore = vault.totalAssets();
uint256 userSharesBefore = vault.balanceOf(user);
uint256 contractBalanceBefore = token.balanceOf(address(vault));

// 2. Execute the operation
vault.withdraw(amount);

// 3. Snapshot state AFTER
uint256 totalAssetsAfter = vault.totalAssets();
uint256 userSharesAfter = vault.balanceOf(user);
uint256 contractBalanceAfter = token.balanceOf(address(vault));

// 4. Assert invariants on the DELTA
assertEq(totalAssetsBefore - totalAssetsAfter, amount, "Total assets decreased by exact amount");
assertEq(contractBalanceBefore - contractBalanceAfter, amount, "Token balance matches");
```

## When to Use
- Verifying accounting invariants (no value leak)
- Checking that operations produce expected state changes
- Detecting phantom asset creation or destruction
