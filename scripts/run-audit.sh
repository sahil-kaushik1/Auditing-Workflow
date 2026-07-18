#!/usr/bin/env bash
# =============================================================================
# run-audit.sh — SAW Smart Contract Audit Harness — Workspace Initializer
# =============================================================================
#
# HOW TO USE (two steps, that's it):
#
#   Step 1:  bash scripts/run-audit.sh /path/to/contracts --protocol "Name"
#   Step 2:  Copy the printed prompt into Codex or Claude Code and press Enter.
#
# The harness runs autonomously for up to 4 hours. You get a full audit report.
#
# Options:
#   --protocol  Protocol name (default: "unknown")
#   --mode      audit_grade | discovery | contest_rush | fast_triage | smoke_scan
#               (default: audit_grade)
#   --rpc-url   RPC endpoint for on-chain queries in economic analysis
#   --dry-run   Print settings without registering the run
#
# Examples:
#   bash scripts/run-audit.sh ~/repos/1inch --protocol "1inch-swap"
#   bash scripts/run-audit.sh ~/repos/vault --mode discovery --protocol "MyVault"
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="${HARNESS_ROOT}/db/saw.db"

# ── Parse Arguments ───────────────────────────────────────────────────────────

PROJECT_PATH=""
MODE="audit_grade"
PROTOCOL="unknown"
RPC_URL=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)       MODE="$2";      shift 2 ;;
    --protocol)   PROTOCOL="$2";  shift 2 ;;
    --rpc-url)    RPC_URL="$2";   shift 2 ;;
    --dry-run)    DRY_RUN=true;   shift 1 ;;
    -*)  echo "Unknown flag: $1" >&2
         echo "Usage: $0 <project-path> [--mode MODE] [--protocol NAME] [--rpc-url URL]"
         exit 1 ;;
    *)   PROJECT_PATH="$1"; shift 1 ;;
  esac
done

if [ -z "$PROJECT_PATH" ]; then
  echo -e "${RED}Error: project path is required.${NC}"
  echo "Usage: $0 <project-path> [--protocol NAME] [--mode MODE]"
  exit 1
fi

PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)"

# ── Banner ────────────────────────────────────────────────────────────────────

echo -e "${BOLD}${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   SAW — Smart Contract Audit Harness v3                      ║"
echo "║   One prompt. One model. Full autonomous audit.               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ── Pre-flight Checks ─────────────────────────────────────────────────────────

echo -e "${BOLD}[PRE-FLIGHT]${NC}"

if [ ! -f "$DB_PATH" ]; then
  echo -e "  ${YELLOW}⚠ Database not found. Initializing...${NC}"
  bash "${HARNESS_ROOT}/db/init.sh"
fi
echo -e "  ${GREEN}✓ Database ready${NC}"

if command -v forge &>/dev/null; then
  echo -e "  ${GREEN}✓ Foundry available${NC}"
else
  echo -e "  ${YELLOW}⚠ Foundry not found — install with: curl -L https://foundry.paradigm.xyz | bash${NC}"
fi

if command -v slither &>/dev/null; then
  echo -e "  ${GREEN}✓ Slither available${NC}"
else
  echo -e "  ${YELLOW}⚠ Slither not found — install with: pip3 install slither-analyzer${NC}"
fi

if command -v medusa &>/dev/null; then
  echo -e "  ${GREEN}✓ Medusa available${NC}"
else
  echo -e "  ${YELLOW}⚠ Medusa not found (optional fuzzer)${NC}"
fi

if command -v echidna &>/dev/null; then
  echo -e "  ${GREEN}✓ Echidna available${NC}"
else
  echo -e "  ${YELLOW}⚠ Echidna not found (optional fuzzer)${NC}"
fi

if ! command -v sqlite3 &>/dev/null; then
  echo -e "  ${RED}✗ sqlite3 not found — required. Install: apt install sqlite3${NC}"
  exit 1
fi

