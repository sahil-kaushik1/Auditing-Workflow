#!/usr/bin/env bash
# =============================================================================
# scripts/check-pipeline-artifacts.sh — Pipeline Artifact Health Check
# =============================================================================
# Called by the Orchestrator before declaring a cycle complete or converged.
# Checks that all expected Stage 3 artifacts exist for the given cycle.
#
# Usage:
#   bash scripts/check-pipeline-artifacts.sh --cycle N [--run-id <run-id>]
#   Exit 0: all artifacts present
#   Exit 1: missing artifacts detected (prints list)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"

CYCLE_NUMBER=1
RUN_ID="${SAW_RUN_ID:-unknown}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cycle)  CYCLE_NUMBER="$2"; shift 2 ;;
    --run-id) RUN_ID="$2";       shift 2 ;;
    *) shift ;;
  esac
done

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

MISSING_COUNT=0
WARN_COUNT=0

echo -e "${BOLD}=== Pipeline Artifact Check — Cycle ${CYCLE_NUMBER} ===${NC}"
echo ""

# ── Get task list ─────────────────────────────────────────────────────────────
TASK_FILES=($(ls "${HARNESS_ROOT}/specs/tasks/TASK-"*.md 2>/dev/null | sort -V || true))
TOTAL_TASKS=${#TASK_FILES[@]}

if [ "$TOTAL_TASKS" -eq 0 ]; then
  echo -e "${YELLOW}⚠ No task files found. Has the Threat Modeler run yet?${NC}"
  exit 1
fi

echo "Tasks found: ${TOTAL_TASKS}"
echo ""

# ── Check each task ───────────────────────────────────────────────────────────
for task_file in "${TASK_FILES[@]}"; do
  task_base=$(basename "$task_file" .md)
  task_id=$(echo "$task_base" | grep -oP 'TASK-\d+' | head -1 || echo "$task_base")

  # Extract numeric part
  task_num=$(echo "$task_id" | grep -oP '\d+' | head -1 || echo "000")

  # Expected artifacts
  context_file="${HARNESS_ROOT}/specs/context/${task_id}-context.md"
  reasoning_file="${HARNESS_ROOT}/specs/reasoning/${task_id}-reasoning.md"
  skeptic_file="${HARNESS_ROOT}/specs/reasoning/${task_id}-skeptic.md"
  claim_file="${HARNESS_ROOT}/specs/verification/${task_id}-claim.md"
  verification_file="${HARNESS_ROOT}/specs/verification/${task_id}-verification.md"
  skills_file="${HARNESS_ROOT}/specs/skills-loaded/${task_id}-skills.txt"

  task_missing=0
  echo -n "  ${task_id}: "

  # Context (warning, not error — may be skipped for small projects)
  if [ ! -f "$context_file" ]; then
    WARN_COUNT=$((WARN_COUNT + 1))
    echo -n "[no-ctx] "
  fi

  # Skills loaded (warning)
  if [ ! -f "$skills_file" ]; then
    WARN_COUNT=$((WARN_COUNT + 1))
    echo -n "[no-skills] "
  fi

  # Reasoning (ERROR — required)
  if [ ! -f "$reasoning_file" ]; then
    MISSING_COUNT=$((MISSING_COUNT + 1))
    task_missing=$((task_missing + 1))
    echo -n "[MISSING-REASONING] "
  fi

  # Skeptic review (ERROR if reasoning exists)
  if [ -f "$reasoning_file" ] && [ ! -f "$skeptic_file" ]; then
    MISSING_COUNT=$((MISSING_COUNT + 1))
    task_missing=$((task_missing + 1))
    echo -n "[MISSING-SKEPTIC] "
  fi

  # Claim file (blind handoff) — ERROR if skeptic passed
  if [ -f "$skeptic_file" ] && [ ! -f "$claim_file" ]; then
    MISSING_COUNT=$((MISSING_COUNT + 1))
    task_missing=$((task_missing + 1))
    echo -n "[MISSING-CLAIM] "
  fi

  # Verification — ERROR if claim exists
  if [ -f "$claim_file" ] && [ ! -f "$verification_file" ]; then
    MISSING_COUNT=$((MISSING_COUNT + 1))
    task_missing=$((task_missing + 1))
    echo -n "[MISSING-VERIFICATION] "
  fi

  if [ "$task_missing" -eq 0 ]; then
    echo -e "${GREEN}✓${NC}"
  else
    echo -e "${RED}✗ (${task_missing} missing)${NC}"
  fi
done

echo ""
echo "─────────────────────────────────"
echo -e "Missing artifacts: ${MISSING_COUNT}"
echo -e "Warnings (non-blocking): ${WARN_COUNT}"
echo ""

if [ "$MISSING_COUNT" -gt 0 ]; then
  echo -e "${RED}${BOLD}PIPELINE INCOMPLETE — ${MISSING_COUNT} required artifacts missing.${NC}"
  echo "The Orchestrator MUST NOT declare this cycle complete until these are written."
  echo ""
  echo "Common fixes:"
  echo "  - Re-dispatch Deep Reasoner for tasks missing reasoning artifacts"
  echo "  - Re-run blind handoff for tasks with reasoning but no claim file"
  echo "  - Re-dispatch Verifier for tasks with claim but no verification"
  exit 1
else
  echo -e "${GREEN}${BOLD}PIPELINE COMPLETE — all required artifacts present.${NC}"
  # Write the cycle-complete signal
  mkdir -p "${HARNESS_ROOT}/specs/cycles"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${HARNESS_ROOT}/specs/cycles/CYCLE-${CYCLE_NUMBER}-COMPLETE.txt"
  echo "Written: specs/cycles/CYCLE-${CYCLE_NUMBER}-COMPLETE.txt"
  exit 0
fi
