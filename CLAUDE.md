# CLAUDE.md — Audit OS Routing Hub

> **Version**: v3 — Model-Independent Audit OS + Hard Loop Enforcement
> **Philosophy**: Model First, Reason Second, Verify Independently, Fuzz Continuously.
---

## What This Repository Is

A **deterministic, multi-agent smart contract auditing operating system**.
When an AI agent reads this file, it understands where to go, what to read, and what to do next.
All agent roles, routing, skills, and gates are defined by the files listed below.
No hard-coded model names. Works with Claude Code, Codex, or any capable model.

---
## How Routing Works

Every agent reads this file first. Then it reads its own agent definition file.
Every agent definition file ends with a **Routing** section listing:
- What input it expects and where to read it from
- What output it produces and where to write it
- What comes next (the next agent + file to read)
- Which skills to load (file paths)
- Which gate blocks it from proceeding

**The chain is self-contained. No prompt is needed beyond the agent name.**

---

## Pipeline Routing Map

```
bash scripts/run-audit.sh → sets env vars + writes specs/cycles/CURRENT-RUN-ID.txt
        ↓
@orchestrator → reads .claude/agents/orchestrator.md
        ↓ spawns in parallel:
        ├── @sast-integrator   → .claude/agents/sast-integrator.md   → specs/sast/
        └── @decomposer        → .claude/agents/decomposer.md         → specs/decomposition/
                ↓ [Decomposition Gate — Judge]
        @flow-mapper           → .claude/agents/flow-mapper.md        → specs/flows/
                ↓
        @threat-modeler        → .claude/agents/threat-modeler.md     → specs/tasks/
                ↓ [Task Quality Gate — Judge + validate-outputs.sh all]
        [PARALLEL] @context-builder  → specs/context/TASK-{N}-context.md
        [PARALLEL] @hypothesis-generator → specs/hypotheses/HYPOTHESIS-CLOUD-{N}.md
                ↓
        [PARALLEL × N] @deep-reasoner → specs/reasoning/TASK-{N}-reasoning.md
                ↓ [Drift Gate — Judge]
        [PARALLEL × N] @skeptic       → specs/reasoning/TASK-{N}-skeptic.md
                ↓ [Skeptic Gate]
        Orchestrator blind handoff    → specs/verification/TASK-{N}-claim.md
                ↓
        [PARALLEL] @verifier (phase 3) → specs/verification/TASK-{N}-verification.md
        [PARALLEL] @verifier + @fuzzer (phase 4+) → verification.md + fuzz-{tool}.md
                ↓ [Evidence Gate — Judge (10 gates)]
        @economic-analyst      → specs/verification/TASK-{N}-economic.md
                ↓
        bash scripts/check-pipeline-artifacts.sh → writes CYCLE-N-COMPLETE.txt
        bash scripts/update-dashboard.sh         → findings/DASHBOARD.md
        bash scripts/cycle-controller.sh         → exit 0=STOP / exit 1=CONTINUE
                ↓ if CONTINUE:
        bash scripts/auto-evolve.sh → apply safe improvements
        [LOOP back to @context-builder with gap-focused tasks]
                ↓ if STOP:
        bash scripts/check-coverage.sh → verify ≥80% flow coverage
                ↓
        @deduplicator          → findings/DEDUP-REPORT.md
        @report-compiler       → findings/EXECUTIVE-SUMMARY.md
        @harness-critic        → specs/evolution/harness-critique-latest.md
        bash scripts/auto-evolve.sh
                ↓
        [HITL] Human auditor reviews EXECUTIVE-SUMMARY.md
```

---

## Agent File Index

