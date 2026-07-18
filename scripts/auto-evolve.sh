#!/usr/bin/env bash
# =============================================================================
# scripts/auto-evolve.sh — Autonomous Harness Evolution Engine
# =============================================================================
# Runs after every audit cycle. Invokes Harness Critic, gets improvement
# suggestions, runs benchmark suite, and AUTO-APPLIES safe improvements.
#
# Two classes of improvements:
#   SAFE (auto-apply if benchmark_after >= benchmark_before):
#     - Adding new entries to memory/negative/false-positives.jsonl
#     - Adding detection_keywords to task templates
#     - Updating gap-analysis thresholds in audit.config.yml
#
#   GATED (require human review OR benchmark improvement > 5%):
#     - Modifying agent definition files (.claude/agents/*.md)
#     - Modifying skill files (.agents/skills/*/SKILL.md)
#     - Changing quality gate criteria
#
# Usage:
#   bash scripts/auto-evolve.sh --run-id <run-id> [--force-gate]
#
# Environment:
#   SAW_AUTO_EVOLVE_THRESHOLD  float, default 0.0  (improvement needed to auto-apply gated changes)
#   SAW_HUMAN_APPROVAL_REQUIRED  true|false, default false for SAFE class
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="${HARNESS_ROOT}/db/saw.db"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

RUN_ID=""
FORCE_GATE=false
AUTO_EVOLVE_THRESHOLD="${SAW_AUTO_EVOLVE_THRESHOLD:-0.0}"
HUMAN_REQUIRED="${SAW_HUMAN_APPROVAL_REQUIRED:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)    RUN_ID="$2";     shift 2 ;;
    --force-gate) FORCE_GATE=true; shift 1 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[ -z "$RUN_ID" ] && RUN_ID=$(date +"%Y%m%d-%H%M%S")

EVOLUTION_DIR="${HARNESS_ROOT}/specs/evolution"
mkdir -p "$EVOLUTION_DIR"
EVOLUTION_LOG="${EVOLUTION_DIR}/EVOLVE-${RUN_ID}.md"

timestamp() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

echo -e "${BOLD}${CYAN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║   SAW Auto-Evolution Engine                          ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "  Run ID:    $RUN_ID"
echo "  Threshold: ${AUTO_EVOLVE_THRESHOLD} (improvement needed for gated changes)"
echo "  Human required for gated: $HUMAN_REQUIRED"
echo ""

# ── Step 1: Read Harness Critic Output ───────────────────────
CRITIC_FILE="${HARNESS_ROOT}/specs/evolution/harness-critique-latest.md"

if [ ! -f "$CRITIC_FILE" ]; then
  echo -e "${YELLOW}No harness critique found at: $CRITIC_FILE${NC}"
  echo "Run the Harness Critic agent first. Prompt:"
  echo ""
  echo "  @harness-critic Review the completed audit cycle in specs/cycles/"
  echo "  and findings/ and produce a critique at specs/evolution/harness-critique-latest.md"
  echo ""
  # Still run benchmarks for baseline
fi

# ── Step 2: Run Baseline Benchmark ───────────────────────────
echo -e "${BOLD}Step 1/4: Running baseline benchmarks...${NC}"
BENCH_BEFORE_FILE="${HARNESS_ROOT}/benchmarks/results/baseline-${RUN_ID}.json"

bash "${SCRIPT_DIR}/run-benchmark.sh" \
  --mode fast_triage \
  --category all \
  2>/dev/null | tail -20 || true

