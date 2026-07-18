# Pattern: Foundry PoC Generation

## Purpose
Produce a runnable Foundry test that proves or disproves a vulnerability hypothesis.

## Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
// Import target contracts and interfaces

contract TASK_XXX_PoC is Test {
    // --- Contract instances ---
    // TargetContract target;
    // IERC20 token;
    // address attacker = makeAddr("attacker");

    function setUp() public {
        // Option A: Fork mainnet at specific block
        // vm.createSelectFork("mainnet", blockNumber);

        // Option B: Deploy fresh
        // target = new TargetContract(params);

        // Set up attacker capabilities
        // vm.deal(attacker, 100 ether);
        // deal(address(token), attacker, 1000e18);
    }

    function test_exploit() public {
        // --- Pre-conditions ---
        // uint256 balanceBefore = token.balanceOf(address(target));

        // --- Attack sequence (from Reasoner's witness) ---
        vm.startPrank(attacker);

        // Step 1: ...
        // Step 2: ...
        // Step 3: ...

        vm.stopPrank();

        // --- Assert failure predicate ---
        // assertLt(target.totalAssets(), target.totalLiabilities(), "Invariant violated");
        // or
        // assertGt(token.balanceOf(attacker), initialBalance, "Attacker profited");
    }

    function test_invariant_holds() public {
        // Counter-test: verify the invariant HOLDS under normal conditions
        // This is important when the Reasoner claims "no vulnerability"
    }
}
```

## Best Practices

1. **Fork at a specific block** for reproducibility
2. **Use `vm.prank`** not `vm.startPrank` for single calls (cleaner)
3. **Assert the task's failure predicate**, not a generic check
4. **Log intermediate state** with `console.log` for debugging
5. **Test boundary values** in addition to the main attack path
6. **Make it self-contained** — runnable with `forge test --match-test test_exploit -vvvv`
