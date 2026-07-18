# AGENTS.md — Agent Registry & Pipeline Reference

> **Version**: v3 — Hard Loop Enforcement + Fuzzer Agent
> **Routing**: Agents read CLAUDE.md first (routing hub), then their own definition file.
> **Full routing map**: See [CLAUDE.md](CLAUDE.md)

---

## 3-Stage Pipeline

```
STAGE 1: DECOMPOSITION (60-70% budget)
  @sast-integrator → @decomposer → @flow-mapper
  Gate: Decomposition Gate (Judge)

STAGE 1.5: FLOW COMPILATION
  @flow-mapper produces FLOW-*.md slices
  Output: specs/flows/FLOW-INDEX.md ordered by economic risk score

STAGE 2: TASK DEFINITION
  @threat-modeler (reads flows + neg-memory) → 19-field tasks
  Phase Assignment Heuristics enforce ≥20% phase 4+ tasks
  Gate: Task Quality Gate (Judge + validate-outputs.sh all)

STAGE 3: REASONING + VERIFICATION (30-40% budget)
  [PARALLEL] @context-builder + @hypothesis-generator
  → [PARALLEL × N] @deep-reasoner
    → [Drift Gate] → [PARALLEL × N] @skeptic
      → [Skeptic Gate] → Blind Handoff (Orchestrator strips CoT)
        → [PARALLEL] @verifier (phase 3)
           [PARALLEL] @verifier + @fuzzer (phase 4+ tasks)
          → [Evidence Gate — 10 gates] → @economic-analyst
            → bash scripts/check-pipeline-artifacts.sh
              → bash scripts/cycle-controller.sh (exit 0=STOP / exit 1=CONTINUE)
                → if CONTINUE: bash auto-evolve.sh → LOOP
                  → @deduplicator → @report-compiler
                    → [HITL] → @harness-critic → auto-evolve.sh
                      → Orchestrator convergence confirmed → DONE
```

---

## Agent Registry

| Agent | Definition File | Exit State |
|-------|----------------|------------|
| **Orchestrator** | `.claude/agents/orchestrator.md` | "Cycle {N} complete. {X} confirmed." |
| **SAST Integrator** | `.claude/agents/sast-integrator.md` | "SAST analysis complete" |
| **Decomposer** | `.claude/agents/decomposer.md` | "Decomposition complete" |
| **Flow Mapper** | `.claude/agents/flow-mapper.md` | "Flow mapping complete. {N} flows." |
| **Threat Modeler** | `.claude/agents/threat-modeler.md` | "Tasks compiled. {N} tasks." |
| **Context Builder** | `.claude/agents/context-builder.md` | "Context package built for TASK-{N}" |
| **Deep Reasoner** | `.claude/agents/deep-reasoner.md` | "Reasoning complete for TASK-{N}" |
| **Hypothesis Generator** | `.claude/agents/hypothesis-generator.md` | "Hypotheses generated" |
| **Fuzzer** | `.claude/agents/fuzzer.md` | "Fuzzing complete for TASK-{N}. Result: {VIOLATION_FOUND\|NO_VIOLATION\|ERROR}." |
| **Skeptic** | `.claude/agents/skeptic.md` | "Skeptic verdict: SURVIVES/KILLED/WEAKENED" |
| **Verifier** | `.claude/agents/verifier.md` | "Verification complete. Verdict: {V}" |
| **Economic Analyst** | `.claude/agents/economic-analyst.md` | "Economic analysis complete" |
| **Judge** | `.claude/agents/judge.md` | "Gate {name}: PASSED/FAILED" |
| **Deduplicator** | `.claude/agents/deduplicator.md` | "Deduplication: {N} → {M} unique" |
| **Report Compiler** | `.claude/agents/report-compiler.md` | "Report compiled" |
| **Harness Critic** | `.claude/agents/harness-critic.md` | "Harness critique complete" |
| **Evolution Manager** | `.claude/agents/evolution-manager.md` | "Evolution analysis complete" |

---

## Quality Gates

