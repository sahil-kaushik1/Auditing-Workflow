#!/usr/bin/env bash
# =============================================================================
# scripts/check-coverage.sh — Pre-Convergence Coverage Validator
# =============================================================================
# Ensures that enough flows have been analyzed before the Orchestrator
# is allowed to declare the audit converged.
#
# Usage:
#   bash scripts/check-coverage.sh --run-id <run-id> [--min-flow-coverage 0.8]
#   Exit 0: coverage threshold met
#   Exit 1: coverage insufficient, must run more cycles
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="${HARNESS_ROOT}/db/saw.db"
CONFIG_FILE="${HARNESS_ROOT}/audit.config.yml"

RUN_ID="${SAW_RUN_ID:-unknown}"
MIN_COVERAGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)            RUN_ID="$2";       shift 2 ;;
    --min-flow-coverage) MIN_COVERAGE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "$MIN_COVERAGE" ] && \
  MIN_COVERAGE=$(grep 'min_flow_coverage_ratio:' "$CONFIG_FILE" | grep -oP '[0-9.]+' | head -1 2>/dev/null || echo "0.8")

echo "=== Coverage Check ==="
echo "Run ID:           ${RUN_ID}"
echo "Min coverage:     ${MIN_COVERAGE}"
echo ""

# ── Count filesystem artifacts as fallback ────────────────────────────────────
TASK_COUNT=$(ls "${HARNESS_ROOT}/specs/tasks/TASK-"*.md 2>/dev/null | wc -l | tr -d ' ')
FLOW_COUNT=$(ls "${HARNESS_ROOT}/specs/flows/FLOW-"*.md 2>/dev/null | grep -v 'INDEX' | wc -l | tr -d ' ')
VERIFIED_COUNT=$(ls "${HARNESS_ROOT}/specs/verification/TASK-"*"-verification.md" 2>/dev/null | wc -l | tr -d ' ')
REASONING_COUNT=$(ls "${HARNESS_ROOT}/specs/reasoning/TASK-"*"-reasoning.md" 2>/dev/null | wc -l | tr -d ' ')

echo "Task files:             ${TASK_COUNT}"
echo "Flow files:             ${FLOW_COUNT}"
echo "Reasoning artifacts:    ${REASONING_COUNT}"
echo "Verification artifacts: ${VERIFIED_COUNT}"
echo ""

# ── Artifact coverage check ───────────────────────────────────────────────────
if [ "$TASK_COUNT" -gt 0 ] && [ "$REASONING_COUNT" -lt "$TASK_COUNT" ]; then
  MISSING=$((TASK_COUNT - REASONING_COUNT))
  echo "❌ COVERAGE INSUFFICIENT: ${MISSING} tasks have no reasoning artifact."
  echo "   Must complete all reasoning passes before convergence."
  exit 1
fi

# ── DB-based flow coverage check ──────────────────────────────────────────────
if [ -f "$DB_PATH" ]; then
  TOTAL_FLOWS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM flows WHERE run_id='${RUN_ID}';" 2>/dev/null || echo "0")
  COVERED_FLOWS=$(sqlite3 "$DB_PATH" "
    SELECT COUNT(DISTINCT t.flow_id) FROM tasks t
    WHERE t.run_id='${RUN_ID}' AND t.flow_id IS NOT NULL
    AND t.verdict IN ('CONFIRMED','REFUTED','INCONCLUSIVE');
  " 2>/dev/null || echo "0")

  echo "DB: Total flows:   ${TOTAL_FLOWS}"
  echo "DB: Covered flows: ${COVERED_FLOWS}"

  if [ "$TOTAL_FLOWS" -gt 0 ]; then
    RATIO=$(python3 -c "print(round(${COVERED_FLOWS}/${TOTAL_FLOWS},3))" 2>/dev/null || echo "0")
    echo "DB: Coverage ratio: ${RATIO} (required: ${MIN_COVERAGE})"

    if python3 -c "exit(0 if float('${RATIO}') < float('${MIN_COVERAGE}') else 1)" 2>/dev/null; then
      echo ""
      echo "❌ COVERAGE INSUFFICIENT: ${RATIO} < ${MIN_COVERAGE} required."
      echo "   Run more gap cycles before declaring convergence."
      exit 1
    fi
  fi
fi

# ── Filesystem-based flow coverage fallback ────────────────────────────────────
if [ "$FLOW_COUNT" -gt 0 ] && [ "$TASK_COUNT" -gt 0 ]; then
  # Rough check: at least 1 task per flow on average
  RATIO=$(python3 -c "print(round(min(${TASK_COUNT}/${FLOW_COUNT},1.0),3))" 2>/dev/null || echo "0")
  echo "Filesystem task/flow ratio: ${RATIO}"

  if python3 -c "exit(0 if float('${RATIO}') < float('${MIN_COVERAGE}') else 1)" 2>/dev/null; then
    echo ""
    echo "❌ COVERAGE INSUFFICIENT (filesystem check): ratio ${RATIO} < ${MIN_COVERAGE}."
    exit 1
  fi
fi

echo ""
echo "✅ COVERAGE SUFFICIENT — convergence check passed."
exit 0