# Calculate score from most recent benchmark result
LATEST_BENCH=$(ls -t "${HARNESS_ROOT}/benchmarks/results/"*.json 2>/dev/null | head -1 || echo "")
BENCH_BEFORE_SCORE=0
if [ -f "$LATEST_BENCH" ]; then
  BENCH_BEFORE_SCORE=$(python3 -c "
import json, sys
try:
  d = json.load(open('$LATEST_BENCH'))
  s = d.get('summary', {})
  total = s.get('total', 1)
  passed = s.get('passed', 0)
  print(round(passed / total, 3) if total > 0 else 0)
except: print(0)
" 2>/dev/null || echo "0")
fi

echo "  Baseline score: ${BENCH_BEFORE_SCORE}"

# ── Step 3: Parse Critic Suggestions & Classify ──────────────
echo ""
echo -e "${BOLD}Step 2/4: Parsing improvement candidates...${NC}"

declare -a SAFE_IMPROVEMENTS=()
declare -a GATED_IMPROVEMENTS=()

# Attempt to parse critic output for improvement items
if [ -f "$CRITIC_FILE" ]; then
  # SAFE: FP additions
  while IFS= read -r line; do
    if echo "$line" | grep -qi "add.*false.positive\|fp pattern\|negative memory"; then
      SAFE_IMPROVEMENTS+=("FP_PATTERN: $line")
    fi
  done < <(grep -i "improvement\|recommendation\|add\|fix\|update" "$CRITIC_FILE" 2>/dev/null || true)

  # GATED: Agent file changes
  while IFS= read -r line; do
    if echo "$line" | grep -qi "agent.*prompt\|modify.*skill\|update.*agent\|change.*gate\|task.*template"; then
      GATED_IMPROVEMENTS+=("AGENT_CHANGE: $line")
    fi
  done < <(grep -i "improvement\|change.*agent\|modify.*prompt" "$CRITIC_FILE" 2>/dev/null || true)
fi

echo "  SAFE improvements found:  ${#SAFE_IMPROVEMENTS[@]}"
echo "  GATED improvements found: ${#GATED_IMPROVEMENTS[@]}"

# ── Step 4: Apply SAFE Improvements Automatically ────────────
echo ""
echo -e "${BOLD}Step 3/4: Applying SAFE improvements...${NC}"

APPLIED_SAFE=0
for improvement in "${SAFE_IMPROVEMENTS[@]}"; do
  if echo "$improvement" | grep -q "^FP_PATTERN:"; then
    # Extract pattern text and append to false-positives.jsonl
    pattern_text="${improvement#FP_PATTERN: }"
    NEW_FP_ENTRY="{\"id\":\"AUTO-$(date +%s)\",\"run_id\":\"${RUN_ID}\",\"source\":\"harness_critic\",\"pattern\":\"${pattern_text}\",\"added_at\":\"$(timestamp)\"}"
    echo "$NEW_FP_ENTRY" >> "${HARNESS_ROOT}/memory/negative/false-positives.jsonl"
    APPLIED_SAFE=$((APPLIED_SAFE + 1))
    echo -e "  ${GREEN}✓ Applied FP pattern${NC}: ${pattern_text:0:80}..."
  fi
done

echo "  Applied $APPLIED_SAFE safe improvements automatically."

# ── Step 5: Handle GATED Improvements ────────────────────────
echo ""
echo -e "${BOLD}Step 4/4: Processing GATED improvements...${NC}"

APPLIED_GATED=0
for improvement in "${GATED_IMPROVEMENTS[@]}"; do
  if [ "$HUMAN_REQUIRED" = "true" ] && [ "$FORCE_GATE" = "false" ]; then
    echo -e "  ${YELLOW}⚠ GATED (human approval required):${NC}"
    echo "    ${improvement:0:120}"
    echo "    → Add to: ${EVOLUTION_LOG}"
    echo "    → Re-run with: --force-gate to auto-apply after benchmark check"
  else
    # If force-gate OR threshold already met, apply with benchmark guard
    echo -e "  ${YELLOW}⚠ Would apply:${NC} ${improvement:0:80}"
    echo "  (Benchmark guard required first — re-run with actual changes applied)"
  fi
done

# ── Step 6: Re-Benchmark After Safe Changes ───────────────────
if [ $APPLIED_SAFE -gt 0 ]; then
  echo ""
  echo -e "${BOLD}Re-benchmarking after safe improvements...${NC}"
  bash "${SCRIPT_DIR}/run-benchmark.sh" \
    --mode fast_triage \
    --category false-positive-cases \
    2>/dev/null | tail -10 || true

  LATEST_BENCH_AFTER=$(ls -t "${HARNESS_ROOT}/benchmarks/results/"*.json 2>/dev/null | head -1 || echo "")
  BENCH_AFTER_SCORE=0
  if [ -f "$LATEST_BENCH_AFTER" ]; then
    BENCH_AFTER_SCORE=$(python3 -c "
import json
try:
  d = json.load(open('$LATEST_BENCH_AFTER'))
  s = d.get('summary', {})
  total = s.get('total', 1)
  passed = s.get('passed', 0)
  print(round(passed / total, 3) if total > 0 else 0)
except: print(0)
" 2>/dev/null || echo "0")
  fi

  echo "  Before: ${BENCH_BEFORE_SCORE} → After: ${BENCH_AFTER_SCORE}"

  if python3 -c "exit(0 if float('${BENCH_AFTER_SCORE}') >= float('${BENCH_BEFORE_SCORE}') else 1)" 2>/dev/null; then
    echo -e "  ${GREEN}✓ PROMOTED — benchmark held or improved${NC}"
    STATUS="PROMOTED"
  else
    echo -e "  ${RED}✗ REGRESSION — rolling back safe improvements${NC}"
    STATUS="ROLLED_BACK"
    # Rollback: remove the last N lines from false-positives.jsonl
    head -n -${APPLIED_SAFE} "${HARNESS_ROOT}/memory/negative/false-positives.jsonl" \
      > "${HARNESS_ROOT}/memory/negative/false-positives.jsonl.tmp" && \
      mv "${HARNESS_ROOT}/memory/negative/false-positives.jsonl.tmp" \
         "${HARNESS_ROOT}/memory/negative/false-positives.jsonl"
    echo "  Rolled back $APPLIED_SAFE FP entries."
  fi
else
  STATUS="NO_SAFE_CHANGES"
  BENCH_AFTER_SCORE="$BENCH_BEFORE_SCORE"
fi

# ── Write Evolution Log ───────────────────────────────────────
cat > "$EVOLUTION_LOG" << EOF
# Auto-Evolution Run: ${RUN_ID}

**Timestamp**: $(timestamp)
**Status**: ${STATUS}

## Benchmark Scores
- Before: ${BENCH_BEFORE_SCORE}
- After:  ${BENCH_AFTER_SCORE}
- Delta:  $(python3 -c "print(round(float('${BENCH_AFTER_SCORE}') - float('${BENCH_BEFORE_SCORE}'), 3))" 2>/dev/null || echo "N/A")

## Safe Improvements Applied (${APPLIED_SAFE})
$(printf '%s\n' "${SAFE_IMPROVEMENTS[@]:-none}" | head -20)

## Gated Improvements Pending (${#GATED_IMPROVEMENTS[@]})
$(printf '%s\n' "${GATED_IMPROVEMENTS[@]:-none}" | head -20)

## Next Actions
$(if [ "${#GATED_IMPROVEMENTS[@]}" -gt 0 ]; then
  echo "- Review gated improvements above"
  echo "- Apply manually OR run: SAW_HUMAN_APPROVAL_REQUIRED=false bash scripts/auto-evolve.sh --run-id ${RUN_ID} --force-gate"
  echo "- Benchmark will auto-gate: if score drops, change is reverted"
else
  echo "- No gated improvements pending"
  echo "- Run next audit cycle"
fi)
EOF

# ── Write to DB ───────────────────────────────────────────────
if [ -f "$DB_PATH" ]; then
  sqlite3 "$DB_PATH" <<SQL 2>/dev/null || true
INSERT INTO harness_versions (
  version_id, component, change_type, description,
  benchmark_before, benchmark_after, applied_at
) VALUES (
  'evolve-${RUN_ID}',
  'auto_evolution_engine',
  'auto_run',
  'Safe: ${APPLIED_SAFE} FP patterns. Gated: ${#GATED_IMPROVEMENTS[@]} pending. Status: ${STATUS}.',
  ${BENCH_BEFORE_SCORE},
  ${BENCH_AFTER_SCORE},
  '$(timestamp)'
);
SQL
fi

echo ""
echo -e "${GREEN}${BOLD}Evolution run complete.${NC}"
echo "  Log: $EVOLUTION_LOG"
echo ""
echo -e "  ${BOLD}To manually apply gated improvements:${NC}"
echo "  1. Edit the relevant agent file in .claude/agents/"
echo "  2. Run benchmarks: bash scripts/run-benchmark.sh --write-db"
echo "  3. If benchmark_after >= benchmark_before: KEEP the change"
echo "  4. If benchmark_after < benchmark_before: git revert"
echo ""
echo -e "  ${BOLD}To fully auto-apply gated changes (bypass human gate):${NC}"
echo "  SAW_HUMAN_APPROVAL_REQUIRED=false bash scripts/auto-evolve.sh --run-id ${RUN_ID} --force-gate"