# ── Generate Run ID ───────────────────────────────────────────────────────────

TIMESTAMP=$(date +"%Y-%m-%dT%H-%M-%S")
RUN_ID="audit-${TIMESTAMP}-$(echo "$PROTOCOL" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')"
SPECS_DIR="${HARNESS_ROOT}/specs"
FINDINGS_DIR="${HARNESS_ROOT}/findings"

# ── Read Config ───────────────────────────────────────────────────────────────

CONFIG_FILE="${HARNESS_ROOT}/audit.config.yml"
if [ -f "$CONFIG_FILE" ]; then
  MAX_CYCLES=$(grep 'max_cycles:'          "$CONFIG_FILE" | grep -oP '\d+'     | head -1 || echo "6")
  MIN_CYCLES=$(grep 'min_cycles:'          "$CONFIG_FILE" | grep -oP '\d+'     | head -1 || echo "3")
  CONV_THRESHOLD=$(grep 'convergence_threshold:' "$CONFIG_FILE" | grep -oP '[0-9.]+' | head -1 || echo "0.3")
  PARALLEL=$(grep 'max_reasoning_workers:' "$CONFIG_FILE" | grep -oP '\d+'     | head -1 || echo "3")
  SLICE_ENABLED=$(grep 'slice_enabled:'    "$CONFIG_FILE" | grep -oP 'true|false' | head -1 || echo "true")
  AUTO_EVOLVE=$(grep 'auto_evolve_after_cycle:' "$CONFIG_FILE" | grep -oP 'true|false' | head -1 || echo "true")
  MIN_PHASE4=$(grep 'min_phase_4_plus_ratio:' "$CONFIG_FILE" | grep -oP '[0-9.]+' | head -1 || echo "0.20")
else
  MAX_CYCLES=6; MIN_CYCLES=3; CONV_THRESHOLD=0.3; PARALLEL=3
  SLICE_ENABLED=true; AUTO_EVOLVE=true; MIN_PHASE4=0.20
fi

# ── Print Setup Summary ───────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}[AUDIT SETUP]${NC}"
echo -e "  Run ID:       ${CYAN}${RUN_ID}${NC}"
echo -e "  Protocol:     ${PROTOCOL}"
echo -e "  Mode:         ${BOLD}${MODE}${NC}"
echo -e "  Project:      ${PROJECT_PATH}"
echo -e "  Max cycles:   ${MAX_CYCLES}  (min: ${MIN_CYCLES})"
echo -e "  Convergence:  ${CONV_THRESHOLD}"
echo -e "  Workers:      ${PARALLEL} parallel reasoning workers"
echo -e "  Phase 4+ min: ${MIN_PHASE4} of tasks must use fuzzing/invariant"
[ -n "$RPC_URL" ] && echo -e "  RPC URL:      ${RPC_URL}"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}DRY RUN — showing settings only, no files written.${NC}"
  exit 0
fi

# ── Register Run in DB ────────────────────────────────────────────────────────

sqlite3 "$DB_PATH" <<SQL 2>/dev/null || true
INSERT OR IGNORE INTO runs (run_id, protocol, repo_url, started_at, mode, provider, status)
VALUES (
  '${RUN_ID}',
  '${PROTOCOL}',
  '${PROJECT_PATH}',
  '$(date -u +"%Y-%m-%dT%H:%M:%SZ")',
  '${MODE}',
  'codex',
  'running'
);
SQL
echo -e "  ${GREEN}✓ Run registered in DB${NC}"

# ── Initialize Workspace ──────────────────────────────────────────────────────

mkdir -p "${SPECS_DIR}/decomposition" \
         "${SPECS_DIR}/flows" \
         "${SPECS_DIR}/tasks" \
         "${SPECS_DIR}/context" \
         "${SPECS_DIR}/reasoning" \
         "${SPECS_DIR}/verification" \
         "${SPECS_DIR}/sast/raw" \
         "${SPECS_DIR}/gates" \
         "${SPECS_DIR}/cycles" \
         "${SPECS_DIR}/evolution" \
         "${SPECS_DIR}/hypotheses" \
         "${SPECS_DIR}/skills-loaded" \
         "${FINDINGS_DIR}" \
         "${HARNESS_ROOT}/memory/evidence/${RUN_ID}"

