---
pattern_id: erc20-model
category: web3-native
title: ERC20 Token Behavior Model
---

# ERC20 Token Behavior Model

Protocols frequently assume standard ERC20 behavior. Non-standard tokens
break assumptions silently. This model documents the deviations to check.

## Behavior Matrix

| Token Type | Transfer Tax | Rebase | Blacklist | Return Value | ERC777 Hook |
|-----------|-------------|--------|-----------|-------------|-------------|
| Standard ERC20 | No | No | No | true | No |
| Fee-on-Transfer | Yes (1-5%) | No | No | true | No |
| Rebasing (stETH) | No | Yes | No | true | No |
| USDC/USDT | No | No | Yes | varies | No |
| ERC777 | No | No | No | true | Yes |
| AMPL | No | Yes (elastic) | No | true | No |

## Fee-on-Transfer (FoT) Tokens

### What Happens

```
token.transferFrom(user, vault, 1000);
// vault actually receives 990 (1% fee deducted)
// vault.balanceOf increases by 990, not 1000
```

### Detection Pattern in Protocol Code

```solidity
// WRONG: credits full amount
function deposit(uint256 amount) external {
    token.transferFrom(msg.sender, address(this), amount);
    balances[msg.sender] += amount;  // ← credits 1000, received 990
}

// RIGHT: balance-diff check
function deposit(uint256 amount) external {
    uint256 before = token.balanceOf(address(this));
    token.transferFrom(msg.sender, address(this), amount);
    uint256 actual = token.balanceOf(address(this)) - before;
    balances[msg.sender] += actual;  // ← credits 990
}
```

### Audit Check
```bash
grep -n "transferFrom\|safeTransferFrom" src/
# For each: does the protocol credit `amount` or measure actual received balance?
```

## Rebasing Tokens (stETH, aTokens)

### What Happens

The balance of a rebasing token increases automatically over time (yield accrual).
If a protocol stores `uint256 amount` rather than `uint256 shares`, the stored
value becomes stale relative to actual balance.

```
t=0: vault.deposit(1000 stETH). Stores: position = 1000
t=1: stETH rebases. Vault holds 1010 stETH.
     Protocol still thinks position = 1000 → 10 stETH unaccounted → stuck
```

### Right Approach: Store Shares

```solidity
// Use Lido's share system instead of stETH amounts
uint256 shares = lido.getSharesByPooledEth(amount);
positions[user] = shares;

// On withdrawal:
uint256 ethAmount = lido.getPooledEthByShares(positions[user]);
```

## Missing Return Value (USDT)

USDT's `transfer()` and `approve()` do not return `bool` on some chains.
Raw ERC20 calls without SafeERC20 will revert on ABI mismatch.

```bash
# Check for raw calls
grep -n "\.transfer(\|\.approve(\|\.transferFrom(" src/ | grep -v "safe\|Safe\|IERC20"
```

Use `SafeERC20` from OpenZeppelin for all ERC20 interactions.

## Blacklist Tokens (USDC, USDT)

If a user is blacklisted, `transferTo` to that address reverts. This can:
- Cause griefing: attacker gets blacklisted, protocol cannot process their funds
- Cause DoS: if protocol iterates users and one is blacklisted, entire batch fails

```solidity
// WRONG: iterates all users, one blacklisted = DoS
function distributeRewards() external {
    for (uint i = 0; i < users.length; i++) {
        token.transfer(users[i], rewards[i]);  // ← revert if users[i] blacklisted
    }
}

// RIGHT: pull-over-push
function claimReward() external {
    uint256 reward = rewards[msg.sender];
    rewards[msg.sender] = 0;
    token.transfer(msg.sender, reward);  // ← only affects the claimer
}
```

## ERC777 Tokens (tokensReceived Hook)

ERC777 tokens call `tokensReceived()` on the recipient before completing transfer.
This is a reentrancy vector: the recipient can re-enter the sending contract.

```bash
grep -rn "ERC777\|IERC777\|tokensReceived" src/
```

If ERC777 tokens are in scope, treat every `transfer` as a potential reentrancy.