| Agent | Definition File | Input From | Output To |
|-------|----------------|------------|-----------|
| Orchestrator | `.claude/agents/orchestrator.md` | audit.config.yml, run-audit.sh | All agents via Task tool |
| SAST Integrator | `.claude/agents/sast-integrator.md` | Source contracts | `specs/sast/` |
| Decomposer | `.claude/agents/decomposer.md` | Source contracts + SAST | `specs/decomposition/` |
| Flow Mapper | `.claude/agents/flow-mapper.md` | `specs/decomposition/` | `specs/flows/` |
| Threat Modeler | `.claude/agents/threat-modeler.md` | `specs/flows/` + neg-memory | `specs/tasks/` |
| Context Builder | `.claude/agents/context-builder.md` | Task file + source | `specs/context/TASK-{N}-context.md` |
| Deep Reasoner | `.claude/agents/deep-reasoner.md` | Task + context package | `specs/reasoning/TASK-{N}-reasoning.md` |
| Hypothesis Generator | `.claude/agents/hypothesis-generator.md` | Task file | `specs/hypotheses/` |
| Fuzzer | `.claude/agents/fuzzer.md` | `TASK-{N}-claim.md` + context | `specs/verification/TASK-{N}-fuzz-{tool}.md` |
| Skeptic | `.claude/agents/skeptic.md` | Reasoning artifact | `specs/reasoning/TASK-{N}-skeptic.md` |
| Verifier | `.claude/agents/verifier.md` | `TASK-{N}-claim.md` (NOT reasoning) | `specs/verification/TASK-{N}-verification.md` |
| Economic Analyst | `.claude/agents/economic-analyst.md` | Verified finding | `specs/verification/TASK-{N}-economic.md` |
| Judge | `.claude/agents/judge.md` | All stage outputs | `specs/gates/` |
| Deduplicator | `.claude/agents/deduplicator.md` | All findings | `findings/DEDUP-REPORT.md` |
| Report Compiler | `.claude/agents/report-compiler.md` | `UNIQUE-FINDINGS.md` | `findings/EXECUTIVE-SUMMARY.md` |
| Harness Critic | `.claude/agents/harness-critic.md` | Cycle artifacts | `specs/evolution/harness-critique-latest.md` |
| Evolution Manager | `.claude/agents/evolution-manager.md` | Critique + benchmarks | `specs/evolution/` |

---

## Skill File Index

Agents load skills on demand. Skills are in `.agents/skills/{name}/SKILL.md`.

| Skill | Path | Loaded By | When |
|-------|------|-----------|------|
| solidity-decomposition | `.agents/skills/solidity-decomposition/SKILL.md` | Decomposer | Stage 1 |
| invariant-extraction | `.agents/skills/invariant-extraction/SKILL.md` | Decomposer | Stage 1 |
| state-machine-analysis | `.agents/skills/state-machine-analysis/SKILL.md` | Decomposer | Stage 1 |
| context-isolation | `.agents/skills/context-isolation/SKILL.md` | Decomposer, Context Builder | Stage 1, 3 |
| flow-compilation | `.agents/skills/flow-compilation/SKILL.md` | Flow Mapper, Threat Modeler | Stage 1.5 |
| web3-checklist | `.agents/skills/web3-checklist/SKILL.md` | SAST Integrator | Stage 1 |
| negative-memory | `.agents/skills/negative-memory/SKILL.md` | Threat Modeler | Before every task |
| task-compilation | `.agents/skills/task-compilation/SKILL.md` | Threat Modeler | Stage 2 |
| defi-patterns | `.agents/skills/defi-patterns/SKILL.md` | Threat Modeler | Stage 2 |
| access-control-patterns | `.agents/skills/access-control-patterns/SKILL.md` | Threat Modeler | Stage 2 |
| drift-detection | `.agents/skills/drift-detection/SKILL.md` | Deep Reasoner | Stage 3 |
| blind-verification | `.agents/skills/blind-verification/SKILL.md` | Orchestrator (handoff) | Pre-Verifier |
| foundry-harness | `.agents/skills/foundry-harness/SKILL.md` | Verifier | Stage 3 |
| evidence-gates | `.agents/skills/evidence-gates/SKILL.md` | Verifier, Judge | After verdict |
| fuzzing-integration | `.agents/skills/fuzzing-integration/SKILL.md` | Verifier, Fuzzer | phase 4+ tasks |
| economic-modeling | `.agents/skills/economic-modeling/SKILL.md` | Economic Analyst | Stage 3 |
| gap-analysis | `.agents/skills/gap-analysis/SKILL.md` | Orchestrator | Between cycles |
| resource-scheduling | `.agents/skills/resource-scheduling/SKILL.md` | Orchestrator | All cycles |
| audit-reporting | `.agents/skills/audit-reporting/SKILL.md` | Report Compiler | Stage 3 |
| cost-tracking | `.agents/skills/cost-tracking/SKILL.md` | All agents | After every task |
| review-attribution | `.agents/skills/review-attribution/SKILL.md` | Judge | Post-audit |
| evolution-tracking | `.agents/skills/evolution-tracking/SKILL.md` | Evolution Manager | Post-cycle |

