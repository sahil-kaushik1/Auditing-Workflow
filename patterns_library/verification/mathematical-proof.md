# Pattern: Mathematical Proof

## Purpose
Formal or semi-formal verification of invariants through mathematical reasoning
rather than testing.

## When to Use
- When an invariant is mathematical in nature (e.g., "totalSupply == sum(balances)")
- When fuzz testing hasn't found violations but you need higher confidence
- When the invariant involves abstract properties (monotonicity, conservation)

## Approach

### 1. State the Invariant Formally
```
∀ state s, ∀ transaction t:
  invariant(apply(s, t)) == true
  given invariant(s) == true
```

### 2. Case Analysis
For each function that modifies relevant state:
- Show that if the invariant holds before the call, it holds after
- Identify ALL state changes and their effect on the invariant

### 3. Boundary Analysis
- Does the proof hold at extreme values (0, type(uint256).max)?
- Does the proof hold with rounding (division truncation)?
- Does the proof hold with fee deductions?

### 4. Document Assumptions
Every mathematical proof rests on assumptions. List them all:
- "Assumes no overflow in line X" (true if Solidity ≥0.8.0)
- "Assumes oracle returns non-zero" (external dependency)
