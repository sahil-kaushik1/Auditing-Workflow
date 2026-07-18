---
pattern_id: liquidation-state-machine
category: web3-native
title: Liquidation State Machine
---

# Liquidation State Machine

## State Transitions

```
                    ┌──────────────────────────────────────┐
                    │                                      │
              [price up]                            [price down]
                    │                                      │
         ┌──────────┴──────────┐              ┌───────────┴──────────┐
         │                     │              │                      │
    [HEALTHY]            [AT_RISK]        [LIQUIDATABLE]         [BAD_DEBT]
  HF >= 1.0 + buffer    HF 1.0–1.X       HF < 1.0             collateral < debt
                                                │
                                        [LIQUIDATION]
                                         keeper liquidates
                                         position → HEALTHY
                                         (if enough collateral)
```

## Health Factor Calculation

```solidity
healthFactor = (collateralValue × liquidationThreshold) / debtValue

// Example: Aave-style
collateralValue = sum(collateral_i × price_i × liquidationThreshold_i)
debtValue       = sum(debt_i × price_i)
healthFactor    = collateralValue / debtValue

// Liquidatable when: healthFactor < 1.0
// Protocol-specific buffer: typically 1.05 for health factor
```

## Attack Vectors on Liquidations

### 1. Oracle Manipulation → Force Liquidation
```
Attacker manipulates oracle price DOWN → victim's HF drops below 1.0
Attacker liquidates victim's position at discounted price
Attacker profit = liquidation_bonus × collateral_value
```

### 2. Liquidation Bonus Extraction
```
On large positions: liquidation_bonus can be enormous
If a single liquidator can liquidate the full position in one tx,
they extract the entire bonus immediately
```

### 3. Bad Debt via Price Gap
```
If price drops faster than liquidators can act:
  collateral_value < debt_value (bad debt)
  Liquidator gets full collateral but cannot cover full debt
  Protocol absorbs shortfall
```

### 4. Liquidation DoS (Blocked Liquidator)
```
If liquidation requires a callback from the liquidator (e.g., Uniswap flash):
  Attacker frontruns to increase their collateral slightly above threshold
  Legitimate liquidator's tx reverts (position no longer liquidatable)
  Gas griefing repeated → position never gets liquidated → bad debt
```

### 5. Self-Liquidation Profit
```
If liquidation_bonus > liquidation_cost:
  User can liquidate their own position:
  1. Create position with max collateral, max debt
  2. Wait for slight HF drop (or manipulate oracle)
  3. Self-liquidate → earn bonus on own collateral
  Profitable if: bonus × collateral > gas + opportunity cost
```

## Detection Checklist

```bash
# Liquidation entry point
grep -n "liquidate\|liquidateBorrow\|seize\|closePosition" src/

# Bonus calculation
grep -n "liquidationBonus\|LIQUIDATION_BONUS\|liquidatorDiscount" src/

# Bad debt handling
grep -n "badDebt\|deficit\|absorb\|shortfall" src/

# Self-liquidation check
grep -n "require.*msg.sender.*borrower\|require.*liquidator.*!=.*borrower" src/

# Oracle dependency in liquidation
grep -n "getPrice\|latestRoundData\|getReserves" src/
# Map: which oracle feeds which liquidation trigger
```

## Invariants to Test

```
INV-LIQ-01: A healthy position (HF >= 1.0) cannot be liquidated
INV-LIQ-02: After liquidation, the protocol's total debt should decrease or equal
INV-LIQ-03: Liquidator's profit = bonus × seized_collateral (not more)
INV-LIQ-04: Liquidated collateral <= position's collateral (no over-seize)
INV-LIQ-05: After liquidation, either HF >= 1.0 OR position is fully closed
```

## Failure Predicates by Attack

| Attack | Failure Predicate |
|--------|-----------------|
| Oracle manip liquidation | protocol.liquidate(victim) succeeds when victim_real_HF > 1.0 |
| Bad debt | sum(protocol.debt) > sum(protocol.collateral) after any operation |
| Self-liquidation profit | user ends with more assets than started after self-liquidating |
| Liquidation DoS | victim.HF < 0.9 and no liquidation possible for > N blocks |