| Gate | Owner File | Blocking | Checks |
|------|-----------|---------|--------|
| Decomposition Gate | `.claude/agents/judge.md` | YES | All 10 dimensions, invariants explicit, flows mapped |
| Task Quality Gate | `.claude/agents/judge.md` | YES | All 19 task fields, falsifiable predicates, neg-memory check |
| Drift Detection Gate | `.claude/agents/judge.md` | YES | Reasoner output matches task drift anchors |
| Skeptic Gate | `.claude/agents/skeptic.md` | YES | 8 challenges: scope, reachability, controllability, feasibility, economics, MEV, protection, intent |
| Evidence Gate | `.claude/agents/judge.md` | YES | 10-gate checklist (G1–G10) |
| Evolution Gate | `.claude/agents/evolution-manager.md` | YES | benchmark_after >= benchmark_before |
| HITL Final Review | Human | YES | Final authority on all findings |

### Evidence Gate — 10 Sub-Gates (G1–G10)

| Gate | Name | What It Checks |
|------|------|---------------|
| G1 | In-Scope | Contract in scope, no trusted-role dependency |
| G2 | Reachability | Entry function public, no blocking modifier |
| G3 | Controllability | Attacker controls the critical parameter |
| G4 | State Feasibility | Pre-state achievable on-chain |
| G5 | Asset Impact | Measurable token/ETH loss or protocol damage |
| G6 | No Trusted Role | Attack works without admin cooperation |
| G7 | Token Assumptions | No non-standard ERC20 behavior assumed |
| G8 | Deterministic Replay | PoC passes 3/3 consecutive forge runs |
| G9 | Counterfactual Fix | Fix applied → PoC fails |
| G10 | Severity Calibration | Immunefi matrix applied, economic model supports label |

---

## Task Structure (19 Mandatory Fields)

Template file: `specs_templates/audit_task_template.md`

| # | Field | Producer | Consumer |
|---|-------|---------|---------|
| 1 | **Target** | Threat Modeler | Deep Reasoner, Verifier |
| 2 | **Execution Path** | Threat Modeler | Deep Reasoner |
| 3 | **Relevant State** | Threat Modeler | Context Builder, Deep Reasoner |
| 4 | **Attacker Capabilities** | Threat Modeler | Skeptic, Verifier |
| 5 | **Invariant** | Threat Modeler | Deep Reasoner, Verifier |
| 6 | **Failure Predicate** | Threat Modeler | Deep Reasoner, Verifier, Judge |
| 7 | **Required Witness** | Threat Modeler | Verifier |
| 8 | **Completion Contract** | Threat Modeler | Judge |
| 9 | **Drift Anchors** | Threat Modeler | Deep Reasoner, Judge (Drift Gate) |
| 10 | **flow_id** | Flow Mapper → Threat Modeler | Orchestrator |
| 11 | **phase** | Threat Modeler | Verifier (tool selection) |
| 12 | **attacker_model** | Threat Modeler | Skeptic (G6 check) |
| 13 | **token_model** | Threat Modeler | Verifier (G7 check) |
| 14 | **out_of_scope_cases** | Threat Modeler | Judge (FP prevention) |
| 15 | **stop_rule** | Threat Modeler | Deep Reasoner (hard stop) |
| 16 | **verification_tools** | Threat Modeler | Verifier (tool selection) |
| 17 | **negative_memory_check** | Threat Modeler (via check-negative-memory.sh) | Judge (Task Quality Gate) |
| 18 | **economic_impact_estimate** | Threat Modeler | Economic Analyst |
| 19 | **budget_tokens** | Threat Modeler | Deep Reasoner (hard budget cap), Context Builder (slice size) |

---

## Scanner Modes

Configured in `audit.config.yml`. Override with `--mode` flag on `run-audit.sh`.

| Mode | Budget Split | Skeptic | Gap Cycles | Verification | Use Case |
|------|-------------|---------|-----------|-------------|---------|
| **audit_grade** | 70/30 | Yes | Yes (max 3) | Full + Foundry PoC | Production audits |
| **discovery** | 50/50 | Optional | Yes (max 2) | Lighter | Initial recon |
| **contest_rush** | 40/60 | Skip | No | Parallel | Time-constrained |
| **fast_triage** | 30/70 | Skip | No | Skip gap cycles | Quick assessment |
| **smoke_scan** | 20/80 | No | No | None (Hypothesis only) | Surface check |
| **conservative** | 60/40 | Yes | No | Full | Max precision, min FP |

