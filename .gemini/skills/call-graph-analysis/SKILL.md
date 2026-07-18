---
name: call-graph-analysis
description: >
  Build and query function call relationships. Used during SAST phase
  to map how functions connect across contracts.
---

# Call Graph Analysis Skill

## Purpose

Map every function-to-function call relationship in the project. This feeds the Decomposer
(entrypoint and data-flow dimensions) and the Threat Modeler (execution path construction).

## When to Use

- During SAST phase (SAST Integrator agent)
- When constructing execution paths for tasks
- When looking for indirect attack surfaces (A calls B calls C)

## Extraction Protocol

### Automated Extraction (Slither)

```bash
# Full call graph
slither . --print call-graph 2>/dev/null

# Function summary (shows calls per function)
slither . --print function-summary 2>/dev/null
```

### Manual Extraction (when Slither fails)

```bash
# Internal calls (this.func or func())
grep -rn "\..*(" --include="*.sol" | grep -v "//\|require\|emit\|event\|import"

# External calls to known contracts
grep -rn "I[A-Z].*\.\|[a-z]Contract\.\|[a-z]Token\." --include="*.sol"

# Delegatecall usage (critical for proxy patterns)
grep -rn "delegatecall\|DELEGATECALL" --include="*.sol"
```

## Output Format

```markdown
# Call Graph

## External Entry Points → Internal Calls

| Entry Point | Contract | Calls | External Calls |
|-------------|----------|-------|----------------|
| deposit() | Vault.sol | _mint(), _updateAccounting() | token.transferFrom() |

## Critical Call Chains (depth > 2)
[Chains where an external entry leads through 3+ function calls]

## Cross-Contract Call Map
[Which contracts call which other contracts, and through what functions]
```

Save to: `specs/sast/call-graph.md`
