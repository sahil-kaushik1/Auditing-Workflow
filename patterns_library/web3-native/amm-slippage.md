---
pattern_id: amm-slippage
category: web3-native
title: AMM Slippage & Sandwich Attack Model
---

# AMM Slippage & Sandwich Attack Model

## Constant Product AMM (Uniswap V2 Style)

```
x * y = k  (invariant)

price      = y / x  (token0 price in token1 terms)
price_impact = deltaX / (x + deltaX)

# After swap of deltaX:
new_x  = x + deltaX
new_y  = k / new_x = k / (x + deltaX)
received = y - new_y = y - k/(x + deltaX)
```

## Sandwich Attack Anatomy

```
Block N mempool observation:
  Target tx: swap(amountIn=1000 USDC → ETH, amountOutMin=0.95 ETH)

Attacker front-runs:
  Step 1: buy ETH with 10,000 USDC → moves price against target
  Step 2: [target tx executes at worse price]
  Step 3: sell ETH back → price returns, attacker profits

Attacker profit = target_slippage_paid - gas_cost
```

## Slippage Vectors in Protocols

### 1. Zero or Bypassed minAmountOut

```solidity
// VULNERABLE: accepts any output amount
function rebalance() internal {
    router.swapExactTokensForTokens(
        amountIn,
        0,              // ← amountOutMin = 0
        path,
        address(this),
        block.timestamp
    );
}
```

### 2. Missing Deadline

```solidity
// VULNERABLE: no deadline, tx can sit in mempool for hours
router.swapExactTokensForTokens(
    amountIn, amountOutMin, path, to,
    type(uint256).max   // ← no deadline
);
```

### 3. On-chain slippage calculation (manipulable)

```solidity
// VULNERABLE: slippage calc reads pool state at tx execution time
uint256 price = pair.getReserves();  // ← sandwich moves this
uint256 minOut = price * amountIn * (1 - slippage);  // based on manipulated price
```

## JIT (Just-In-Time) Liquidity Attack (Uniswap V3)

```
Attacker observes: large swap incoming in fee tier pool

Step 1: Add large concentrated liquidity around current tick
Step 2: [swap executes, attacker's liquidity captures fees]
Step 3: Remove liquidity immediately after swap

Profit: fees earned - gas
Victim: other LPs whose fee share is diluted
```

## Protection Patterns

```solidity
// Right: explicit minAmountOut from user or TWAP
function swapWithProtection(
    uint256 amountIn,
    uint256 amountOutMin,  // ← user specifies
    uint256 deadline       // ← must be block.timestamp + reasonable time
) external {
    require(block.timestamp <= deadline, "expired");
    uint256 received = router.swap(..., amountOutMin, ...);
    require(received >= amountOutMin, "slippage exceeded");
}
```

## Detection

```bash
# Find swap calls
grep -n "swap\|exactInput\|exactOutput\|addLiquidity\|removeLiquidity" src/

# Check for minAmountOut = 0
grep -n ", 0," src/ | grep -i "swap\|amount"

# Check for deadline
grep -n "deadline\|block\.timestamp" src/ | grep -i "swap"

# Check for on-chain slippage calculation
grep -n "getReserves\|slot0\|observe" src/
```

## Failure Predicates

```
Sandwich attack:
  attacker profit > 0 when:
    - amountOutMin is 0 or not enforced
    - protocol executes swap in same block as setup

JIT attack:
  LPs receive fewer fees than expected when attacker adds/removes
  liquidity around single swap

Manipulation via getReserves:
  protocol.computePrice() returns manipulable value in same block as flash loan
```

## AMM-Specific Risk by Protocol Type

| Protocol | Slippage Risk | Sandwich Risk | Price Oracle Risk |
|---------|--------------|--------------|-----------------|
| Uniswap V2 | High | High | High (spot) |
| Uniswap V3 | Medium | High | Medium (TWAP available) |
| Curve | Low (stable) | Low | Low (virtual_price stable) |
| Balancer | Medium | Medium | Medium |
| Custom AMM | Unknown | Unknown | Unknown |
