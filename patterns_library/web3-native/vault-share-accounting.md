---
pattern_id: vault-share-accounting
category: web3-native
title: ERC4626 Vault Share Accounting Model
cross-reference: vulnerability-classes/donation-inflation.md, vulnerability-classes/precision-rounding.md
---

# ERC4626 Vault Share Accounting Model

## Invariants All ERC4626 Vaults Must Preserve

```
1. Solvency:    totalAssets >= sum(previewRedeem(shares[i]) for all users)
2. Rounding:    previewDeposit rounds DOWN (user gets fewer shares)
               previewWithdraw rounds UP  (user burns more shares)
               previewMint rounds UP      (user pays more assets)
               previewRedeem rounds DOWN  (user gets fewer assets)
3. Non-inflation: deposit(assets) >= previewRedeem(previewDeposit(assets))
                  (depositing and immediately redeeming should not profit)
4. Monotonicity: share price non-decreasing under normal operation
```

## Key Function Analysis

```solidity
// convertToShares: assets → shares (floor division, protects protocol)
function convertToShares(uint256 assets) public view returns (uint256) {
    uint256 supply = totalSupply();
    return supply == 0
        ? assets                           // first deposit: 1 share per asset
        : assets.mulDivDown(supply, totalAssets());  // floor: ok
}

// convertToAssets: shares → assets (floor division, protects protocol)
function convertToAssets(uint256 shares) public view returns (uint256) {
    uint256 supply = totalSupply();
    return supply == 0
        ? shares
        : shares.mulDivDown(totalAssets(), supply);  // floor: ok
}
```

## Virtual Shares Protection (OZ v5)

```solidity
// _decimalsOffset() non-zero → virtual shares active
function _decimalsOffset() internal pure override returns (uint8) {
    return 3;  // 10^3 = 1000 virtual shares always present
}

// Effect: first depositor needs to donate > 1000x deposit to inflate price
// Makes first-depositor attack economically infeasible
```

## Detection Checklist

```bash
# 1. Check if ERC4626
grep -rn "ERC4626\|IERC4626\|totalAssets\|convertToShares" src/

# 2. Check virtual shares
grep -n "_decimalsOffset\|decimalsOffset" src/
# If absent or returns 0 → donation attack risk

# 3. Check rounding direction
grep -n "mulDivDown\|mulDivUp\|Math.mulDiv" src/
# Verify direction matches ERC4626 spec

# 4. Check totalAssets() implementation
grep -A5 "function totalAssets" src/
# If: return token.balanceOf(address(this)) → donation attack surface

# 5. Check for internal accounting vs raw balanceOf
grep -n "storedBalance\|_totalAssets\|internalBalance" src/
# Internal balance → better: direct token donations not reflected
```

## Common ERC4626 Vulnerabilities

| Vulnerability | Root Cause | Severity | Check |
|--------------|-----------|----------|-------|
| Share inflation (first depositor) | No virtual shares | Critical | _decimalsOffset |
| Donation via totalAssets | balanceOf in totalAssets | High | totalAssets impl |
| Wrong rounding direction | mulDivDown where mulDivUp needed | Medium | previewWithdraw |
| Missing slippage in deposit/redeem | No minShares/maxAssets param | Medium | function params |
| Yield accrual manipulation | External protocol changes totalAssets mid-tx | High | cross-contract |

## Forge Test: Invariant Checking

```solidity
// Foundry stateful invariant test for ERC4626
contract ERC4626InvariantTest is StdInvariant, Test {
    ERC4626Vault vault;
    MockERC20 token;

    function setUp() public {
        token = new MockERC20();
        vault = new ERC4626Vault(address(token));
        targetContract(address(vault));
    }

    function invariant_solvency() public {
        // Total assets >= what all depositors can redeem
        assertGe(vault.totalAssets(), vault.convertToAssets(vault.totalSupply()));
    }

    function invariant_share_price_non_negative() public {
        if (vault.totalSupply() > 0) {
            assertGt(vault.convertToAssets(1e18), 0);
        }
    }

    function invariant_deposit_redeem_not_profitable() public {
        uint256 assets = 1000e18;
        // Depositing then immediately redeeming should not profit
        vm.startPrank(address(this));
        token.mint(address(this), assets);
        token.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, address(this));
        uint256 returned = vault.redeem(shares, address(this), address(this));
        assertLe(returned, assets);  // should never get back more than deposited
        vm.stopPrank();
    }
}
```
