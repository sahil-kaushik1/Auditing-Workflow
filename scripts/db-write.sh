#!/usr/bin/env bash
# =============================================================================
# scripts/db-write.sh — Agent DB Write Wrapper
# =============================================================================
# Provides simple sub-commands for all agents to write to saw.db without
# embedding raw SQL in every agent definition file.
#
# Usage:
#   bash scripts/db-write.sh task-start    <task_id> [run_id]
#   bash scripts/db-write.sh task-complete <task_id> <verdict> <severity> <cost_usd> <tokens_used>
#   bash scripts/db-write.sh task-status   <task_id> <status>
#   bash scripts/db-write.sh finding-add   <finding_id> <task_id> <severity> <title>
#   bash scripts/db-write.sh import-tasks  <index_file> [run_id]
#   bash scripts/db-write.sh import-flows  <index_file> [run_id]
#   bash scripts/db-write.sh run-complete  [run_id]
#   bash scripts/db-write.sh fp-add        <pattern> <reason> <keywords> [task_id]
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="${HARNESS_ROOT}/db/saw.db"

COMMAND="${1:-help}"
shift || true

RUN_ID="${SAW_RUN_ID:-unknown}"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Gracefully skip if DB not initialized
if [ ! -f "$DB_PATH" ] && [ "$COMMAND" != "help" ]; then
  echo "⚠ db-write.sh: DB not found at ${DB_PATH}. Skipping write (run db/init.sh first)."
  exit 0
fi

sq() { sqlite3 "$DB_PATH" "$1" 2>/dev/null || true; }

