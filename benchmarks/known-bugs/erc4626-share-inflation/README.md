# Benchmark: ERC4626 Share Inflation

## Vulnerability
Classic first-depositor share price manipulation in a vault without virtual shares.

## Attack Path
1. Attacker calls `deposit(1)` → receives 1 share (total supply = 1, total assets = 1)
2. Attacker donates 1e18 tokens directly to vault (not via deposit)
3. `totalAssets()` = 1e18 + 1, `totalSupply()` = 1
4. `convertToShares(1e18)` = floor(1e18 * 1 / (1e18 + 1)) = 0
5. Victim calls `deposit(1e18)` → receives 0 shares → loses all funds
6. Attacker redeems 1 share → receives (1e18 + 1 + 1e18) / 1 ≈ 2e18 tokens

## Expected Finding
- **Severity**: High
- **Root cause**: No virtual shares offset in `convertToShares`

## Fix
Add virtual shares: `return (assets * (supply + 10**decimalsOffset)) / (totalAssets() + 10**decimalsOffset)`
