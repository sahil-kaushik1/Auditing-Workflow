# Benchmark: ETH Reentrancy

## Vulnerability
Classic reentrancy: ETH is sent before `balances[msg.sender]` is decremented.

## Attack Path
1. Attacker deposits 1 ETH
2. Attacker calls `withdraw(1 ether)`
3. During the ETH transfer, attacker's `receive()` calls `withdraw(1 ether)` again
4. Balance check passes (still 1 ETH in state)
5. Second ETH transfer succeeds
6. Attacker drains entire contract

## Expected Finding
- **Severity**: Critical
- **Root cause**: Violation of Checks-Effects-Interactions (CEI) in `withdraw()`

## Fix
Move `balances[msg.sender] -= amount` BEFORE the `call{value: amount}`.
Or add `nonReentrant` modifier.
