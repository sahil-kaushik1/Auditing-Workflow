---
name: access-control-patterns
description: >
  Role/permission analysis: admin keys, timelocks, governance, privilege
  escalation. Used during threat modeling to define attacker capabilities.
---

# Access Control Patterns Skill

## Purpose

Catalog who can do what in the protocol. This directly feeds the "Attacker Capabilities"
field of every audit task — the Threat Modeler needs to know what an attacker can and
cannot call.

## When to Use

- During threat modeling to define attacker capabilities
- During decomposition (permission-flow dimension)
- When assessing admin/governance risk

## Extraction Protocol

### Step 1: Identify Access Control Mechanisms

```bash
# OpenZeppelin Ownable
grep -rn "onlyOwner\|Ownable" --include="*.sol"

# OpenZeppelin AccessControl (roles)
grep -rn "onlyRole\|AccessControl\|ADMIN_ROLE\|MINTER_ROLE" --include="*.sol"

# Custom modifiers
grep -rn "modifier " --include="*.sol"

# Timelock patterns
grep -rn "timelock\|TimelockController\|delay\|queueTransaction" --include="*.sol"

# Multi-sig patterns
grep -rn "multisig\|MultiSig\|threshold\|confirmTransaction" --include="*.sol"
```

### Step 2: Build Permission Matrix

| Function | Contract | Access | Controller | Risk Level |
|----------|----------|--------|------------|------------|
| `setFee()` | Vault.sol | onlyOwner | EOA | High (single point of failure) |
| `pause()` | Vault.sol | onlyRole(PAUSER) | Multi-sig | Medium |
| `mint()` | Token.sol | onlyRole(MINTER) | Vault contract | Low |
| `withdraw()` | Vault.sol | public | Any user | N/A (user function) |

### Step 3: Identify Risk Patterns

| Risk Pattern | Description |
|-------------|-------------|
| **Single EOA admin** | One address controls critical functions |
| **No timelock** | Admin changes take effect immediately |
| **Privilege escalation** | Can a role grant itself more permissions? |
| **Unrenounceable ownership** | Owner cannot be removed (intentional or bug?) |
| **Backdoor functions** | Admin-only functions that can drain funds |
| **Proxy admin overlap** | Proxy admin can change implementation at will |

### Step 4: Attacker Capability Matrix

For the Threat Modeler, produce:

```markdown
## Attacker Capability Levels

### Level 1: External User (no special permissions)
Can call: [list of public/external functions]
Cannot call: [list of restricted functions]

### Level 2: Privileged Role (e.g., keeper, operator)
Can call: [Level 1 + role-specific functions]
Special powers: [e.g., can trigger liquidations, update prices]

### Level 3: Admin / Owner
Can call: [everything]
Critical powers: [e.g., change fees, pause, upgrade, set oracle]

### Level 4: Compromised Admin (worst case)
What damage can a malicious admin do?
[e.g., drain all funds, change oracle to attacker-controlled contract]
```

## Output

Save to: `specs/decomposition/permission-flow-decomposition.md`