**Bug Bounty Sequence**: discovery → contest_rush → fast_triage → audit_grade

---

## Finding Classification Ladder

| Level | Criteria | Who Sets It |
|-------|---------|------------|
| **Hypothesis** | Reasoner proposed, no verification | Deep Reasoner |
| **Candidate** | Verified but lacks full impact proof | Verifier |
| **Verified** | PoC passes 3/3, attack path confirmed | Verifier |
| **Confirmed** | Verified + impact assessed + severity assigned | Judge + Economic Analyst |

---

## Review Attribution (Missed Finding Analysis)

When a known vulnerability is missed, the Judge identifies which component failed:

| # | Failure Type | Root File | Fix Target |
|---|-------------|-----------|-----------|
| 1 | No task for this root cause | `specs/tasks/` | `.claude/agents/threat-modeler.md` |
| 2 | Missing failure predicate | Task file | `.agents/skills/task-compilation/SKILL.md` |
| 3 | Missing witness requirement | Task file | `.agents/skills/task-compilation/SKILL.md` |
| 4 | Relevant code not provided | `specs/context/` | `.claude/agents/context-builder.md` |
| 5 | Task + context correct, model missed it | `specs/reasoning/` | `.claude/agents/deep-reasoner.md` |
| 6 | Found but not reproduced | `specs/verification/` | `.claude/agents/verifier.md` |
| 7 | Found but not in output | `findings/` | `.claude/agents/report-compiler.md` |
| 8 | Found but lost in report | `findings/EXECUTIVE-SUMMARY.md` | `.agents/skills/audit-reporting/SKILL.md` |

---

## Skill Registry

All skills are in `.agents/skills/{name}/SKILL.md`.

| Skill | Trigger Condition | Loaded By |
|-------|------------------|-----------|
| `solidity-decomposition` | Stage 1 start | Decomposer |
| `invariant-extraction` | Stage 1 start | Decomposer |
| `state-machine-analysis` | Stage 1 start | Decomposer |
| `context-isolation` | > 10 contracts OR any Stage 3 task | Decomposer, Context Builder |
| `web3-checklist` | SAST phase | SAST Integrator |
| `call-graph-analysis` | SAST phase | SAST Integrator |
| `flow-compilation` | Flow Mapper stage | Flow Mapper, Threat Modeler |
| `negative-memory` | Before EVERY task generation | Threat Modeler |
| `task-compilation` | Stage 2 | Threat Modeler |
| `defi-patterns` | Stage 2 | Threat Modeler |
| `access-control-patterns` | Stage 2 | Threat Modeler |
| `cross-contract-analysis` | Stage 2 (multi-contract tasks) | Threat Modeler |
| `data-flow-tracking` | Stage 2 (data-flow tasks) | Threat Modeler |
| `drift-detection` | Stage 3 reasoning | Deep Reasoner |
| `blind-verification` | Pre-Verifier handoff | Orchestrator |
| `foundry-harness` | Stage 3 verification | Verifier |
| `evidence-gates` | After CONFIRMED verdict | Verifier, Judge |
| `fuzzing-integration` | task.phase = 4+ | Verifier, Fuzzer |
| `economic-modeling` | Economic Analyst stage | Economic Analyst |
| `gap-analysis` | Between cycles | Orchestrator |
| `resource-scheduling` | All cycles | Orchestrator |
| `audit-reporting` | Stage 3 report | Report Compiler |
| `cost-tracking` | After every task | All agents |
| `review-attribution` | Post-audit miss analysis | Judge |
| `evolution-tracking` | Post-cycle | Evolution Manager |

---

## Artifact Routing (Where Everything Is Written)

