---
pattern_id: oracle-dependency
category: web3-native
title: Oracle Dependency & Manipulation Graph
---

# Oracle Dependency & Manipulation Graph

## Oracle Types and Risk Profiles

| Type | Manipulation Window | Cost | Used For |
|------|-------------------|------|---------|
| Chainlink spot | Low (requires validator collusion) | Very High | Collateral pricing |
| Chainlink TWAP | Minimal | Extreme | Best for high-value |
| Uniswap V3 TWAP | Depends on duration | Moderate–High | DeFi pricing |
| Uniswap V2 spot (getReserves) | 1 block (flash loan) | Zero | DANGEROUS |
| Curve virtual_price | Mid-tx (read-only reentrancy) | Zero | Use with care |
| Balancer pool price | 1 block (flash loan) | Zero | DANGEROUS |
| Custom/admin oracle | Any time | Zero (admin) | DANGEROUS |

## Critical Checks

### 1. Staleness Check (Chainlink)

```solidity
// WRONG: no staleness check
(, int256 price, , , ) = priceFeed.latestRoundData();

// RIGHT:
(uint80 roundId, int256 price, , uint256 updatedAt, uint80 answeredInRound)
    = priceFeed.latestRoundData();
require(answeredInRound >= roundId, "stale round");
require(updatedAt >= block.timestamp - MAX_STALENESS, "price stale");
require(price > 0, "invalid price");
```

```bash
grep -n "latestRoundData\|latestAnswer" src/
# For each: check updatedAt comparison present
```

### 2. L2 Sequencer Uptime (Arbitrum/Optimism)

```solidity
// Required on L2: check sequencer is live before using Chainlink
address constant SEQUENCER_UPTIME_FEED = 0x...; // Chainlink L2 feed

function _checkSequencer() internal view {
    (, int256 answer, uint256 startedAt, , ) =
        AggregatorV2V3Interface(SEQUENCER_UPTIME_FEED).latestRoundData();
    require(answer == 0, "sequencer offline");
    // Grace period after restart
    require(block.timestamp - startedAt > GRACE_PERIOD, "sequencer just restarted");
}
```

### 3. Spot Price From AMM (Flash Loan Attack)

```solidity
// DANGEROUS: spot price from Uniswap V2 — manipulable in 1 block
(uint112 reserve0, uint112 reserve1,) = pair.getReserves();
uint256 price = reserve1 * 1e18 / reserve0;  // ← attackable via flash loan

// SAFER: Uniswap V3 TWAP over 30+ minutes
(int56[] memory tickCumulatives, ) = pool.observe([1800, 0]);
int24 avgTick = int24((tickCumulatives[1] - tickCumulatives[0]) / 1800);
uint256 price = TickMath.getSqrtRatioAtTick(avgTick);
```

### 4. Curve virtual_price — Read-Only Reentrancy

```solidity
// Dangerous if called from a reentrancy entry point:
uint256 price = ICurvePool(curvePool).get_virtual_price();
// If curvePool is mid-execution, this returns stale price

// Check if Curve pool exposes reentrancy lock:
// Some pools: pool.withdraw_admin_fees() reverts if reentrancy lock is set
// Use this as a reentrancy check before reading virtual_price
```

## Oracle Dependency Graph Template

For each oracle the protocol reads, document:

```
Oracle: {name}
  Contract: {address}
  Read by: {ContractName.function}
  Used for: collateral pricing | liquidation trigger | swap pricing
  Staleness check: YES / NO
  TWAP duration: N/A | 30min | 60min
  Manipulation cost estimate: $X
  Reentrancy risk: LOW / MEDIUM / HIGH
  Notes: {any special considerations}
```

## Failure Predicates by Oracle Type

```
Chainlink (no staleness): price used after oracle stops updating →
  collateral overvalued → undercollateralized borrows pass

AMM spot price: flash loan moves price P% in same block →
  protocol executes at manipulated price →
  attacker profit = P% × affected_value

Curve virtual_price (read-only reentrancy): read during Curve withdrawal →
  stale price used for collateral valuation →
  borrower takes out loan against inflated collateral
```
