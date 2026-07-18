# Pattern: Permission Flow Decomposition

## Purpose
Map how authority is granted, delegated, used, and revoked in the protocol.

## Protocol

### 1. Identify All Roles
- Owner / Admin
- Operators / Keepers
- Governance (multisig, DAO)
- Users (general public)

### 2. Map Permission Lifecycle
- **Grant**: How is a role assigned? (constructor, governance vote, admin call)
- **Delegate**: Can a role delegate its powers? (approve, setOperator)
- **Use**: What can the role do? (parameter changes, emergency actions, fund moves)
- **Revoke**: How is a role removed? (renounce, timelock, governance)

### 3. Risk Assessment
- Single point of failure (one EOA controls everything)
- Missing timelock on critical parameter changes
- Privilege escalation paths (can a lower role become a higher role?)
- Irrevocable permissions (roles that can never be removed)