| Stage | Agent | Writes To |
|-------|-------|-----------|
| 1 | SAST Integrator | `specs/sast/raw/slither-output.json` |
| 1 | Decomposer | `specs/decomposition/{dimension}.md` |
| 1.5 | Flow Mapper | `specs/flows/FLOW-{N}.md`, `specs/flows/FLOW-INDEX.md` |
| 2 | Threat Modeler | `specs/tasks/TASK-{N}-{name}.md`, `specs/tasks/INDEX.md` |
| 3 | Context Builder | `specs/context/TASK-{N}-context.md` |
| 3 | Deep Reasoner | `specs/reasoning/TASK-{N}-reasoning.md` |
| 3 | Skeptic | `specs/reasoning/TASK-{N}-skeptic.md` |
| 3 | Orchestrator (Blind Handoff) | `specs/verification/TASK-{N}-claim.md` |
| 3 | Verifier | `specs/verification/TASK-{N}-verification.md` |
| 3 | Economic Analyst | `specs/verification/TASK-{N}-economic.md` |
| 3 | Judge | `specs/gates/GATE-{name}-{timestamp}.md` |
| 3 | Orchestrator | `specs/cycles/CYCLE-{N}-report.md`, `specs/cycles/GAP-ANALYSIS-{N}.md` |
| Post | Deduplicator | `findings/DEDUP-REPORT.md`, `findings/UNIQUE-FINDINGS.md` |
| Post | Report Compiler | `findings/FINDING-{ID}.md`, `findings/EXECUTIVE-SUMMARY.md` |
| Post | Harness Critic | `specs/evolution/harness-critique-latest.md` |
| Post | Evolution Manager | `specs/evolution/` |

---

## Directory Structure

```
.claude/agents/          ← 17 agent definition files (read by AI runtimes)
.agents/skills/          ← 33 skill files (loaded on-demand by agents)
adapters/                ← Provider interface contracts
audit.config.yml         ← All runtime settings (loops, parallelism, convergence)
CLAUDE.md                ← Routing hub (read first by every agent)
AGENTS.md                ← This file — agent registry and pipeline reference
GUIDE.md                 ← Human operator guide
scripts/
  run-audit.sh              ← Workspace init + one-prompt generator
  slice-context.sh          ← Per-task context slicer (remapping-aware, python3 extractor)
  auto-evolve.sh            ← Post-cycle evolution engine
  run-benchmark.sh          ← Benchmark suite runner (real TP/TN/FP/FN measurement)
  check-negative-memory.sh  ← FP pre-check before task generation
  validate-outputs.sh       ← Schema validator (all 19 task fields)
  update-dashboard.sh       ← Live dashboard regeneration from DB
  cycle-controller.sh       ← Hard loop gate (exit 0=STOP / exit 1=CONTINUE)
  check-pipeline-artifacts.sh ← Artifact health check; writes CYCLE-N-COMPLETE.txt
  check-coverage.sh         ← Pre-convergence flow coverage validator
  db-write.sh               ← Agent DB write wrapper
db/
  schema.sql             ← SQLite schema
  init.sh                ← One-time DB setup
  saw.db                 ← Runtime state (git-ignored)
memory/
  working/               ← Current task (cleared per task)
  run/                   ← Current audit
  episodic/              ← Past audit summaries
  semantic/              ← = patterns_library
  procedural/            ← Proven workflows
  negative/              ← false-positives.jsonl (FP patterns)
  evidence/              ← Immutable PoC outputs
specs/
  decomposition/         ← Stage 1 outputs
  flows/                 ← Stage 1.5 outputs
  sast/                  ← SAST outputs
  tasks/                 ← Stage 2 task files (19-field)
  context/               ← Per-task sliced context packages
  skills-loaded/          ← Per-task skill-loading evidence
  reasoning/             ← Reasoning + Skeptic artifacts
  verification/          ← claim.md + verification evidence
  gates/                 ← Judge gate decisions
  cycles/                ← Cycle reports + gap analysis
  evolution/             ← Harness Critic output
findings/
  DASHBOARD.md           ← Live dashboard (updated per task)
  FINDING-{ID}.md        ← Confirmed findings
  DEDUP-REPORT.md        ← Deduplication results
  UNIQUE-FINDINGS.md     ← Deduplicated list
  COVERAGE-MAP.md        ← What was examined
  EXECUTIVE-SUMMARY.md   ← Final report
benchmarks/
  known-bugs/            ← 5 confirmed vulnerable contracts
  synthetic-bugs/        ← 2 clean + deliberately buggy pairs
  false-positive-cases/  ← 5 safe contracts (must not be flagged)
  runner.sh              ← Benchmark execution engine
patterns_library/
  vulnerability-classes/ ← 15 vulnerability class patterns
  web3-native/           ← 5 DeFi economic model patterns
specs_templates/
  audit_task_template.md ← 19-field task template
  finding_template.md    ← Finding format
```
