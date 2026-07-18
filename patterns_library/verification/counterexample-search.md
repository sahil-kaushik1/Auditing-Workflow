# Pattern: Counterexample Search

## Purpose
Systematically search for inputs that violate an invariant using Foundry fuzzing.

## Protocol

```solidity
// Fuzz test: search for invariant violations across random inputs
function testFuzz_invariantHolds(
    uint256 depositAmount,
    uint256 withdrawAmount,
    address user
) public {
    // Bound inputs to realistic ranges
    vm.assume(user != address(0));
    depositAmount = bound(depositAmount, 1, 1e24);
    withdrawAmount = bound(withdrawAmount, 1, depositAmount);

    // Execute the path
    vm.startPrank(user);
    vault.deposit(depositAmount);
    vault.withdraw(withdrawAmount);
    vm.stopPrank();

    // Assert invariant
    assertGe(vault.totalAssets(), vault.totalLiabilities(), "Solvency invariant");
}

// Invariant test: run random sequences of operations
function invariant_solvency() public {
    assertGe(vault.totalAssets(), vault.totalLiabilities());
}
```

## Foundry Configuration

```toml
# foundry.toml
[invariant]
runs = 256
depth = 50
fail_on_revert = false
```

## When to Use
- When the Reasoner claims "no vulnerability" — fuzz to challenge that claim
- When looking for boundary-value bugs
- When the attack surface is large and manual testing is insufficient
