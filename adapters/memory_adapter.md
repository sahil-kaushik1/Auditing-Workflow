# MemoryAdapter — 7-Layer Access Policy Contract

## Core Rule

> If it is not triggered, do not read it.
> If it is not relevant, do not inject it.
> If it failed, do not globalize it — fix it locally.

## Layer Access Policy

| Layer | Read Permission | Write Permission | Cleared | Size Limit |
|-------|----------------|-----------------|---------|-----------|
| `working/` | Current task agents only | Current task agents | After task completes | 4000 tokens |
| `run/` | Any agent in current audit | Orchestrator only | After audit completes | Unlimited |
| `episodic/` | Read-only during tasks | After task/audit ends | Never (append-only) | Unlimited |
| `semantic/` | Read-only always | Evolution Manager only | Never (versioned) | Unlimited |
| `procedural/` | Read-only always | Evolution Manager only | Never (versioned) | Unlimited |
| `negative/` | Read-only during task gen | Judge after REFUTED | Never (append-only) | Unlimited |
| `evidence/` | Write-only during task | Append-only | Never (immutable) | Unlimited |

## Layer Trigger Rules

### Working Memory (`memory/working/TASK-{N}.md`)
```
Triggered by: Orchestrator when task is assigned to Deep Reasoner
Contains: task context, working hypotheses, current trace (≤4000 tokens)
Destroyed: When Orchestrator marks task complete
Rule: Reasoner reads ONLY this file + the task file. Nothing else.
```

### Run Memory (`memory/run/current-audit.md`)
```
Triggered by: Orchestrator at audit start
Updated after: Every task completes
Contains: task index, confirmed findings, budget used, coverage map
Read by: Gap Analyzer, Orchestrator (scheduling decisions)
```

### Episodic Memory (`memory/episodic/{protocol}-{date}.md`)
```
Triggered by: "auditing a {protocol_type} protocol" + past episodic exists
Read only if: similar protocol type to current audit
Contains: lessons from past audits (high-yield patterns, FP patterns, tool issues)
Written by: Report Compiler at audit end
```

### Semantic Memory (`memory/semantic/*.md`)
```
= patterns_library/ content
Triggered by: Specific pattern reference in task (e.g., "check reentrancy")
Read: The relevant pattern file only (not all of semantic memory)
Never written during an audit
```

### Procedural Memory (`memory/procedural/*.md`)
```
Triggered by: "audit ERC4626" → load procedural/erc4626-audit-sequence.md
Contains: proven step-by-step audit sequences for specific protocol types
Never written during an audit
```

### Negative Memory (`memory/negative/false-positives.jsonl`)
```
Triggered by: Before EVERY task generation (mandatory)
Access: check-negative-memory.sh script only
Written by: Judge after REFUTED verdict (append-only)
Rule: match_score > 0.8 → FLAG task for human review before generation
```

### Evidence Memory (`memory/evidence/{run-id}/TASK-{N}/`)
```
Triggered by: Verifier and SAST Integrator completing tool runs
Access: WRITE-ONLY during a task — never read back during same task
Contents: forge outputs, PoC files, Slither JSON, Echidna corpus
Immutable: SHA256 hash stored in DB. Never modify. Never delete.
```

## Anti-Patterns

```
✗ DO NOT inject all episodic memory into every task context
✗ DO NOT read semantic memory for topics not relevant to the current task
✗ DO NOT read working memory from a different task
✗ DO NOT write to evidence memory and then read it back in the same task
✗ DO NOT let the Reasoner see negative memory records (confirmation bias risk)
✗ DO NOT let the Verifier see working memory (breaks blind protocol)
```

## Isolation Guarantee

The isolation between layers is what makes cross-model convergence possible.
If the harness injects the right context and nothing more, o3 and claude-opus-4
will reason over the same bounded problem and produce comparable outputs.
Context pollution is the primary cause of model-dependent behavior.
