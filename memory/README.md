# Memory System — SAW Audit Harness

7-layer memory architecture for model-independent, isolated audit context.

## Layer Access Policy

| Layer | Read | Write | Cleared | Size Limit |
|-------|------|-------|---------|-----------|
| `working/` | During task | During task | After task completes | 4000 tokens |
| `run/` | During audit | During audit | After audit completes | Unlimited |
| `episodic/` | Read-only during task | After task/audit ends | Never | Unlimited |
| `semantic/` | Read-only always | Evolution Manager only | Never (versioned) | Unlimited |
| `procedural/` | Read-only always | Evolution Manager only | Never (versioned) | Unlimited |
| `negative/` | Read-only during task gen | Judge after REFUTED | Never | Unlimited |
| `evidence/` | Never (write-only) | Append-only | Never | Unlimited |

## The Core Rule

> If it is not triggered, do not read it.
> If it is not relevant, do not inject it.
> If it failed, do not globalize it.

## Layer Descriptions

### `working/` — Current Task Only
- One file per task: `TASK-{N}-working.md`
- Contains: current execution trace, working hypotheses
- **Deleted when the task completes** (verdict written to DB)
- The Reasoner reads ONLY this layer + the task file

### `run/` — Current Audit Campaign
- `current-audit.md` — task index, confirmed findings so far, budget used
- Updated by Orchestrator after each task completes
- Used by Gap Analyzer to compute coverage
- **Cleared (archived to episodic) when audit completes**

### `episodic/` — Previous Run Summaries
- One file per completed audit: `{protocol}-{date}-summary.md`
- Written by Report Compiler at audit end
- Read by Threat Modeler at START of new audit on similar protocol type
- **Trigger**: "If auditing a vault protocol, read episodic memory for past vault audits"

### `semantic/` — Stable Security Knowledge
- Maps to `patterns_library/` content (vulnerability classes, web3-native models)
- **Never modify during an audit**
- Update path: Evolution Manager proposes → regression benchmark → commit

### `procedural/` — Proven Workflow Patterns
- Sequences like "how to audit ERC4626", "how to audit a proxy upgrade"
- Maps to `patterns_library/decomposition/` and `patterns_library/business-flows/`
- **Never modify during an audit**

### `negative/` — False-Positive Patterns
- `false-positives.jsonl` — one JSON object per line
- **Mandatory check before every task generation**
- Written by Judge after every REFUTED verdict
- Also mirrored to `false_positives` table in DB

### `evidence/` — Immutable PoC Store
- Organized: `evidence/{run-id}/TASK-{N}/`
- Contains: forge output, PoC Solidity files, traces, Slither JSON
- **Append-only — never modify a past artifact**
- Content hash stored in DB `artifacts` table
