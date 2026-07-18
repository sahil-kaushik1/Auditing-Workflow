# GEMINI.md - System Instructions for Gemini CLI

You are working in a **multi-agent smart contract auditing environment** using a deterministic 3-stage pipeline: Decompose → Define Tasks → Reason + Verify.

## Key Principles

### Model First, Reason Second
70% of resources go to decomposition and task definition. 30% goes to reasoning.
Reasoning is deep exploration inside a limited task space, NOT unrestricted exploration.

### Pattern-First Analysis
Before analyzing any vulnerability class:
1. Check `patterns_library/vulnerability-classes/` for known patterns
2. Check `patterns_library/decomposition/` for decomposition protocols
3. Check `patterns_library/verification/` for PoC generation patterns

### Independent Verification
The Reasoner ≠ the Verifier. Claims must be independently reproduced.

## Pipeline

```
SAST Integrator → Decomposer (10 dimensions) → [Decomposition Gate]
  → Threat Modeler (9-field tasks) → [Task Quality Gate]
    → Context Builder → Deep Reasoner → [Drift Gate]
      → Verifier (Foundry PoCs) → [Evidence Gate]
        → Report Compiler → [HITL Review]
```

## Agent Roles

See `AGENTS.md` for the full 11-agent role reference.
See `.claude/agents/` for individual agent definitions.

## Key Commands

```bash
# SAST
slither . --json specs/sast/raw/slither-output.json
forge build

# Verification
forge test -vvv
forge test --match-test test_exploit -vvvv

# Storage inspection
forge inspect ContractName storage-layout
```

## Directory Structure

- `specs/decomposition/` — Stage 1 outputs
- `specs/tasks/` — Stage 2 proof obligations
- `specs/reasoning/` — Stage 3 reasoning artifacts
- `specs/verification/` — Verification evidence
- `findings/` — Confirmed findings, gap records, coverage maps
- `patterns_library/` — Audit-domain patterns (vulnerability classes, verification, etc.)
