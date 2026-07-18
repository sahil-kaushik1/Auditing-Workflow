---
name: context-isolation
description: >
  Enforce that untriggered knowledge is not loaded and irrelevant context
  is excluded. Three types: trigger, responsibility, and per-task isolation.
---

# Context Isolation Skill

## Purpose

> "If it is not triggered, do not read it. If it is irrelevant, do not place it in
> the current context."

Splitting prompts into files is NOT real isolation if the agent still reads all of them.
This skill enforces actual isolation at three levels.

## Three Isolation Types

### 1. Trigger Isolation
Skills are loaded ONLY when their trigger condition is met.

| Skill | Trigger | When NOT to load |
|-------|---------|-----------------|
| `foundry-harness` | During verification | During decomposition |
| `defi-patterns` | During threat modeling | During verification |
| `drift-detection` | During reasoning | During decomposition |

**Rule**: If a skill's trigger condition is not met, the agent MUST NOT read it.

### 2. Responsibility Isolation
Each agent sees ONLY its role-relevant artifacts.

| Agent | Can See | Cannot See |
|-------|---------|------------|
| Deep Reasoner | Task file, context package, target code | Verifier's prior conclusions, other tasks' reasoning |
| Verifier | Task file, reasoner's CLAIM only (not chain-of-thought), target code | Reasoner's internal reasoning process |
| Judge | Both reasoner and verifier outputs | Nothing restricted |
| Decomposer | Source code, SAST facts | Previous audit findings (anchoring bias) |

**Rule**: Agents MUST NOT consume artifacts outside their responsibility boundary.

### 3. Context Isolation (Per-Task)
The Context Builder provides ONLY task-relevant context.

For a task targeting `Vault.withdraw()`:
- ✅ Include: Vault.sol, imported interfaces, ERC20 token contract
- ✅ Include: State variables listed in the task's "Relevant State"
- ❌ Exclude: Governance.sol (unless the task specifically involves governance)
- ❌ Exclude: Frontend deployment config
- ❌ Exclude: Test files from previous audits

**Rule**: Context packages MUST document what was excluded and why.

## Enforcement

The Context Builder agent is responsible for building isolation-compliant context
packages. The Judge checks that reasoning outputs don't reference excluded context
(which would indicate an isolation violation).

## Why This Matters

Without real isolation:
- One huge prompt becomes several smaller prompt fragments (same problem)
- Irrelevant context dilutes attention on the actual task
- Anchoring bias from previous findings prevents fresh analysis
- Context overload causes the model to take shortcuts (vulnerability drift)
