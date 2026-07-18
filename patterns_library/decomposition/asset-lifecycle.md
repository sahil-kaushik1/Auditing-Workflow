# Pattern: Asset Lifecycle

## Purpose
Track every asset through its complete lifecycle: creation → movement → transformation → accounting → destruction.

## Protocol

For each asset type (ETH, ERC20, ERC721, shares, debt, LP tokens):

### 1. Creation
- How is the asset minted/deposited?
- Who can create it?
- What invariants hold at creation? (e.g., shares minted = deposit * rate)

### 2. Movement
- How is the asset transferred between addresses?
- Are there transfer restrictions (pausable, blacklist, whitelist)?
- Do transfers trigger callbacks (ERC-777 hooks)?

### 3. Transformation
- Can the asset be converted? (e.g., stETH → wstETH, deposit → shares)
- Is the conversion rate fixed or variable?
- Can the conversion rate be manipulated?

### 4. Accounting
- How is the asset tracked internally? (`balances` mapping, `totalSupply`)
- Is there a single source of truth or multiple? (desync risk)
- Does accounting handle rebasing tokens / fee-on-transfer tokens?

### 5. Destruction
- How is the asset burned/withdrawn?
- What invariants hold at destruction? (e.g., shares burned = withdrawal * rate)
- Can burning be front-run or sandwiched?

## Key Invariant

```
sum(all user balances) == totalSupply at all times
```

Any violation of this is a critical finding.
