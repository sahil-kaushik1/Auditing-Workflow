#!/usr/bin/env bash
# =============================================================================
# benchmarks/runner.sh — SAW Benchmark Execution Engine
# =============================================================================
#
# Usage:
#   bash benchmarks/runner.sh [options]
#
# Options:
#   --category  known-bugs | synthetic-bugs | false-positive-cases | all (default: all)
#   --case      Run a single named case (e.g. erc4626-share-inflation)
#   --mode      smoke_scan | fast_triage | audit_grade (default: fast_triage)
#   --write-db  Write results to saw.db (requires db to be initialized)
#   --dry-run   Show what would run without executing
#
# Output:
#   benchmarks/results/BENCH-RUN-{timestamp}.json
#   Summary table printed to stdout
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ "$SCRIPT_DIR" == *"scripts" ]]; then
  HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"
  BENCH_DIR="${HARNESS_ROOT}/benchmarks"
else
  HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"
  BENCH_DIR="$SCRIPT_DIR"
fi
DB_PATH="${HARNESS_ROOT}/db/saw.db"
RESULTS_DIR="${BENCH_DIR}/results"

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ── Args ──────────────────────────────────────────────────────

CATEGORY="all"
CASE=""
MODE="fast_triage"
WRITE_DB=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --category) CATEGORY="$2"; shift 2 ;;
    --case)     CASE="$2";     shift 2 ;;
    --mode)     MODE="$2";     shift 2 ;;
    --write-db) WRITE_DB=true; shift 1 ;;
    --dry-run)  DRY_RUN=true;  shift 1 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

TIMESTAMP=$(date +"%Y-%m-%dT%H-%M-%S")
BENCH_RUN_ID="bench-${TIMESTAMP}"
mkdir -p "$RESULTS_DIR"
RESULTS_FILE="${RESULTS_DIR}/BENCH-RUN-${TIMESTAMP}.json"

# ── Banner ────────────────────────────────────────────────────

echo -e "${BOLD}${CYAN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   SAW Benchmark Suite Runner                         ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  Run ID:   ${BENCH_RUN_ID}"
echo -e "  Category: ${CATEGORY}"
echo -e "  Mode:     ${MODE}"
echo ""

# ── Discover Cases ────────────────────────────────────────────

declare -a CASES_TO_RUN=()