echo "$RUN_ID" > "${SPECS_DIR}/cycles/CURRENT-RUN-ID.txt"

# Initialize dashboard
cat > "${FINDINGS_DIR}/DASHBOARD.md" <<EOF
# Audit Dashboard — ${PROTOCOL}

**Run ID**: \`${RUN_ID}\`
**Mode**: ${MODE}
**Status**: 🟡 RUNNING
**Started**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

---

## Findings
| Severity | Confirmed |
|---------|-----------|
| Critical | 0 |
| High     | 0 |
| Medium   | 0 |
| Low      | 0 |

## Task Progress
| Status    | Count |
|-----------|-------|
| Pending   | 0 |
| Running   | 0 |
| Done      | 0 |

## Coverage
(flows not yet mapped)
EOF

# Negative memory count
FP_COUNT=$(wc -l < "${HARNESS_ROOT}/memory/negative/false-positives.jsonl" 2>/dev/null || echo "0")

echo -e "  ${GREEN}✓ Workspace initialized${NC}"
echo -e "  ${GREEN}✓ Negative memory: ${FP_COUNT} FP patterns loaded${NC}"
echo ""

# Export env vars for the agent session
export SAW_RUN_ID="$RUN_ID"
export SAW_PROTOCOL="$PROTOCOL"
export SAW_MODE="$MODE"
export SAW_PROJECT_PATH="$PROJECT_PATH"
export SAW_DB_PATH="$DB_PATH"
[ -n "$RPC_URL" ] && export RPC_URL="$RPC_URL"

# ── Print The One Prompt ──────────────────────────────────────────────────────

SEP="════════════════════════════════════════════════════════"
echo -e "${BOLD}${CYAN}${SEP}${NC}"
echo -e "${BOLD}  ⚡ YOUR PROMPT — paste this into Codex or Claude Code:${NC}"
echo -e "${BOLD}${CYAN}${SEP}${NC}"
echo ""

cat << PROMPT
@orchestrator

Audit ${PROJECT_PATH} for protocol ${PROTOCOL}.
Run ID: ${RUN_ID} (already registered in the database).
Mode: ${MODE}. Max cycles: ${MAX_CYCLES}. Min cycles: ${MIN_CYCLES}. Convergence: ${CONV_THRESHOLD}.
Parallel reasoning workers: ${PARALLEL}. Phase 4+ task minimum: ${MIN_PHASE4}.

## Read these files first (in order):
1. cat CLAUDE.md
2. cat AGENTS.md
3. cat .claude/agents/orchestrator.md
4. cat audit.config.yml

## Pre-flight:
bash db/init.sh 2>/dev/null || true
mkdir -p specs/cycles specs/skills-loaded specs/reasoning specs/verification specs/context findings specs/hypotheses
echo "${RUN_ID}" > specs/cycles/CURRENT-RUN-ID.txt

## Run the full pipeline:

Stage 1 [parallel]: SAST + Decompose
  @sast-integrator → specs/sast/
  @decomposer      → specs/decomposition/  (3-pass hierarchical if >10 contracts)
  GATE: Decomposition Gate (Judge)

Stage 1.5: Flow Mapping
  @flow-mapper → specs/flows/FLOW-INDEX.md
  bash scripts/db-write.sh import-flows specs/flows/FLOW-INDEX.md ${RUN_ID}

Stage 2: Task Compilation
  @threat-modeler → specs/tasks/  (19 fields, neg-memory check, min ${MIN_PHASE4} phase 4+)
  bash scripts/validate-outputs.sh all
  GATE: Task Quality Gate (Judge)
  bash scripts/db-write.sh import-tasks specs/tasks/INDEX.md ${RUN_ID}

Stage 3 [parallel]: Context + Hypotheses
  @context-builder      → specs/context/TASK-{N}-context.md  (use slice-context.sh)
  @hypothesis-generator → specs/hypotheses/HYPOTHESIS-CLOUD-{cycle}.md

Stage 4 [parallel, max ${PARALLEL}]: Deep Reasoning
  bash scripts/db-write.sh task-start TASK-{N} ${RUN_ID}
  @deep-reasoner → specs/reasoning/TASK-{N}-reasoning.md  ← MUST write this file to disk
  GATE: Drift Detection Gate (Judge)

Stage 5 [parallel]: Skeptic Challenge
  @skeptic → specs/reasoning/TASK-{N}-skeptic.md  ← MUST write this file to disk

Stage 6: Blind Handoff (you do this, not an agent)
  For each surviving task: extract claim → specs/verification/TASK-{N}-claim.md
  The claim file contains ONLY: Hypothesis, Attack Path, Witness. NOT the full reasoning.

Stage 7 [parallel]: Verification + Fuzzing
  Phase 3 tasks:  @verifier only
  Phase 4+ tasks: @verifier + @fuzzer running in parallel
  → specs/verification/TASK-{N}-verification.md  ← MUST write this file to disk
  → specs/verification/TASK-{N}-fuzz-{tool}.md   (for phase 4+ tasks)
  GATE: Evidence Gate — 10 gates (G1-G10, Judge)

Stage 8: Economic Analysis (CONFIRMED findings only)
  @economic-analyst → specs/verification/TASK-{N}-economic.md

Stage 9: Cycle Completion
  bash scripts/check-pipeline-artifacts.sh --cycle N --run-id ${RUN_ID}
  bash scripts/update-dashboard.sh --run-id ${RUN_ID}

## After each cycle — loop control (mandatory):
  bash scripts/cycle-controller.sh --run-id ${RUN_ID} --cycle-number N
  → exit 0: converged — proceed to post-convergence
  → exit 1: not done — run bash scripts/auto-evolve.sh, then start next cycle

  Before convergence also run:
  bash scripts/check-coverage.sh --run-id ${RUN_ID}
  → exit 0: coverage sufficient
  → exit 1: more cycles needed

## After convergence:
  @deduplicator    → findings/DEDUP-REPORT.md
  @report-compiler → findings/EXECUTIVE-SUMMARY.md
  @harness-critic  → specs/evolution/harness-critique-latest.md
  bash scripts/auto-evolve.sh --run-id ${RUN_ID}
  bash scripts/db-write.sh run-complete ${RUN_ID}
  bash scripts/update-dashboard.sh --run-id ${RUN_ID}

## Rules — do not break these:
- Do NOT stop after cycle 1. cycle-controller.sh is the only authority on when to stop.
- Do NOT skip writing reasoning artifacts to disk. Missing = pipeline incomplete.
- Do NOT let the Verifier read reasoning.md. It reads ONLY claim.md.
- Do NOT default all tasks to phase 3. At least ${MIN_PHASE4} must be phase 4+.
- Do NOT declare convergence without cycle-controller.sh exiting 0.
PROMPT

echo ""
echo -e "${BOLD}${CYAN}${SEP}${NC}"
echo ""
echo -e "${BOLD}Monitor while it runs:${NC}"
echo "  watch -n 10 cat findings/DASHBOARD.md"
echo "  bash scripts/check-pipeline-artifacts.sh --cycle 1"
if command -v sqlite3 &>/dev/null && [ -f "$DB_PATH" ]; then
  echo "  sqlite3 db/saw.db 'SELECT * FROM v_run_summary;'"
fi
echo ""
echo -e "${GREEN}${BOLD}✓ Ready. Copy the prompt above and paste it into Codex or Claude Code.${NC}"
