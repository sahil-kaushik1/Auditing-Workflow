#!/usr/bin/env bash
# =============================================================================
# scripts/update-dashboard.sh — Live Dashboard Updater
# =============================================================================
# Called by the Orchestrator after every task completion.
# Reads from db/saw.db and regenerates findings/DASHBOARD.md.
#
# Usage:
#   bash scripts/update-dashboard.sh --run-id <run-id>
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="${HARNESS_ROOT}/db/saw.db"
FINDINGS_DIR="${HARNESS_ROOT}/findings"

RUN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id) RUN_ID="$2"; shift 2 ;;
    *) shift ;;
  esac
done

[ -z "$RUN_ID" ] && RUN_ID="${SAW_RUN_ID:-unknown}"

mkdir -p "$FINDINGS_DIR"
DASHBOARD="${FINDINGS_DIR}/DASHBOARD.md"

# ── Pull stats from DB (graceful fallback if DB missing) ──────────────────

if [ -f "$DB_PATH" ]; then
  TOTAL_TASKS=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE run_id='${RUN_ID}';" 2>/dev/null || echo "0")
  PENDING=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE run_id='${RUN_ID}' AND status='pending';" 2>/dev/null || echo "0")
  REASONING=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE run_id='${RUN_ID}' AND status='reasoning';" 2>/dev/null || echo "0")
  VERIFYING=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE run_id='${RUN_ID}' AND status='verifying';" 2>/dev/null || echo "0")
  DONE=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE run_id='${RUN_ID}' AND status='done';" 2>/dev/null || echo "0")
  CONFIRMED=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE run_id='${RUN_ID}' AND verdict='CONFIRMED';" 2>/dev/null || echo "0")
  REFUTED=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE run_id='${RUN_ID}' AND verdict='REFUTED';" 2>/dev/null || echo "0")
  INCONCLUSIVE=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE run_id='${RUN_ID}' AND verdict='INCONCLUSIVE';" 2>/dev/null || echo "0")
  CRITICAL=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE run_id='${RUN_ID}' AND severity='Critical' AND is_duplicate=0;" 2>/dev/null || echo "0")
  HIGH=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE run_id='${RUN_ID}' AND severity='High' AND is_duplicate=0;" 2>/dev/null || echo "0")
  MEDIUM=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE run_id='${RUN_ID}' AND severity='Medium' AND is_duplicate=0;" 2>/dev/null || echo "0")
  LOW=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM findings WHERE run_id='${RUN_ID}' AND severity='Low' AND is_duplicate=0;" 2>/dev/null || echo "0")
  TOTAL_COST=$(sqlite3 "$DB_PATH" "SELECT ROUND(total_cost_usd,4) FROM runs WHERE run_id='${RUN_ID}';" 2>/dev/null || echo "0.0000")
  OVER_BUDGET=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE run_id='${RUN_ID}' AND tokens_used > budget_tokens;" 2>/dev/null || echo "0")

  # Flow coverage
  FLOW_COVERAGE=$(sqlite3 "$DB_PATH" "
    SELECT COUNT(DISTINCT flow_id) || '/' || (SELECT COUNT(*) FROM flows WHERE run_id='${RUN_ID}')
    FROM tasks WHERE run_id='${RUN_ID}' AND flow_id IS NOT NULL AND verdict IN ('CONFIRMED','REFUTED','INCONCLUSIVE');
  " 2>/dev/null || echo "?/?")

  MODE_VAL=$(sqlite3 "$DB_PATH" "SELECT mode FROM runs WHERE run_id='${RUN_ID}';" 2>/dev/null || echo "unknown")
  PROTOCOL_VAL=$(sqlite3 "$DB_PATH" "SELECT protocol FROM runs WHERE run_id='${RUN_ID}';" 2>/dev/null || echo "unknown")
  STARTED_AT=$(sqlite3 "$DB_PATH" "SELECT started_at FROM runs WHERE run_id='${RUN_ID}';" 2>/dev/null || echo "unknown")
  STATUS_VAL=$(sqlite3 "$DB_PATH" "SELECT status FROM runs WHERE run_id='${RUN_ID}';" 2>/dev/null || echo "running")
else
  # DB not available — count from filesystem
  TOTAL_TASKS=$(ls "${HARNESS_ROOT}/specs/tasks/TASK-"*.md 2>/dev/null | wc -l | tr -d ' ')
  CONFIRMED=$(ls "${HARNESS_ROOT}/findings/FINDING-"*.md 2>/dev/null | wc -l | tr -d ' ')
  PENDING="?"; REASONING="?"; VERIFYING="?"; DONE="?"; REFUTED="?"; INCONCLUSIVE="?"
  CRITICAL="?"; HIGH="?"; MEDIUM="?"; LOW="?"; OVER_BUDGET="0"; TOTAL_COST="0.0000"
  FLOW_COVERAGE="?/?"; MODE_VAL="unknown"; PROTOCOL_VAL="unknown"
  STARTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"; STATUS_VAL="running"
fi

# ── Count cycles ──────────────────────────────────────────────────────────────
CYCLES_DONE=$(ls "${HARNESS_ROOT}/specs/cycles/CYCLE-"*"-COMPLETE.txt" 2>/dev/null | wc -l | tr -d ' ')
CYCLES_STARTED=$(ls "${HARNESS_ROOT}/specs/cycles/CYCLE-"*"-STARTED.txt" 2>/dev/null | wc -l | tr -d ' ')

# ── Status emoji ─────────────────────────────────────────────────────────────
case "$STATUS_VAL" in
  running)  STATUS_ICON="🟡" ;;
  complete) STATUS_ICON="🟢" ;;
  failed)   STATUS_ICON="🔴" ;;
  *)        STATUS_ICON="⚪" ;;
