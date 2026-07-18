# Pattern: Invariant Extraction

## Purpose
Identify properties of the system that MUST hold true regardless of the sequence of actions.

## Categories of Invariants

### Accounting Invariants
- `totalSupply == sum(balanceOf(all_users))`
- `totalAssets >= totalLiabilities` (solvency)
- `sum(deposits) - sum(withdrawals) == contract.balance` (no value leak)

### Access Invariants
- "Only owner can call X"
- "Once renounced, ownership cannot be reclaimed"
- "Timelock delay cannot be bypassed"

### Ordering Invariants
- "Initialize must be called before any other function"
- "Deposit must precede withdrawal"
- "Cooldown period must pass before unstake"

### Conservation Invariants
- "Minting shares doesn't create value out of nothing"
- "Burning shares returns proportional value"
- "Fees never exceed X basis points"

## Extraction Sources

1. **Documentation** — Look for absolute statements
2. **require/assert statements** — These ARE invariant enforcement
3. **Modifier chains** — What conditions are always checked
4. **Test files** — What do existing tests assert?
5. **Economic model** — What must be true for the protocol to be solvent?

## Output Format

```markdown
| ID | Invariant | Type | Enforced By | Contracts |
|----|-----------|------|------------|-----------|
| INV-001 | totalAssets >= totalLiabilities | Accounting | settle() check | Vault, Accounting |
```
