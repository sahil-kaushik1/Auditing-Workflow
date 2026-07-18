#!/usr/bin/env bash
# =============================================================================
# scripts/cycle-controller.sh — Hard Loop Enforcement
# =============================================================================
# Called by the Orchestrator after every cycle to determine whether to
# continue running or stop. Returns exit code 0 = STOP, 1 = CONTINUE.
#
# Usage:
#   bash scripts/cycle-controller.sh --run-id <run-id> --cycle-number <N>
#   Exit 0: converged, stop the loop
#   Exit 1: not converged, run another cycle
#
# The orchestrator MUST call this script and respect its exit code.
# The orchestrator MUST NOT declare completion unless this script exits 0.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="${HARNESS_ROOT}/db/saw.db"
CONFIG_FILE="${HARNESS_ROOT}/audit.config.yml"

RUN_ID=""
CYCLE_NUMBER=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)       RUN_ID="$2";       shift 2 ;;
    --cycle-number) CYCLE_NUMBER="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "$RUN_ID" ] && RUN_ID="${SAW_RUN_ID:-unknown}"

# ── Read config ───────────────────────────────────────────────────────────────
MAX_CYCLES=$(grep 'max_cycles:' "$CONFIG_FILE" | grep -oP '\d+' | head -1 2>/dev/null || echo "6")
MIN_CYCLES=$(grep 'min_cycles:' "$CONFIG_FILE" | grep -oP '\d+' | head -1 2>/dev/null || echo "3")
CONV_THRESHOLD=$(grep 'convergence_threshold:' "$CONFIG_FILE" | grep -oP '[0-9.]+' | head -1 2>/dev/null || echo "0.3")
MIN_FLOW_COV=$(grep 'min_flow_coverage_ratio:' "$CONFIG_FILE" | grep -oP '[0-9.]+' | head -1 2>/dev/null || echo "0.8")
REQUIRE_ARTIFACTS=$(grep 'require_reasoning_artifacts:' "$CONFIG_FILE" | grep -oP 'true|false' | head -1 2>/dev/null || echo "true")

echo "=== Cycle Controller ==="
echo "Run ID:           ${RUN_ID}"
echo "Cycle:            ${CYCLE_NUMBER}"
echo "Max cycles:       ${MAX_CYCLES}"
echo "Min cycles:       ${MIN_CYCLES}"
echo "Conv. threshold:  ${CONV_THRESHOLD}"
echo "Min flow coverage: ${MIN_FLOW_COV}"
echo ""

# ── Check 1: Minimum cycles ────────────────────────────────────────────────
if [ "$CYCLE_NUMBER" -lt "$MIN_CYCLES" ]; then
  echo "DECISION: CONTINUE — minimum cycle count (${MIN_CYCLES}) not reached. Current: ${CYCLE_NUMBER}."
  exit 1
fi

# ── Check 2: Maximum cycles ────────────────────────────────────────────────
if [ "$CYCLE_NUMBER" -ge "$MAX_CYCLES" ]; then
  echo "DECISION: STOP — maximum cycle count (${MAX_CYCLES}) reached."
  exit 0
fi

# ── Check 3: Reasoning artifacts exist ────────────────────────────────────
if [ "$REQUIRE_ARTIFACTS" = "true" ]; then
  TASK_COUNT=$(ls "${HARNESS_ROOT}/specs/tasks/TASK-"*.md 2>/dev/null | wc -l | tr -d ' ')
  REASONING_COUNT=$(ls "${HARNESS_ROOT}/specs/reasoning/TASK-"*"-reasoning.md" 2>/dev/null | wc -l | tr -d ' ')
  VERIFICATION_COUNT=$(ls "${HARNESS_ROOT}/specs/verification/TASK-"*"-verification.md" 2>/dev/null | wc -l | tr -d ' ')

  echo "Tasks:        ${TASK_COUNT}"
  echo "Reasoning:    ${REASONING_COUNT}"
  echo "Verification: ${VERIFICATION_COUNT}"

  if [ "$TASK_COUNT" -gt 0 ] && [ "$REASONING_COUNT" -lt "$TASK_COUNT" ]; then
    MISSING=$((TASK_COUNT - REASONING_COUNT))
    echo "DECISION: CONTINUE — ${MISSING} reasoning artifacts missing. Pipeline incomplete."
    exit 1
  fi
fi

# ── Check 4: Flow coverage ─────────────────────────────────────────────────
if [ -f "$DB_PATH" ]; then
  TOTAL_FLOWS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM flows WHERE run_id='${RUN_ID}';" 2>/dev/null || echo "0")
  COVERED_FLOWS=$(sqlite3 "$DB_PATH" "
    SELECT COUNT(DISTINCT flow_id) FROM tasks
    WHERE run_id='${RUN_ID}' AND flow_id IS NOT NULL
    AND verdict IN ('CONFIRMED','REFUTED','INCONCLUSIVE');
  " 2>/dev/null || echo "0")

  echo "Total flows:   ${TOTAL_FLOWS}"
  echo "Covered flows: ${COVERED_FLOWS}"

  if [ "$TOTAL_FLOWS" -gt 0 ]; then
    COVERAGE_RATIO=$(python3 -c "print(round(${COVERED_FLOWS} / ${TOTAL_FLOWS}, 3))" 2>/dev/null || echo "0")
    echo "Coverage ratio: ${COVERAGE_RATIO} (min required: ${MIN_FLOW_COV})"

    if python3 -c "exit(0 if float('${COVERAGE_RATIO}') < float('${MIN_FLOW_COV}') else 1)" 2>/dev/null; then
      echo "DECISION: CONTINUE — flow coverage ${COVERAGE_RATIO} < minimum ${MIN_FLOW_COV}."
      exit 1
    fi
  fi
fi

# ── Check 5: Gap analysis score ────────────────────────────────────────────
LATEST_GAP=$(ls "${HARNESS_ROOT}/specs/cycles/GAP-ANALYSIS-"*.md 2>/dev/null | sort -V | tail -1 || echo "")
if [ -n "$LATEST_GAP" ]; then
  # Extract the highest gap score from the gap analysis (look for a numeric score line)
  MAX_GAP=$(grep -oP 'score:\s*\K[0-9.]+' "$LATEST_GAP" 2>/dev/null | sort -rn | head -1 || echo "1.0")
  echo "Max gap score: ${MAX_GAP} (convergence threshold: ${CONV_THRESHOLD})"

  if python3 -c "exit(0 if float('${MAX_GAP}') > float('${CONV_THRESHOLD}') else 1)" 2>/dev/null; then
    echo "DECISION: CONTINUE — gap score ${MAX_GAP} > threshold ${CONV_THRESHOLD}."
    exit 1
  fi
fi

# ── All checks passed — converged ──────────────────────────────────────────
echo "DECISION: STOP — all convergence criteria met after ${CYCLE_NUMBER} cycles."
exit 0
