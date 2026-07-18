# Pattern: Entrypoint Decomposition

## Purpose
Catalog every point where an external actor can enter the system.

## Protocol

### 1. Enumerate All External/Public Functions

```bash
grep -rn "function.*external\|function.*public" --include="*.sol" | grep -v "view\|pure"
```

### 2. Group by Access Level

| Access Level | Functions |
|-------------|-----------|
| **Anyone** (no modifier) | `deposit()`, `withdraw()`, `swap()` |
| **Role-restricted** | `pause()`, `setFee()`, `updateOracle()` |
| **Internal-only** (called by other contracts) | `callback()`, `onFlashLoan()` |

### 3. Document for Each Entrypoint

- What state does it modify?
- What parameters does the caller control?
- What value can be sent (ETH)?
- Can it trigger external calls to untrusted addresses?
- What events does it emit?