case "$COMMAND" in

  task-start)
    TASK_ID="${1:-}"; shift || true
    RUN_ID_ARG="${1:-$RUN_ID}"; shift || true
    sq "UPDATE tasks SET status='reasoning', started_at='${NOW}' WHERE task_id='${TASK_ID}';"
    # Insert if not exists
    sq "INSERT OR IGNORE INTO tasks (task_id, run_id, priority, phase, target, status, created_at)
        VALUES ('${TASK_ID}', '${RUN_ID_ARG}', 'High', '3-foundry-unit', '${TASK_ID}', 'reasoning', '${NOW}');"
    echo "✓ DB: task-start ${TASK_ID}"
    ;;

  task-complete)
    TASK_ID="${1:-}"; shift || true
    VERDICT="${1:-INCONCLUSIVE}"; shift || true
    SEVERITY="${1:-}"; shift || true
    COST="${1:-0}"; shift || true
    TOKENS="${1:-0}"; shift || true
    sq "UPDATE tasks SET
          verdict='${VERDICT}',
          severity='${SEVERITY}',
          cost_usd=${COST},
          tokens_used=${TOKENS},
          status='done',
          completed_at='${NOW}'
        WHERE task_id='${TASK_ID}';"
    sq "UPDATE runs SET
          total_cost_usd = total_cost_usd + ${COST},
          total_tokens = total_tokens + ${TOKENS}
        WHERE run_id='${RUN_ID}';"
    echo "✓ DB: task-complete ${TASK_ID} verdict=${VERDICT} severity=${SEVERITY}"
    ;;

  task-status)
    TASK_ID="${1:-}"; shift || true
    STATUS="${1:-pending}"; shift || true
    sq "UPDATE tasks SET status='${STATUS}' WHERE task_id='${TASK_ID}';"
    echo "✓ DB: task-status ${TASK_ID} → ${STATUS}"
    ;;

  finding-add)
    FINDING_ID="${1:-}"; shift || true
    TASK_ID="${1:-}"; shift || true
    SEVERITY="${1:-High}"; shift || true
    TITLE="${1:-Untitled Finding}"; shift || true
    sq "INSERT OR IGNORE INTO findings
          (finding_id, run_id, task_id, severity, title, created_at)
        VALUES
          ('${FINDING_ID}', '${RUN_ID}', '${TASK_ID}', '${SEVERITY}',
           '${TITLE}', '${NOW}');"
    echo "✓ DB: finding-add ${FINDING_ID} severity=${SEVERITY}"
    ;;

  import-tasks)
    INDEX_FILE="${1:-specs/tasks/INDEX.md}"; shift || true
    RUN_ID_ARG="${1:-$RUN_ID}"; shift || true
    # Parse task lines from INDEX.md: | TASK-NNN | ... |
    if [ -f "${HARNESS_ROOT}/${INDEX_FILE}" ]; then
      grep '| TASK-' "${HARNESS_ROOT}/${INDEX_FILE}" 2>/dev/null | while IFS='|' read -r _ tid target invariant priority _rest; do
        tid=$(echo "$tid" | tr -d ' ')
        target=$(echo "$target" | tr -d ' ')
        priority=$(echo "$priority" | tr -d ' ' | grep -oE 'Critical|High|Medium|Low' || echo "High")
        [ -z "$tid" ] && continue
        sq "INSERT OR IGNORE INTO tasks
              (task_id, run_id, priority, phase, target, status, created_at)
            VALUES
              ('${tid}', '${RUN_ID_ARG}', '${priority}', '3-foundry-unit',
               '${target}', 'pending', '${NOW}');"
      done
      echo "✓ DB: import-tasks from ${INDEX_FILE}"
    else
      echo "⚠ DB: import-tasks — index file not found: ${INDEX_FILE}"
    fi
    ;;

  import-flows)
    INDEX_FILE="${1:-specs/flows/FLOW-INDEX.md}"; shift || true
    RUN_ID_ARG="${1:-$RUN_ID}"; shift || true
    if [ -f "${HARNESS_ROOT}/${INDEX_FILE}" ]; then
      grep '| FLOW-' "${HARNESS_ROOT}/${INDEX_FILE}" 2>/dev/null | while IFS='|' read -r _ fid ftype score _rest; do
        fid=$(echo "$fid" | tr -d ' ')
        ftype=$(echo "$ftype" | tr -d ' ')
        score=$(echo "$score" | grep -oP '[0-9.]+' | head -1 || echo "0.5")
        [ -z "$fid" ] && continue
        sq "INSERT OR IGNORE INTO flows
              (flow_id, run_id, flow_type, economic_risk_score, created_at)
            VALUES
              ('${fid}', '${RUN_ID_ARG}', '${ftype}', ${score}, '${NOW}');"
      done
      echo "✓ DB: import-flows from ${INDEX_FILE}"
    else
      echo "⚠ DB: import-flows — index file not found: ${INDEX_FILE}"
    fi
    ;;

  run-complete)
    RUN_ID_ARG="${1:-$RUN_ID}"; shift || true
    sq "UPDATE runs SET status='complete', completed_at='${NOW}' WHERE run_id='${RUN_ID_ARG}';"
    echo "✓ DB: run-complete ${RUN_ID_ARG}"
    ;;

  fp-add)
    PATTERN="${1:-}"; shift || true
    REASON="${1:-}"; shift || true
    KEYWORDS="${1:-}"; shift || true
    TASK_ID_ARG="${1:-}"; shift || true
    FP_ID="AUTO-$(date +%s)"
    HASH=$(echo "${PATTERN}${REASON}" | sha256sum | cut -c1-16 || echo "unknown")
    sq "INSERT OR IGNORE INTO false_positives
          (fp_id, run_id, task_id, pattern_hash, apparent_vuln, why_false_positive,
           detection_keywords, added_by, added_at)
        VALUES
          ('${FP_ID}', '${RUN_ID}', '${TASK_ID_ARG}', '${HASH}',
           '${PATTERN}', '${REASON}', '${KEYWORDS}', 'auto', '${NOW}');"
    # Also append to jsonl file
    echo "{\"id\":\"${FP_ID}\",\"pattern\":\"${PATTERN}\",\"why_false_positive\":\"${REASON}\",\"detection_keywords\":[${KEYWORDS}],\"added_at\":\"${NOW}\"}" \
      >> "${HARNESS_ROOT}/memory/negative/false-positives.jsonl"
    echo "✓ DB: fp-add ${FP_ID}"
    ;;

  help|*)
    echo "Usage: bash scripts/db-write.sh <command> [args...]"
    echo ""
    echo "Commands:"
    echo "  task-start    <task_id> [run_id]"
    echo "  task-complete <task_id> <verdict> <severity> <cost_usd> <tokens_used>"
    echo "  task-status   <task_id> <status>"
    echo "  finding-add   <finding_id> <task_id> <severity> <title>"
    echo "  import-tasks  <index_file> [run_id]"
    echo "  import-flows  <index_file> [run_id]"
    echo "  run-complete  [run_id]"
    echo "  fp-add        <pattern> <reason> <keywords_csv> [task_id]"
    ;;
esac