---

## Key File Paths

| File | Purpose |
|------|---------|
| `audit.config.yml` | All runtime settings: loop count, convergence threshold, parallelism, evolution |
| `scripts/run-audit.sh` | Workspace initializer — run this before invoking @orchestrator |
| `scripts/slice-context.sh` | Per-task context slicer — Context Builder calls this for every task |
| `scripts/auto-evolve.sh` | Post-cycle evolution engine — Orchestrator calls this after every cycle |
| `scripts/run-benchmark.sh` | Benchmark suite runner — measures harness quality |
| `scripts/check-negative-memory.sh` | FP pre-check — Threat Modeler calls before every task |
| `scripts/validate-outputs.sh` | Output schema validator |
| `scripts/update-dashboard.sh` | Dashboard updater — called after every task; reads DB |
| `scripts/cycle-controller.sh` | Hard loop gate — exit 0=STOP, exit 1=CONTINUE |
| `scripts/check-pipeline-artifacts.sh` | Pre-cycle-complete artifact verifier; writes CYCLE-N-COMPLETE.txt |
| `scripts/check-coverage.sh` | Pre-convergence flow coverage check |
| `scripts/db-write.sh` | Agent DB write wrapper (task-start, task-complete, finding-add, etc.) |
| `specs/skills-loaded/` | Per-task skill-loading evidence directory |
| `db/init.sh` | One-time DB setup |
| `db/saw.db` | SQLite audit state store |
| `memory/negative/false-positives.jsonl` | FP pattern store — checked before every task generation |
| `specs/cycles/CURRENT-RUN-ID.txt` | Run ID written by run-audit.sh, read by Orchestrator |
| `specs_templates/audit_task_template.md` | 19-field task template — Threat Modeler uses this |
| `specs_templates/finding_template.md` | Finding format — Report Compiler uses this |
| `findings/DASHBOARD.md` | Live dashboard — updated after every task |

---

## Quality Gates (All Blocking)

| Gate | Owner | After Stage | Passes When |
|------|-------|-------------|-------------|
| Decomposition Gate | Judge | Stage 1 | All 10 dimensions documented |
| Task Quality Gate | Judge | Stage 2 | All 19 fields present, falsifiable predicates |
| Drift Detection Gate | Judge | Reasoning | Reasoner stayed within task boundaries |
| Skeptic Gate | Skeptic | Skeptic review | Hypothesis survives 8 challenges |
| Evidence Gate | Judge | Verification | Passes all 10 sub-gates |
| Evolution Gate | Evolution Manager | Post-cycle | Benchmark did not regress |
| HITL Final Review | Human | End of audit | Human auditor signs off |

---

## Environment Variables

Set by `scripts/run-audit.sh`. All agents may read these:

| Variable | Value |
|----------|-------|
| `SAW_RUN_ID` | Unique run identifier |
| `SAW_PROTOCOL` | Protocol name |
| `SAW_MODE` | Scanner mode |
| `SAW_PROJECT_PATH` | Absolute path to target contracts |
| `SAW_DB_PATH` | Path to saw.db |
| `RPC_URL` | RPC endpoint (optional) |

---

## Anti-Patterns (Enforced by Gates)

| Anti-Pattern | Blocked By |
|-------------|-----------|
| File-by-file reading of all contracts | Context isolation skill — use hierarchical decomposition |
| "Check for reentrancy" (vague task) | Task Quality Gate — failure predicate must be falsifiable |
| Reasoner verifies its own finding | Blind handoff protocol — Verifier only sees claim.md |
| Agent reads another agent's CoT | Responsibility isolation in context-isolation skill |
| Harness change without benchmark guard | Evolution Gate — benchmark_after >= benchmark_before required |
| Full re-scan in Cycle 2+ | Gap-driven reallocation — Orchestrator generates gap-targeted tasks only |
| Declaring convergence without script approval | cycle-controller.sh gate — only script can authorize STOP |
| All tasks assigned phase 3 | Task Quality Gate + min_phase_4_plus_ratio:0.20 enforcement |
| Artifact missing before next stage | check-pipeline-artifacts.sh blocks cycle completion |
| Fuzzer skipped for accounting tasks | Phase Assignment Heuristics in threat-modeler.md enforce phase 4+ |