esac

# ── Write dashboard ───────────────────────────────────────────────────────────
cat > "$DASHBOARD" << DASH
# Audit Dashboard — ${PROTOCOL_VAL}

**Run ID**: \`${RUN_ID}\`
**Mode**: ${MODE_VAL}
**Status**: ${STATUS_ICON} ${STATUS_VAL^^}
**Started**: ${STARTED_AT}
**Last Updated**: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

---

## Cycle Progress
| Cycles Started | Cycles Complete |
|---------------|----------------|
| ${CYCLES_STARTED} | ${CYCLES_DONE} |

## Budget
| Total Cost | Over-Budget Tasks |
|-----------|-----------------|
| \$${TOTAL_COST} | ${OVER_BUDGET} |

## Findings
| Severity | Confirmed | Candidates |
|---------|-----------|-----------|
| Critical | ${CRITICAL} | 0 |
| High     | ${HIGH}     | 0 |
| Medium   | ${MEDIUM}   | 0 |
| Low      | ${LOW}      | 0 |

## Task Progress
| Status      | Count |
|-------------|-------|
| Pending     | ${PENDING} |
| Reasoning   | ${REASONING} |
| Verifying   | ${VERIFYING} |
| Done        | ${DONE} |
| **Total**   | **${TOTAL_TASKS}** |

## Verdicts
| Confirmed | Refuted | Inconclusive |
|-----------|---------|--------------|
| ${CONFIRMED} | ${REFUTED} | ${INCONCLUSIVE} |

## Flow Coverage
${FLOW_COVERAGE} flows have at least one resolved task.

## Artifact Health
$([ -d "${HARNESS_ROOT}/specs/reasoning" ] && ls "${HARNESS_ROOT}/specs/reasoning/TASK-"*"-reasoning.md" 2>/dev/null | wc -l | tr -d ' ' || echo "0") reasoning artifacts
$([ -d "${HARNESS_ROOT}/specs/verification" ] && ls "${HARNESS_ROOT}/specs/verification/TASK-"*"-verification.md" 2>/dev/null | wc -l | tr -d ' ' || echo "0") verification artifacts
$([ -d "${HARNESS_ROOT}/specs/verification" ] && ls "${HARNESS_ROOT}/specs/verification/TASK-"*"-claim.md" 2>/dev/null | wc -l | tr -d ' ' || echo "0") blind-handoff claim files

## Human Review Queue
$(ls "${HARNESS_ROOT}/findings/FINDING-"*.md 2>/dev/null | while read f; do echo "- [ ] $(basename $f)"; done || echo "(empty)")
DASH

echo "✅ Dashboard updated: $DASHBOARD"
