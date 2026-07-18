# GUIDE.md — SAW Audit OS v3 — Human Operator Guide

> **Audience**: Human auditors and operators who run and configure the harness.
> **For agents**: Read `CLAUDE.md` (routing hub) and `AGENTS.md` (registry) instead.
> **Version**: v3 — Hard Loop Enforcement + Fuzzer Agent + Artifact-Verified Pipeline

---

## Table of Contents

1. [What This System Does](#1-what-this-system-does)
2. [Prerequisites](#2-prerequisites)
3. [One-Time Setup](#3-one-time-setup)
4. [Configure Your Audit](#4-configure-your-audit)
5. [Run an Audit — Two Steps](#5-run-an-audit--two-steps)
6. [What Happens After You Paste the Prompt](#6-what-happens-after-you-paste-the-prompt)
7. [Monitor Progress](#7-monitor-progress)
8. [Read the Results](#8-read-the-results)
9. [Scanner Modes](#9-scanner-modes)
10. [Context Window Management](#10-context-window-management)
11. [Fuzzing and Symbolic Execution](#11-fuzzing-and-symbolic-execution)
12. [Self-Evolution System](#12-self-evolution-system)
13. [Memory System](#13-memory-system)
14. [Database](#14-database)
15. [Benchmark Suite](#15-benchmark-suite)
16. [Codex vs Claude Code Differences](#16-codex-vs-claude-code-differences)
17. [Troubleshooting](#17-troubleshooting)
18. [Architecture Reference](#18-architecture-reference)

---

## 1. What This System Does

The **Safe Agentic Workflow (SAW) v3** is a deterministic, model-agnostic smart contract auditing OS.

It works by:
1. **Decomposing** the target protocol into 10 structured dimensions
2. **Mapping** business flows with economic risk scores
3. **Compiling** proof obligations into precise 19-field tasks (≥20% must be fuzzing/symbolic phase)
4. **Reasoning** over each task in parallel, each with bounded context and token budget
5. **Fuzzing** accounting invariants and multi-step sequences with Medusa/Echidna/Halmos
6. **Verifying** every hypothesis independently via Foundry PoC (Reasoner never verifies its own claims)
7. **Enforcing** a hard loop: `cycle-controller.sh` is the sole authority on when to stop
8. **Persisting** all artifacts to disk and SQLite — no phantom completions
9. **Evolving** after every cycle by applying safe improvements automatically

**Key guarantees in v3:**
- The loop **cannot be stopped early** — `cycle-controller.sh` enforces `min_cycles: 3` hard minimum
- Every stage **must write an artifact** — missing artifacts trigger automatic re-dispatch
- All 19 task fields are **mechanically validated** — `validate-outputs.sh` enforces the schema
- Codex will **not pause for approval** — `approval_policy = "never"` with `job_max_runtime = 4h`

---

## 2. Prerequisites

| Tool | Required | Install |
|------|----------|---------| 
| **Foundry** | Yes | `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| **Slither** | Yes (SAST) | `pip3 install slither-analyzer` |
| **Medusa** | Recommended | `go install github.com/crytic/medusa@latest` |
| **Echidna** | Recommended | See [Echidna releases](https://github.com/crytic/echidna/releases) |
| **Halmos** | Optional | `pip3 install halmos` |
| **SQLite3** | Yes | `apt install sqlite3` or `brew install sqlite3` |
| **Python3** | Yes | `apt install python3` |
| **Codex CLI** or **Claude Code** | Yes | See provider docs |

Verify:
```bash
forge --version
slither --version
medusa --version 2>/dev/null || echo "medusa not installed"
echidna --version 2>/dev/null || echo "echidna not installed"
sqlite3 --version
python3 --version
```

---

## 3. One-Time Setup

```bash
# 1. Clone the harness
git clone https://github.com/your-org/safe-agentic-workflow.git
cd safe-agentic-workflow

# 2. Initialize the database
bash db/init.sh
# Creates db/saw.db with all tables

# 3. Make all scripts executable
chmod +x scripts/*.sh

# 4. Verify setup
sqlite3 db/saw.db '.tables'
# Should list: runs, flows, tasks, findings, artifacts, tool_calls, gate_results,
#              false_positives, harness_versions, gap_cycles

# 5. (Optional) Install fuzzing tools
pip3 install halmos
pip3 install slither-analyzer
# medusa and echidna: see their GitHub releases
```

---

## 4. Configure Your Audit

Edit `audit.config.yml` before every audit:

```yaml
loop:
  max_cycles: 6              # Maximum cycles (complex protocols may need 6+)
  min_cycles: 3              # ALWAYS run at least 3 cycles — enforced by cycle-controller.sh
  convergence_threshold: 0.3 # HARD to converge — prevents premature stopping
  stop_on_critical_finding: false

parallelism:
  max_reasoning_workers: 3
  dispatch_mode: "parallel"  # Use "parallel" for Codex, "task_tool" for Claude Code

scanner:
  mode: "audit_grade"
  min_phase_4_plus_ratio: 0.20  # At least 20% tasks use fuzzing/invariant/symbolic

verification:
  require_poc_for_high: true
  require_poc_for_critical: true

fuzzing:
  enabled: true
  fuzz_timeout_sec: 300
  medusa_workers: 4
  echidna_test_limit: 50000
  halmos_loop_bound: 10

artifact_enforcement:
  require_reasoning_artifacts: true    # Cannot converge with missing reasoning files
  require_verification_artifacts: true
  min_flow_coverage_ratio: 0.80        # 80% of flows need resolved tasks before convergence
```

**For most audits**: the defaults (from this v3 config) work well. Only adjust `max_cycles` and `scanner.mode`.

---

## 5. Run an Audit — Two Steps

### Step 1: Initialize workspace

```bash
bash scripts/run-audit.sh /path/to/target/contracts \
  --protocol "ProtocolName" \
  --mode audit_grade
```

This prints a ready-to-paste prompt with your Run ID embedded. That's all it does.

### Step 2: Paste the printed prompt into Codex or Claude Code

The prompt looks like this:
```
@orchestrator

Audit /path/to/contracts for protocol ProtocolName.
Run ID: audit-2026-07-09T... (already registered in the database).
Mode: audit_grade. Max cycles: 6. Min cycles: 3. ...

## Read these files first:
...

## Run the full pipeline:
...
```

Paste it. The model runs everything autonomously from there — SAST, decomposition, flow mapping, task compilation, parallel reasoning, skeptic challenges, verification, fuzzing, economic analysis, deduplication, reporting — for up to 4 hours. You get `findings/EXECUTIVE-SUMMARY.md` at the end.

**That's it. Two commands. You don't touch anything in between.**

---

## 6. What Happens After You Paste the Prompt

The orchestrator executes this sequence automatically for each cycle:

```
1. Read CLAUDE.md → AGENTS.md → orchestrator.md → audit.config.yml

2. Pre-flight:
   bash db/init.sh (if needed)
   mkdir -p specs/cycles specs/skills-loaded ...
   Import run ID

3. Stage 1 — SAST + Decompose (parallel):
   @sast-integrator → specs/sast/
   @decomposer      → specs/decomposition/
   GATE: Decomposition Gate (Judge)

4. Stage 1.5 — Flow Mapping:
   @flow-mapper → specs/flows/FLOW-INDEX.md (ordered by economic risk)
   bash scripts/db-write.sh import-flows ...

5. Stage 2 — Task Compilation:
   @threat-modeler → specs/tasks/ (19 fields, neg-memory check, phase heuristics)
   bash scripts/validate-outputs.sh all
   GATE: Task Quality Gate (Judge)
   bash scripts/db-write.sh import-tasks ...

6. Stage 3 — Context + Hypotheses (parallel):
   @context-builder → specs/context/TASK-{N}-context.md
   @hypothesis-generator → specs/hypotheses/HYPOTHESIS-CLOUD-{cycle}.md

7. Stage 4 — Reasoning (parallel, up to max_reasoning_workers):
   For each task:
     bash scripts/db-write.sh task-start TASK-{N}
     @deep-reasoner → specs/reasoning/TASK-{N}-reasoning.md  ← MUST write this file
     [GATE: Drift Detection]

8. Stage 5 — Skeptic Challenge (parallel):
   @skeptic → specs/reasoning/TASK-{N}-skeptic.md  ← MUST write this file

9. Stage 6 — Blind Handoff:
   Orchestrator strips CoT → specs/verification/TASK-{N}-claim.md

10. Stage 7 — Verification + Fuzzing:
    Phase 3 tasks:
      @verifier → specs/verification/TASK-{N}-verification.md
    Phase 4+ tasks (parallel):
      @verifier → verification.md
      @fuzzer   → fuzz-{tool}.md  (Foundry invariant / Medusa / Echidna / Halmos)
    GATE: Evidence Gate (10 gates, Judge)

11. Stage 8 — Economic Analysis (CONFIRMED findings only):
    @economic-analyst → specs/verification/TASK-{N}-economic.md

12. Stage 9 — Cycle Completion Check:
    bash scripts/check-pipeline-artifacts.sh --cycle N
    bash scripts/update-dashboard.sh --run-id RUN_ID
    bash scripts/cycle-controller.sh --run-id RUN_ID --cycle-number N
    → exit 0: proceed to post-convergence
    → exit 1: bash auto-evolve.sh, then start cycle N+1

13. [After convergence approved]:
    bash scripts/check-coverage.sh --run-id RUN_ID
    @deduplicator → findings/DEDUP-REPORT.md
    @report-compiler → findings/EXECUTIVE-SUMMARY.md
    @harness-critic → specs/evolution/harness-critique-latest.md
    bash scripts/auto-evolve.sh
    bash scripts/db-write.sh run-complete RUN_ID
```

**The operator has zero interaction during this process.** Everything is automatic.

---

## 7. Monitor Progress

```bash
# Live dashboard (auto-updated after every task)
watch -n 10 cat findings/DASHBOARD.md

# Query the database
sqlite3 db/saw.db 'SELECT * FROM v_run_summary;'
sqlite3 db/saw.db "SELECT task_id, status, verdict FROM tasks ORDER BY created_at DESC LIMIT 20;"

# Check cycle progress
ls specs/cycles/CYCLE-*-COMPLETE.txt    # Completed cycles
ls specs/cycles/CYCLE-*-STARTED.txt     # Started cycles
cat specs/cycles/CURRENT-RUN-ID.txt     # Current run ID

# Check artifact health
bash scripts/check-pipeline-artifacts.sh --cycle 1

# Check flow coverage
bash scripts/check-coverage.sh

# Watch findings accumulate
ls -lt findings/FINDING-*.md 2>/dev/null

# Watch skill loading
ls specs/skills-loaded/ 2>/dev/null

# Check gate decisions
ls specs/gates/
```

---

## 8. Read the Results

After the audit completes:

| File | What It Contains |
|------|----------------|
| `findings/EXECUTIVE-SUMMARY.md` | All confirmed findings with severity, PoC, and remediation |
| `findings/FINDING-{ID}.md` | One file per confirmed finding with full Foundry PoC |
| `findings/DEDUP-REPORT.md` | Which findings were merged (duplicates across cycles) |
| `findings/COVERAGE-MAP.md` | What was examined and what was skipped |
| `findings/DASHBOARD.md` | Final dashboard with totals and costs |
| `specs/cycles/GAP-ANALYSIS-{N}.md` | What remains unexamined after each cycle |
| `specs/verification/TASK-*-fuzz-*.md` | Fuzzer output for phase 4+ tasks |
| `db/saw.db` | Full structured audit trace (tasks, findings, costs, gates) |

**Finding classification ladder:**

| Level | Meaning | Action |
|-------|---------|--------|
| Hypothesis | Reasoner proposed, no verification | Ignore unless escalated |
| Candidate | Partially verified, evidence incomplete | Review manually |
| Verified | PoC passes 3/3 Foundry runs | Include in report |
| Confirmed | Verified + 10 evidence gates passed + economic impact | Final finding |

**HITL Review**: After completion, review all `Confirmed` findings in `findings/EXECUTIVE-SUMMARY.md` and sign off. This is the final gate.

---

## 9. Scanner Modes

| Mode | Min Cycles | Convergence | Fuzzing | Gap Cycles | Use Case |
|------|-----------|-------------|---------|-----------|---------|
| `audit_grade` | 3 | 0.3 (hard) | Full | Yes (max 6) | Production audits |
| `discovery` | 2 | 0.5 | Lighter | Yes (max 2) | First recon |
| `contest_rush` | 1 | 0.6 | Phase 3 only | No | 24-hour contest |
| `fast_triage` | 1 | 0.7 | Skip | No | Pre-audit screening |
| `smoke_scan` | 1 | N/A | No | No | 30-minute surface check |
| `conservative` | 2 | 0.2 | Full | No | Bug bounty, max precision |

**Bug Bounty sequence:**
```bash
bash scripts/run-audit.sh ./contracts --mode discovery    --protocol "MyProtocol"
bash scripts/run-audit.sh ./contracts --mode contest_rush --protocol "MyProtocol"
bash scripts/run-audit.sh ./contracts --mode audit_grade  --protocol "MyProtocol"
```

---

## 10. Context Window Management

The harness prevents context overflow via three mechanisms:

### Per-Task Context Slicing
Every task gets a dedicated context package containing only the relevant function and callees:
```bash
bash scripts/slice-context.sh \
  --task specs/tasks/TASK-001.md \
  --src /path/to/contracts \
  --out specs/context/TASK-001-context.md \
  --max-tokens 8000 \
  --depth 2
```

The slicer in v3 handles:
- Foundry remappings (`@openzeppelin/...` → resolved path)
- Python3-based function body extraction (handles assembly, string literals)
- awk fallback if python3 unavailable
- Hard budget cap with graceful truncation

### Hierarchical Decomposition
For protocols with > 10 contracts, the Decomposer uses 3 passes:
- **Pass 1**: Header scan (function signatures only) — ~200-400 tokens per file
- **Pass 2**: Full read of top-priority 5-8 contracts
- **Pass 3**: On-demand reads for specific functions

### Skills-Loaded Evidence
Each agent writes `specs/skills-loaded/TASK-{N}-skills.txt` after loading its skills. The orchestrator can verify skills were actually loaded before accepting the agent's output.

---

## 11. Fuzzing and Symbolic Execution

v3 adds a dedicated `@fuzzer` agent that runs in parallel with `@verifier` for phase 4+ tasks.

### Phase Assignment Rules (enforced by Threat Modeler)

| Phase | Tool | Triggers |
|-------|------|---------|
| `3-foundry-unit` | Foundry PoC | Single function, deterministic path |
| `4-foundry-invariant` | Foundry invariant test | Any task with `totalAssets`, `totalSupply`, `shares`, solvency |
| `5-medusa-fuzz` | Medusa | Multi-step sequences, partial fills, cancel/withdraw ordering |
| `6-echidna` | Echidna | Arithmetic properties, overflow, precision |
| `7-halmos` | Halmos | Formal safety proofs, symbolic property verification |

**Minimum 20% of tasks must be phase 4+** — enforced by `min_phase_4_plus_ratio: 0.20`.

### Fuzzer Output
Results are written to `specs/verification/TASK-{N}-fuzz-{tool}.md`:
- `VIOLATION_FOUND` — with exact counterexample call sequence
- `NO_VIOLATION` — with coverage metrics (strong safety evidence)
- `TIMEOUT` — increase `fuzz_timeout_sec` in config

### Running Fuzz Tools Manually
```bash
# Medusa (multi-step stateful)
medusa fuzz --config medusa.json --target ContractName

# Echidna (property-based)
echidna TestContract.sol --contract TestContract --config echidna.yaml

# Halmos (symbolic)
halmos --contract ContractName --function check_invariant --loop 10
```

---

## 12. Self-Evolution System

After every cycle:
```
@harness-critic analyzes cycle artifacts → specs/evolution/harness-critique-latest.md
bash scripts/auto-evolve.sh --run-id RUN_ID
  → SAFE changes applied automatically (FP patterns, keywords)
  → GATED changes require benchmark guard (auto-evolve checks before/after score)
```

### Auto-apply thresholds (set in `audit.config.yml`):
```yaml
evolution:
  auto_apply_safe: true      # FP patterns, detection keywords
  auto_apply_gated: false    # Agent file edits require human approval (default)
  gated_improvement_threshold: 0.05  # Must improve benchmark by 5%
  benchmark_guard: true
```

### Benchmark Suite
```bash
# Run all benchmarks
bash scripts/run-benchmark.sh --mode fast_triage

# Write to DB
bash scripts/run-benchmark.sh --write-db

# View history
sqlite3 db/saw.db 'SELECT version_id, benchmark_before, benchmark_after, applied_at FROM harness_versions ORDER BY applied_at DESC LIMIT 10;'
```

Current benchmark cases:
- `benchmarks/known-bugs/erc4626-share-inflation/` — Must find High finding
- `benchmarks/known-bugs/reentrancy-eth/` — Must find Critical finding
- `benchmarks/false-positive-cases/erc4626-with-virtual-offset/` — Must NOT flag

---

## 13. Memory System

| Layer | Location | Contents | Cleared When |
|-------|----------|----------|-------------|
| Working | `memory/working/` | Current task state | After each task |
| Run | `memory/run/` | Current audit state | After each audit |
| Episodic | `memory/episodic/` | Past audit summaries | Never |
| Semantic | `memory/semantic/` | Pattern library | Never |
| Procedural | `memory/procedural/` | Proven workflows | Never |
| **Negative** | `memory/negative/false-positives.jsonl` | FP patterns (do not chase) | Never (append-only) |
| Evidence | `memory/evidence/{run-id}/` | Immutable PoC outputs | Never (append-only) |

**To add a manual FP pattern** (after human review):
```bash
echo '{"id":"MANUAL-001","pattern":"describe the safe pattern","why_false_positive":"why it is safe","detection_keywords":["keyword1","keyword2"],"added_at":"2026-07-09"}' \
  >> memory/negative/false-positives.jsonl
```

Or use the wrapper:
```bash
bash scripts/db-write.sh fp-add "pattern description" "why it is safe" '"keyword1","keyword2"'
```

---

## 14. Database

```bash
# Initialize (one-time)
bash db/init.sh

# Current run summary
sqlite3 db/saw.db 'SELECT * FROM v_run_summary;'

# Task verdicts
sqlite3 db/saw.db "SELECT task_id, status, verdict, severity FROM tasks WHERE run_id = 'your-run-id';"

# Confirmed findings
sqlite3 db/saw.db "SELECT * FROM findings WHERE verdict = 'CONFIRMED';"

# Flow coverage
sqlite3 db/saw.db 'SELECT * FROM v_flow_coverage ORDER BY economic_risk_score DESC;'

# Cost breakdown
sqlite3 db/saw.db "SELECT task_id, cost_usd, tokens_used, verdict FROM tasks ORDER BY cost_usd DESC LIMIT 10;"

# Harness evolution history
sqlite3 db/saw.db 'SELECT component, benchmark_before, benchmark_after, applied_at FROM harness_versions ORDER BY applied_at DESC LIMIT 10;'
```

---

## 15. Benchmark Suite

```bash
# Run all
bash scripts/run-benchmark.sh --mode fast_triage

# Known bugs only (must find)
bash scripts/run-benchmark.sh --category known-bugs

# False positive cases (must NOT flag)
bash scripts/run-benchmark.sh --category false-positive-cases

# Write results to DB
bash scripts/run-benchmark.sh --write-db
```

**Ground truth is immutable** — never edit `expected_finding.json` files. The harness must evolve to match truth, not the other way around.

---

## 16. How Multi-Model Selection Actually Works

### The Honest Architecture

Codex and Claude Code each run **one model for the entire session**. You select the model in the UI or CLI before starting. The harness cannot switch models mid-session — there are no API calls.

`model-config.yml` is a **planning document**, not a runtime switch. It tells you which model to select in your AI client for each stage. The staged run system makes this mapping real.

### The Solution: Staged Multi-Session Runs

Every stage writes completion files to disk. The next stage reads from those files. Run each stage in a separate Codex/Claude Code session with the optimal model for that work.

```
┌─────────────────────────────────────────────────────────────────┐
│  Session 1 — PLANNING                                           │
│  Model: o4-mini / claude-sonnet / gemini-flash                  │
│  Why: Pattern matching + structured output. No deep reasoning.  │
│                                                                 │
│  bash scripts/run-audit.sh /contracts \                         │
│    --stage planning --protocol "ProtocolName"                   │
│                                                                 │
│  Produces: specs/tasks/ (all 19-field tasks)                    │
│  Writes:   specs/cycles/STAGE-planning-COMPLETE.txt             │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  Session 2 — REASONING                                          │
│  Model: o3 / claude-opus / gemini-2.5-pro  ← BEST MODEL        │
│  Why: Core vulnerability discovery. Maximum reasoning depth.    │
│                                                                 │
│  bash scripts/run-audit.sh /contracts \                         │
│    --stage reasoning --protocol "ProtocolName"                  │
│                                                                 │
│  Reads:    specs/tasks/ (from Session 1)                        │
│  Produces: specs/reasoning/ + specs/verification/*-claim.md     │
│  Writes:   specs/cycles/STAGE-reasoning-COMPLETE.txt            │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  Session 3 — VERIFICATION                                       │
│  Model: o3 / claude-opus / gemini-2.5-pro  ← BEST MODEL, NEW   │
│  Why: Independent verification. Different session = different   │
│       context. The Verifier genuinely cannot see the Reasoner's │
│       chain-of-thought — it wasn't in this session at all.      │
│                                                                 │
│  bash scripts/run-audit.sh /contracts \                         │
│    --stage verification --protocol "ProtocolName"               │
│                                                                 │
│  Reads:    specs/verification/*-claim.md (from Session 2)       │
│  Produces: specs/verification/*-verification.md                 │
│  Writes:   specs/cycles/STAGE-verification-COMPLETE.txt         │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  Session 4 — REPORTING                                          │
│  Model: o4-mini / claude-haiku / gemini-flash                   │
│  Why: Text compilation. No reasoning needed.                    │
│                                                                 │
│  bash scripts/run-audit.sh /contracts \                         │
│    --stage reporting --protocol "ProtocolName"                  │
│                                                                 │
│  Reads:    specs/verification/ (from Session 3)                 │
│  Produces: findings/EXECUTIVE-SUMMARY.md                        │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Is Better Than a Single Session

| Property | Single Session | Multi-Session |
|----------|---------------|---------------|
| Verifier independence | Partial — same context window | **True** — different session, no CoT contamination |
| Model-task fit | One model does everything | Each stage uses optimal model |
| Cost | High — best model for all stages | **Lower** — cheap model for planning + reporting |
| Resume after failure | Must restart from scratch | Resume from last STAGE-*-COMPLETE.txt |
| Human review point | None during run | **Natural checkpoint between stages** |

### Session Commands Reference

```bash
# Planning — any capable model
bash scripts/run-audit.sh /path/to/contracts \
  --stage planning --protocol "ProtocolName" --mode audit_grade

# Reasoning — BEST model (new Codex/Claude Code session)
bash scripts/run-audit.sh /path/to/contracts \
  --stage reasoning --protocol "ProtocolName"

# Verification — BEST model (brand new session for independence)
bash scripts/run-audit.sh /path/to/contracts \
  --stage verification --protocol "ProtocolName"

# Reporting — any model
bash scripts/run-audit.sh /path/to/contracts \
  --stage reporting --protocol "ProtocolName"

# Single session — one model does everything
bash scripts/run-audit.sh /path/to/contracts \
  --stage all --protocol "ProtocolName"
```

Each command auto-detects the Run ID from `specs/cycles/CURRENT-RUN-ID.txt` — you do not need to pass `--run-id` between stages.

### What model-config.yml Actually Does

`model-config.yml` is your **session planning guide**. Before each stage, read it to know which model to select:

```yaml
# model-config.yml tells you:
# → planning stage:     select sonnet / gpt-4.1 / gemini-flash
# → reasoning stage:    select opus / o3 / gemini-2.5-pro
# → verification stage: select opus / o3 / gemini-2.5-pro
# → reporting stage:    select haiku / gpt-4.1-mini / gemini-flash
```

It is not read by the pipeline at runtime. It is documentation for the human operator.

### Codex vs Claude Code Differences

| Feature | Codex | Claude Code |
|---------|-------|------------|
| Model selection | CLI flag or config.toml default | UI model picker |
| `dispatch_mode` | `"parallel"` | `"task_tool"` |
| Approval policy | `"never"` (set in .codex/config.toml) | Configure in settings |
| Max job runtime | 4 hours (.codex/config.toml) | Session-dependent |
| Agent reading | AGENTS.md as system context | CLAUDE.md as system context |
| Both read | Same .claude/agents/*.md files | Same .claude/agents/*.md files |

---

## 17. Troubleshooting

### "Codex keeps stopping after cycle 1"
**Now fixed in v3.** The root cause was `approval_policy = "on-request"` making Codex pause on every file write. v3 sets `approval_policy = "never"` in `.codex/config.toml`.

If it still stops: verify `.codex/config.toml` has `approval_policy = "never"` and `job_max_runtime_seconds = 14400`.

### "Reasoning artifacts are empty"
Check if Context Builder ran slice-context.sh first:
```bash
ls specs/context/TASK-*.md  # Should have files
```
If empty, force re-run:
```bash
bash scripts/slice-context.sh --task specs/tasks/TASK-001.md --src /path/to/contracts --out specs/context/TASK-001-context.md
```

### "Task Quality Gate keeps failing"
```bash
# Run validator to see which fields are missing
bash scripts/validate-outputs.sh task specs/tasks/TASK-001.md
```
Check: `phase` field must be a valid enum. `negative_memory_check` must have `checked: true`. `budget_tokens` must be numeric.

### "cycle-controller.sh says CONTINUE after 6 cycles"
Check coverage:
```bash
bash scripts/check-coverage.sh --run-id your-run-id
```
If flow coverage < 80%, the controller correctly requires more cycles. Either lower `min_flow_coverage_ratio` in config or run more gap cycles.

### "Fuzzer not running"
Check task phase:
```bash
grep 'phase:' specs/tasks/TASK-*.md | grep -v "3-foundry"
```
If all tasks are phase 3, the Threat Modeler ignored the phase heuristics. Check `min_phase_4_plus_ratio` in config and re-run threat modeling.

### "Slither not found"
```bash
pip3 install slither-analyzer
```

### "Forge build fails in target project"
```bash
cd /path/to/target && forge install && forge build
```

### "DB not found"
```bash
bash db/init.sh
```

### "Convergence never reached"
Lower `loop.convergence_threshold` in `audit.config.yml`, or raise `loop.max_cycles`. Also check `min_flow_coverage_ratio` — if it's 0.80 and you have many flows, it may need more cycles.

---

## 18. Architecture Reference

### Full Agent Chain

```
bash scripts/run-audit.sh /contracts --mode audit_grade --protocol "Name"
  ↓ initializes workspace, prints prompt
Paste prompt into Codex or Claude Code:
  @orchestrator [prompt text]
    ↓ reads: CLAUDE.md → AGENTS.md → orchestrator.md → audit.config.yml
    ↓ pre-flight: db/init.sh, mkdir, write CURRENT-RUN-ID.txt
    ↓ [parallel]
  @sast-integrator    → specs/sast/
  @decomposer         → specs/decomposition/
    ↓ [Decomposition Gate]
  @flow-mapper        → specs/flows/
    ↓
  @threat-modeler     → specs/tasks/ (19 fields, ≥20% phase 4+)
    ↓ [Task Quality Gate + validate-outputs.sh]
  [parallel]
  @context-builder    → specs/context/
  @hypothesis-generator → specs/hypotheses/
    ↓
  [parallel × N]
  @deep-reasoner      → specs/reasoning/TASK-{N}-reasoning.md
    ↓ [Drift Gate]
  @skeptic            → specs/reasoning/TASK-{N}-skeptic.md
    ↓ Blind Handoff → specs/verification/TASK-{N}-claim.md
  [parallel]
  @verifier (phase 3) → specs/verification/TASK-{N}-verification.md
  @verifier + @fuzzer (phase 4+) → verification.md + fuzz-{tool}.md
    ↓ [Evidence Gate G1-G10]
  @economic-analyst   → specs/verification/TASK-{N}-economic.md
    ↓
  scripts/check-pipeline-artifacts.sh  → CYCLE-N-COMPLETE.txt
  scripts/update-dashboard.sh          → findings/DASHBOARD.md
  scripts/cycle-controller.sh          → exit 0 or 1
    ↓ exit 1: scripts/auto-evolve.sh → LOOP
    ↓ exit 0:
  scripts/check-coverage.sh
  @deduplicator       → findings/DEDUP-REPORT.md
  @report-compiler    → findings/EXECUTIVE-SUMMARY.md
  @harness-critic     → specs/evolution/harness-critique-latest.md
  scripts/auto-evolve.sh
  scripts/db-write.sh run-complete RUN_ID
    ↓
  Human HITL review of findings/EXECUTIVE-SUMMARY.md
```

### Quality Gates Summary (All Blocking)

| Gate | Script/Agent | Input | Action on Failure |
|------|-------------|-------|------------------|
| Decomposition Gate | Judge | `specs/decomposition/` | Return to @decomposer |
| Task Quality Gate | Judge + `validate-outputs.sh all` | `specs/tasks/` | Return to @threat-modeler |
| Drift Detection Gate | Judge | `specs/reasoning/` | Re-dispatch @deep-reasoner |
| Skeptic Gate | Skeptic | `specs/reasoning/*-skeptic.md` | Mark REJECTED, skip Verifier |
| Evidence Gate (G1-G10) | Judge | `specs/verification/` | Downgrade to CANDIDATE |
| Cycle Artifact Gate | `check-pipeline-artifacts.sh` | All stage artifacts | Re-dispatch missing stages |
| Coverage Gate | `check-coverage.sh` | DB + filesystem | Force more gap cycles |
| Loop Gate | `cycle-controller.sh` | Config + artifacts + DB | CONTINUE (exit 1) |
| Evolution Gate | `auto-evolve.sh` | Benchmark scores | Roll back bad changes |
| HITL Final Review | Human | `EXECUTIVE-SUMMARY.md` | Human judgment |

Act as the root audit orchestrator and execute the full BattleChain Confidence Pools audit pipeline. Do not only describe, summarize, or plan the work. Every stage must be executed, delegated where required, validated, and written to disk.

## Audit configuration

```text
Repository:
/home/sahilkaushik/study_material/blockchain/audit/2026-07-bc-confidence-pools

Target:
/home/sahilkaushik/study_material/blockchain/audit/2026-07-bc-confidence-pools/src

Protocol:
BattleChain Confidence Pools

Run ID:
audit-2026-07-10T18-29-06-battlechain

Mode:
audit_grade

Minimum cycles:
4

Maximum cycles:
6

Convergence threshold:
0.2

Maximum parallel deep-reasoning workers:
3

Minimum Phase 4+ tasks:
4
```

The run is already registered in the database. Resume valid existing work, but verify every artifact before reusing it.

## Initialization

First execute:

```bash
cd /home/sahilkaushik/study_material/blockchain/audit/2026-07-bc-confidence-pools

cat CLAUDE.md
cat AGENTS.md
cat .claude/agents/orchestrator.md
cat audit.config.yml

bash db/init.sh 2>/dev/null || true

mkdir -p \
  specs/cycles \
  specs/skills-loaded \
  specs/sast \
  specs/decomposition \
  specs/flows \
  specs/tasks \
  specs/reasoning \
  specs/verification \
  specs/context \
  specs/hypotheses \
  specs/evolution \
  findings

echo "audit-2026-07-10T18-29-06-battlechain" \
  > specs/cycles/CURRENT-RUN-ID.txt
```

Also inspect all available agent files:

```bash
find .claude/agents -maxdepth 1 -type f -name '*.md' | sort
```

## Agent execution rules

Files under `.claude/agents/` are role instructions, not shell commands.

For every role:

1. Read the complete role file.
2. Spawn a real Codex subagent using those instructions.
3. Give the subagent the exact task, inputs, cycle number, task ID, run ID, target files, and required output path.
4. Require it to write its result to disk.
5. Wait for the worker to finish.
6. Verify the required artifact exists and is non-empty.
7. Rerun or replace the worker if the artifact is missing, malformed, incomplete, or written to the wrong path.

Do not treat reading an agent file as executing that agent.

Do not accept a chat response in place of the required file.

Use real parallel execution where the pipeline says parallel. Do not run more than three deep-reasoning workers at once.

Maintain:

```text
specs/cycles/PIPELINE-STATE.md
specs/cycles/EXECUTION-LOG.md
```

Record the current cycle, stage, active tasks, completed tasks, failed commands, gate results, missing artifacts, coverage result, and controller exit code.

---

# Stage 1 — SAST and decomposition

Run these two agents concurrently:

```text
.claude/agents/sast-integrator.md
→ specs/sast/

.claude/agents/decomposer.md
→ specs/decomposition/
```

The SAST worker must run the configured static-analysis tools and record both successful and unavailable tools.

The decomposer must analyze:

* In-scope contracts.
* Inheritance.
* Storage.
* External interfaces.
* Public and external entry points.
* Internal call chains.
* Privileged roles.
* State machines.
* Token flows.
* Cross-contract dependencies.
* Trust boundaries.

Use three-pass hierarchical decomposition only if the scope contains more than ten contracts.

After both workers finish, verify that both output directories contain non-empty artifacts.

Run the Decomposition Gate as judge. Write:

```text
specs/decomposition/DECOMPOSITION-GATE.md
```

Do not continue until the gate passes.

---

# Stage 1.5 — Flow mapping

Run:

```text
.claude/agents/flow-mapper.md
```

Required output:

```text
specs/flows/FLOW-INDEX.md
```

The flow index must cover:

* Every public and external flow.
* Internal functions affecting those flows.
* Token movements.
* Registry-state transitions.
* Stake and withdrawal paths.
* Bonus contribution and distribution.
* Resolution paths.
* Moderator paths.
* Sponsor paths.
* Factory and upgrade paths.
* Cross-flow state interactions.

Verify the file and import it:

```bash
test -s specs/flows/FLOW-INDEX.md

bash scripts/db-write.sh import-flows \
  specs/flows/FLOW-INDEX.md \
  audit-2026-07-10T18-29-06-battlechain
```

Do not continue if the import fails.

---

# Stage 2 — Task compilation

Run:

```text
.claude/agents/threat-modeler.md
→ specs/tasks/
```

The threat modeler must use:

* SAST results.
* Decomposition.
* Flow index.
* Protocol documentation.
* `docs/DESIGN.md`.
* Existing negative memory.
* Known intentional behaviors.

Every task must contain all required 19 fields.

The task set must include:

* Flow-specific tasks.
* Cross-flow tasks.
* Accounting tasks.
* State-transition tasks.
* Authorization tasks.
* Liveness and DoS tasks.
* Rounding and precision tasks.
* Snapshot and claim-order tasks.
* Upgradeability tasks.
* External-call and token-transfer tasks.

At least four tasks must be meaningful Phase 4+ tasks. Do not assign everything to Phase 3.

Run:

```bash
bash scripts/validate-outputs.sh all
```

Run the Task Quality Gate and write:

```text
specs/tasks/TASK-QUALITY-GATE.md
```

Repair failed or weak tasks before continuing.

Then import tasks:

```bash
bash scripts/db-write.sh import-tasks \
  specs/tasks/INDEX.md \
  audit-2026-07-10T18-29-06-battlechain
```

---

# Audit cycle loop

Run at least four cycles and at most six.

Never stop before Cycle 4.

For every cycle, execute Stages 3 through 9.

The cycle controller is the only authority that may declare convergence.

---

# Stage 3 — Context and hypotheses

Run in parallel:

```text
.claude/agents/context-builder.md
→ specs/context/TASK-{ID}-context.md

.claude/agents/hypothesis-generator.md
→ specs/hypotheses/HYPOTHESIS-CLOUD-{cycle}.md
```

Use `slice-context.sh` for task-specific context.

Each context file must include only the relevant:

* Contracts.
* Functions.
* State variables.
* Roles.
* Flows.
* Tests.
* Documentation.
* External interfaces.
* Known false positives.

The hypothesis cloud must contain new cycle-specific hypotheses and must not blindly repeat previously rejected ideas.

Verify every context and hypothesis artifact before Stage 4.

---

# Stage 4 — Deep reasoning

Process tasks with a maximum of three concurrent workers.

Before each task, run:

```bash
bash scripts/db-write.sh task-start \
  TASK-{ID} \
  audit-2026-07-10T18-29-06-battlechain
```

Run:

```text
.claude/agents/deep-reasoner.md
```

Required output:

```text
specs/reasoning/TASK-{ID}-reasoning.md
```

The reasoning must test:

* Reachability.
* Attacker control.
* Required state.
* Required call sequence.
* Registry conditions.
* Token conditions.
* Trusted-role assumptions.
* Accounting effects.
* Victim impact.
* Existing checks.
* Counterexamples.
* Relevant intentional behavior in `docs/DESIGN.md`.

The reasoning artifact must be written to disk.

Run the Drift Detection Gate. Reject reasoning that is out of scope, based on unsupported assumptions, incompatible with standard ERC-20 scope, or already documented as intentional behavior.

---

# Stage 5 — Skeptic challenge

For every reasoning task, run a separate skeptic:

```text
.claude/agents/skeptic.md
→ specs/reasoning/TASK-{ID}-skeptic.md
```

The skeptic must try to disprove:

* Reachability.
* State feasibility.
* Attacker permissions.
* Profitability.
* Repeatability.
* Loss severity.
* Scope validity.
* Token compatibility.
* Timing assumptions.
* Missing protocol protections.
* Known design decisions.

Only tasks surviving the skeptic continue.

Preserve rejected hypotheses and rejection reasons as negative memory.

---

# Stage 6 — Blind handoff

The root orchestrator performs this stage directly.

For every surviving task, create:

```text
specs/verification/TASK-{ID}-claim.md
```

The claim file must contain only:

```markdown
# Hypothesis

# Attack Path

# Witness
```

Do not include:

* Full reasoning.
* Skeptic conclusions.
* Confidence scores.
* Expected verdict.
* References to `reasoning.md`.
* References to `skeptic.md`.

The verifier must remain blind to the reasoning process.

---

# Stage 7 — Verification and fuzzing

The verifier must not read:

```text
specs/reasoning/TASK-{ID}-reasoning.md
specs/reasoning/TASK-{ID}-skeptic.md
```

It may read only the claim, source code, tests, build configuration, and necessary protocol documentation.

For Phase 3 tasks:

```text
.claude/agents/verifier.md
→ specs/verification/TASK-{ID}-verification.md
```

For Phase 4+ tasks, run in parallel:

```text
.claude/agents/verifier.md
.claude/agents/fuzzer.md
```

Required outputs:

```text
specs/verification/TASK-{ID}-verification.md
specs/verification/TASK-{ID}-fuzz-{tool}.md
```

The fuzzer must actually execute the required tools. Do not claim fuzzing occurred without command output, tests, traces, or tool evidence.

Record:

* Commands executed.
* Tests created.
* Build results.
* Reproduction steps.
* State transitions.
* Balance changes.
* Expected result.
* Actual result.
* Limitations.
* Whether the issue is deterministic.

Run the complete Evidence Gate G1–G10.

Only tasks passing all required gates may be marked:

```text
CONFIRMED
```

Use explicit verdicts:

```text
CONFIRMED
REJECTED
INCONCLUSIVE
DESIGN-INTENDED
OUT-OF-SCOPE
DUPLICATE
```

Do not convert an unresolved hypothesis into a finding.

---

# Stage 8 — Economic analysis

Run only for confirmed findings:

```text
.claude/agents/economic-analyst.md
→ specs/verification/TASK-{ID}-economic.md
```

Analyze:

* Capital required.
* Attacker cost.
* Attacker profit.
* Victim loss.
* Maximum impact.
* Repeatability.
* Timing constraints.
* Liquidity requirements.
* Realistic versus theoretical impact.
* Gas and fee sensitivity.

Do not invent unsupported values.

---

# Stage 9 — Cycle completion

Run:

```bash
bash scripts/check-pipeline-artifacts.sh \
  --cycle {cycle} \
  --run-id audit-2026-07-10T18-29-06-battlechain
```

If it fails, repair all missing or malformed artifacts and rerun it.

Then run:

```bash
bash scripts/update-dashboard.sh \
  --run-id audit-2026-07-10T18-29-06-battlechain
```

---

# Coverage and convergence control

After every cycle, run:

```bash
bash scripts/check-coverage.sh \
  --run-id audit-2026-07-10T18-29-06-battlechain
```

Then run:

```bash
bash scripts/cycle-controller.sh \
  --run-id audit-2026-07-10T18-29-06-battlechain \
  --cycle-number {cycle}
```

Rules:

* Cycles 1–4 are mandatory.
* Do not declare convergence before Cycle 4.
* Exit `1` means another cycle is required.
* When exit is `1`, run:

```bash
bash scripts/auto-evolve.sh \
  --run-id audit-2026-07-10T18-29-06-battlechain
```

* Use coverage gaps, rejected hypotheses, unresolved tasks, and harness evolution to build the next cycle.
* Do not simply rerun identical tasks.
* Exit `0` after Cycle 4 or later permits post-convergence.
* Never declare convergence unless `cycle-controller.sh` actually exits `0`.
* Do not exceed Cycle 6 unless repository instructions explicitly authorize it.

---

# Post-convergence

After authorized convergence, run:

```text
.claude/agents/deduplicator.md
→ findings/DEDUP-REPORT.md

.claude/agents/report-compiler.md
→ findings/EXECUTIVE-SUMMARY.md

.claude/agents/harness-critic.md
→ specs/evolution/harness-critique-latest.md
```

The final report must contain only confirmed, evidence-gated, deduplicated findings.

Do not include rejected, design-intended, or inconclusive hypotheses as vulnerabilities.

Then run:

```bash
bash scripts/auto-evolve.sh \
  --run-id audit-2026-07-10T18-29-06-battlechain

bash scripts/db-write.sh run-complete \
  audit-2026-07-10T18-29-06-battlechain

bash scripts/update-dashboard.sh \
  --run-id audit-2026-07-10T18-29-06-battlechain
```

Do not mark the run complete before all required artifacts exist.

---

# Mandatory enforcement rules

* Execute the pipeline; do not merely describe it.
* Do not stop after Cycle 1.
* Complete at least four cycles.
* Do not skip any stage, gate, command, or required artifact.
* Missing or empty artifact means the stage is incomplete.
* Do not accept subagent chat output instead of files.
* Do not let the verifier read reasoning or skeptic artifacts.
* Maintain at least four meaningful Phase 4+ tasks.
* Run verifier and fuzzer in parallel for Phase 4+ tasks.
* Do not claim fuzzing unless the tool actually ran.
* Run all Evidence Gates G1–G10.
* Check every candidate against `docs/DESIGN.md`.
* Respect standard ERC-20 and trusted-role assumptions.
* Do not report intentional behavior as a vulnerability.
* Do not report hypotheses without reproducible evidence.
* Do not perform economic analysis for unconfirmed issues.
* Do not mark the database run complete early.
* Retry failed workers and commands when locally recoverable.
* Record genuine blockers instead of silently skipping work.
* Keep executing autonomously until the controller authorizes convergence and all artifacts are complete.

Before finishing, verify:

```bash
test -s specs/flows/FLOW-INDEX.md
test -s specs/tasks/INDEX.md
test -s specs/cycles/PIPELINE-STATE.md
test -s specs/cycles/EXECUTION-LOG.md
test -s findings/DEDUP-REPORT.md
test -s findings/EXECUTIVE-SUMMARY.md
test -s specs/evolution/harness-critique-latest.md
```

Final response must report only:

```text
Run ID
Cycles completed
Controller exit code
Convergence status
Tasks processed
Phase 4+ tasks processed
Confirmed findings
Rejected findings
Inconclusive tasks
Main artifact paths
Unavailable tools
Remaining limitations
```

Start execution now.

