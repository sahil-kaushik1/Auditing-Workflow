# Audit Agents

> 16 specialized agents for the smart contract auditing pipeline (11 original + 5 new).

## Agent Roster

| Agent | File | Stage | Category |
|-------|------|-------|----------|
| **Orchestrator** | `orchestrator.md` | All | Planning |
| **Decomposer** | `decomposer.md` | 1 — Decomposition | Planning |
| **Flow Mapper** | `flow-mapper.md` | 1.5 — Flow Compilation | Planning ✨ |
| **Threat Modeler** | `threat-modeler.md` | 2 — Task Definition | Planning |
| **Deep Reasoner** | `deep-reasoner.md` | 3 — Reasoning | Execution |
| **Hypothesis Generator** | `hypothesis-generator.md` | 3 — Reasoning (optional) | Execution |
| **SAST Integrator** | `sast-integrator.md` | 1 — Decomposition | Execution |
| **Skeptic** | `skeptic.md` | 3 — Pre-Verification | Quality ✨ |
| **Verifier** | `verifier.md` | 3 — Verification | Quality |
| **Economic Analyst** | `economic-analyst.md` | 3 — Post-Verification | Quality ✨ |
| **Judge** | `judge.md` | All Gates | Quality |
| **Context Builder** | `context-builder.md` | 1+3 | Quality |
| **Deduplicator** | `deduplicator.md` | Pre-Report | Quality ✨ |
| **Report Compiler** | `report-compiler.md` | Post-Verification | Quality |
| **Harness Critic** | `harness-critic.md` | Between Audits | Evolution ✨ |
| **Evolution Manager** | `evolution-manager.md` | Between Audits | Evolution |

✨ = new in v2

## Pipeline

```
SAST → Decompose → Flow Map → [Decomposition Gate] →
  Threat Model (19-field tasks, neg-memory check) → [Task Quality Gate] →
    Context → Reason → [Drift Gate] →
      Skeptic (8 challenges) →
        [KILLED → reject] | [SURVIVES → blind handoff] →
          Verify (blind, 10-gate) →
            Economic Analyst →
              [Evidence Gate] →
                Deduplicator →
                  Report → [HITL Review]
                    ↓ (after cycle)
                  Harness Critic → Evolution Manager
```

## Processor Registry

| Processor | Input Type | Output Type | Agent |
|-----------|-----------|-------------|-------|
| ContextAssembler | repo_path | decomposition_artifacts | Decomposer |
| FlowMapper | decomposition_artifacts | flow_slices[] | Flow Mapper |
| TaskRouter | flow_slices[] | task_queue[] | Threat Modeler |
| MemoryRetriever | task_id | context_package | Context Builder |
| Executor | task + context | reasoning_artifact | Deep Reasoner |
| Skeptic | task + hypothesis | skeptic_verdict | Skeptic |
| Verifier | task + claim | verification_artifact | Verifier |
| EconomicAnalyst | verified_finding | economic_impact | Economic Analyst |
| GapAnalyzer | run_memory | gap_report | Orchestrator |
| Deduplicator | findings[] | deduplicated_findings[] | Deduplicator |
| Reporter | confirmed_findings[] | finding_reports[] | Report Compiler |
| Critic | cycle_artifacts | harness_critique | Harness Critic |

## Key Rules

1. **Verifier ≠ Reasoner** — Blind protocol: Verifier never sees Reasoner's CoT
2. **Skeptic runs before Verifier** — Kills weak leads before spending tool budget
3. **Judge is non-collapsible** — Cannot be merged into another role
4. **Hypothesis Generator is optional** — Only in Discovery/Contest-Rush modes
5. **Harness Critic ≠ Evolution Manager** — Critic identifies, Manager proposes+tests fixes
6. **Negative memory checked before every task** — Not optional, not skippable


## Agent Roles

| Agent | File | Stage | Category |
|-------|------|-------|----------|
| **Orchestrator** | `orchestrator.md` | All | Planning |
| **Decomposer** | `decomposer.md` | 1 — Decomposition | Planning |
| **Threat Modeler** | `threat-modeler.md` | 2 — Task Definition | Planning |
| **Deep Reasoner** | `deep-reasoner.md` | 3 — Reasoning | Execution |
| **Hypothesis Generator** | `hypothesis-generator.md` | 3 — Reasoning (optional) | Execution |
| **SAST Integrator** | `sast-integrator.md` | 1 — Decomposition | Execution |
| **Verifier** | `verifier.md` | 3 — Verification | Quality |
| **Judge** | `judge.md` | All Gates | Quality |
| **Context Builder** | `context-builder.md` | 1+3 | Quality |
| **Report Compiler** | `report-compiler.md` | Post-Verification | Quality |
| **Evolution Manager** | `evolution-manager.md` | Between Audits | Evolution |

## Pipeline

```
SAST → Decompose → [Decomposition Gate] →
  Threat Model → [Task Quality Gate] →
    Context → Reason → [Drift Gate] →
      Verify → [Evidence Gate] →
        Report → [HITL Review]
```

## Key Rules

1. **Verifier ≠ Reasoner** — They never share context
2. **Judge is non-collapsible** — Cannot be merged into another role
3. **Hypothesis Generator is optional** — Only in Discovery/Contest-Rush modes
