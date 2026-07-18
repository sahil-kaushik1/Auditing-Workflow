# Pattern: Module Decomposition

## Purpose
Identify what each contract, library, and interface does, and map the trust
boundaries between components.

## Protocol

### 1. Catalog All Contracts

```bash
find . -name "*.sol" -not -path "*/test/*" -not -path "*/node_modules/*" | sort
```

### 2. Classify Each Contract

| Contract | Type | Purpose | Trust Level |
|----------|------|---------|-------------|
| Vault.sol | Core | Asset custody, share minting | Highest — holds user funds |
| Oracle.sol | Peripheral | Price feed | Semi-trusted — relies on external data |
| Router.sol | Entry | User interaction routing | Untrusted — processes user input |

### 3. Map Dependencies

Which contracts import which? Which depend on which for correctness?

```bash
grep -rn "import " --include="*.sol" | grep -v "test\|node_modules"
```

### 4. Identify Trust Boundaries

A trust boundary exists where:
- An untrusted contract calls a trusted one (user → vault)
- A trusted contract calls an external one (vault → oracle)
- Data crosses from user-controlled to protocol-controlled