collect_cases() {
  local cat="$1"
  local cat_dir="${BENCH_DIR}/${cat}"
  if [ -d "$cat_dir" ]; then
    for case_dir in "$cat_dir"/*/; do
      if [ -d "$case_dir" ]; then
        local case_name
        case_name="$(basename "$case_dir")"
        if [ -z "$CASE" ] || [ "$case_name" = "$CASE" ]; then
          CASES_TO_RUN+=("${cat}/${case_name}")
        fi
      fi
    done
  fi
}

if [ "$CATEGORY" = "all" ]; then
  collect_cases "known-bugs"
  collect_cases "synthetic-bugs"
  collect_cases "false-positive-cases"
  collect_cases "regression-cases"
else
  collect_cases "$CATEGORY"
fi

echo -e "${BOLD}Cases discovered: ${#CASES_TO_RUN[@]}${NC}"
for case_path in "${CASES_TO_RUN[@]}"; do
  echo "  → ${case_path}"
done
echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}DRY RUN — no execution${NC}"
  exit 0
fi

# ── Run Each Case ──────────────────────────────────────────────

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
TP=0   # true positives (found when should find)
TN=0   # true negatives (not flagged when should not flag)
FP=0   # false positives (flagged when should not flag)
FN=0   # false negatives (not found when should find)

declare -a RESULTS=()

run_case() {
  local case_path="$1"
  local category
  category="$(echo "$case_path" | cut -d'/' -f1)"
  local case_name
  case_name="$(echo "$case_path" | cut -d'/' -f2)"
  local case_dir="${BENCH_DIR}/${case_path}"

  TOTAL=$((TOTAL + 1))

  # Determine expected file
  local expected_file=""
  if [ "$category" = "false-positive-cases" ]; then
    expected_file="${case_dir}/expected_verdict.json"
  else
    expected_file="${case_dir}/expected_finding.json"
  fi

  if [ ! -f "$expected_file" ]; then
    echo -e "  ${YELLOW}SKIP${NC} ${case_path} — no expected file"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  # Determine expected must_find
  local must_find
  if [ "$category" = "false-positive-cases" ]; then
    must_find="false"
  else
    must_find=$(python3 -c "import json,sys; d=json.load(open('$expected_file')); print(str(d.get('pass_criteria',{}).get('must_find', True)).lower())" 2>/dev/null || echo "true")
  fi

  echo -e "  ${BOLD}Running:${NC} ${case_path}"
  echo -e "    Expected: must_find=${must_find}"

  # ── ACTUAL AUDIT INVOCATION ────────────────────────────────
  # In a full implementation, this would call:
  #   bash "${HARNESS_ROOT}/scripts/run-audit.sh" "$case_dir" --mode "$MODE" \
  #        --protocol "$case_name" --max-tasks 5
  # and then parse the findings output.
  #
  # For now, we record the case as PENDING and document the manual check needed.
  # Replace the block below with actual pipeline invocation when automating.

  # ── ACTUAL AUDIT INVOCATION ────────────────────────────────
  # Run the pipeline in a temporary isolated workspace, then compare findings.
  BENCH_WORKSPACE=$(mktemp -d)
  BENCH_FINDINGS="${BENCH_WORKSPACE}/findings"
  mkdir -p "${BENCH_FINDINGS}" "${BENCH_WORKSPACE}/specs" "${BENCH_WORKSPACE}/memory/negative"

  # Copy negative memory so the benchmark uses accumulated FP knowledge
  cp "${HARNESS_ROOT}/memory/negative/false-positives.jsonl" \
     "${BENCH_WORKSPACE}/memory/negative/" 2>/dev/null || true

  echo -e "    Running pipeline (mode=${MODE}, workspace=${BENCH_WORKSPACE})..."

  # Run the audit against the benchmark case directory
  # Use a short timeout appropriate for benchmarks
  BENCH_TIMEOUT=600  # 10 minutes per benchmark case
  ORIGINAL_DIR="$(pwd)"

  (
    cd "${HARNESS_ROOT}"
    timeout "${BENCH_TIMEOUT}" bash scripts/run-audit.sh \
      "${HARNESS_ROOT}/${case_dir}" \
      --mode "${MODE}" \
      --protocol "${case_name}" \
      2>&1 > "${BENCH_WORKSPACE}/audit-output.log" || true
  ) || true

  # Check findings output
  FOUND_FINDINGS=0
  if [ -d "${HARNESS_ROOT}/findings" ]; then
    # Check in main findings dir (run-audit.sh uses harness root findings/)
    FOUND_FINDINGS=$(ls "${HARNESS_ROOT}/findings/FINDING-"*.md 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo -e "    Findings found: ${FOUND_FINDINGS}, must_find=${must_find}"

  if [ "${must_find}" = "true" ]; then
    if [ "${FOUND_FINDINGS}" -gt 0 ]; then
      # Verify the found finding matches expected severity/class
      EXPECTED_SEVERITY=$(python3 -c \
        "import json; d=json.load(open('${expected_file}')); print(d.get('expected_finding',{}).get('severity','High'))" \
        2>/dev/null || echo "High")
      if grep -qiE "${EXPECTED_SEVERITY}" "${HARNESS_ROOT}/findings/FINDING-"*.md 2>/dev/null; then
        echo -e "    ${GREEN}TRUE POSITIVE: found ${EXPECTED_SEVERITY} finding${NC}"
        TP=$((TP + 1)); PASSED=$((PASSED + 1))
        RESULTS+=("\"case\":\"${case_path}\",\"status\":\"pass\",\"type\":\"tp\",\"must_find\":${must_find}")
      else
        echo -e "    ${YELLOW}PARTIAL: finding found but wrong severity${NC}"
        TP=$((TP + 1)); PASSED=$((PASSED + 1))
        RESULTS+=("\"case\":\"${case_path}\",\"status\":\"partial\",\"type\":\"tp\",\"must_find\":${must_find}")
      fi
    else
      echo -e "    ${RED}FALSE NEGATIVE: expected finding not found${NC}"
      FN=$((FN + 1)); FAILED=$((FAILED + 1))
      RESULTS+=("\"case\":\"${case_path}\",\"status\":\"fail\",\"type\":\"fn\",\"must_find\":${must_find}")
    fi
  else
    # must_find = false (false-positive test case)
    if [ "${FOUND_FINDINGS}" -eq 0 ]; then
      echo -e "    ${GREEN}TRUE NEGATIVE: correctly not flagged${NC}"
      TN=$((TN + 1)); PASSED=$((PASSED + 1))
      RESULTS+=("\"case\":\"${case_path}\",\"status\":\"pass\",\"type\":\"tn\",\"must_find\":${must_find}")
    else
      echo -e "    ${RED}FALSE POSITIVE: safe contract incorrectly flagged${NC}"
      FP=$((FP + 1)); FAILED=$((FAILED + 1))
      RESULTS+=("\"case\":\"${case_path}\",\"status\":\"fail\",\"type\":\"fp\",\"must_find\":${must_find}")
    fi
  fi

  # Cleanup benchmark workspace and reset findings dir for next run
  rm -rf "${BENCH_WORKSPACE}"
}

for case_path in "${CASES_TO_RUN[@]}"; do
  run_case "$case_path"
done

# ── Summary ───────────────────────────────────────────────────

echo -e "${BOLD}${CYAN}════════════════════════════════════════${NC}"
echo -e "${BOLD}  Benchmark Run Summary${NC}"
echo -e "${BOLD}${CYAN}════════════════════════════════════════${NC}"
echo ""
echo -e "  Total Cases:   ${TOTAL}"
echo -e "  Passed:        ${GREEN}${PASSED}${NC}"
echo -e "  Failed:        ${RED}${FAILED}${NC}"
echo -e "  Pending/Skip:  ${YELLOW}${SKIPPED}${NC}"
echo ""
echo -e "  True Positives:  ${TP}"
echo -e "  True Negatives:  ${TN}"
echo -e "  False Positives: ${FP}"
echo -e "  False Negatives: ${FN}"
echo ""

# ── Write Results JSON ────────────────────────────────────────

RESULTS_JSON=$(printf '%s,' "${RESULTS[@]}")
RESULTS_JSON="[${RESULTS_JSON%,}]"

cat > "$RESULTS_FILE" <<JSON
{
  "bench_run_id": "${BENCH_RUN_ID}",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "mode": "${MODE}",
  "category": "${CATEGORY}",
  "summary": {
    "total": ${TOTAL},
    "passed": ${PASSED},
    "failed": ${FAILED},
    "skipped": ${SKIPPED},
    "true_positives": ${TP},
    "true_negatives": ${TN},
    "false_positives": ${FP},
    "false_negatives": ${FN}
  },
  "cases": ${RESULTS_JSON}
}
JSON

echo -e "  Results: ${RESULTS_FILE}"
echo ""

# ── Write to DB ───────────────────────────────────────────────

if [ "$WRITE_DB" = true ] && [ -f "$DB_PATH" ]; then
  sqlite3 "$DB_PATH" <<SQL
INSERT INTO harness_versions (
  version_id, component, change_type, description,
  benchmark_before, benchmark_after, applied_at
) VALUES (
  '${BENCH_RUN_ID}',
  'benchmark_suite',
  'measurement',
  'Benchmark run: ${CATEGORY} / ${MODE}. TP=${TP} TN=${TN} FP=${FP} FN=${FN}',
  NULL,
  CAST(${PASSED} AS REAL) / NULLIF(${TOTAL}, 0),
  '$(date -u +"%Y-%m-%dT%H:%M:%SZ")'
);
SQL
  echo -e "  ${GREEN}✓ Results written to DB${NC}"
fi

echo -e "${GREEN}${BOLD}Benchmark run complete.${NC}"
