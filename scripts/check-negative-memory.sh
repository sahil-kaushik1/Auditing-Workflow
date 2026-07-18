#!/usr/bin/env bash
# =============================================================================
# check-negative-memory.sh — Query negative memory before task generation
# =============================================================================
#
# Mandatory: Run before generating any task. If match_score > 0.8, the
# Threat Modeler must FLAG the task for human review before proceeding.
#
# Usage:
#   ./scripts/check-negative-memory.sh \
#     --function "withdraw" \
#     --invariant "share price manipulation" \
#     --keywords "donation,share,ERC4626,totalAssets"
#
# Output (JSON to stdout):
#   {"match_score": 0.85, "matched_pattern": "FP-SEED-001",
#    "recommendation": "flag_for_review", "reason": "..."}
#
# Exit codes:
#   0 — No match or low match (proceed)
#   1 — High match (flag for review)
#   2 — Usage error
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FP_FILE="${SCRIPT_DIR}/../memory/negative/false-positives.jsonl"

# Parse args
FUNCTION=""
INVARIANT=""
KEYWORDS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --function)  FUNCTION="$2";  shift 2 ;;
    --invariant) INVARIANT="$2"; shift 2 ;;
    --keywords)  KEYWORDS="$2";  shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$FUNCTION" ] && [ -z "$INVARIANT" ] && [ -z "$KEYWORDS" ]; then
  echo '{"error": "No input provided. Use --function, --invariant, or --keywords"}' >&2
  exit 2
fi

if [ ! -f "$FP_FILE" ]; then
  echo '{"match_score": 0.0, "matched_pattern": null, "recommendation": "proceed", "reason": "No negative memory file found"}'
  exit 0
fi

# Build search terms (lowercase, split by comma for keywords)
SEARCH_TERMS=()
[ -n "$FUNCTION" ]  && SEARCH_TERMS+=("$(echo "$FUNCTION" | tr '[:upper:]' '[:lower:]')")
[ -n "$INVARIANT" ] && SEARCH_TERMS+=("$(echo "$INVARIANT" | tr '[:upper:]' '[:lower:]')")
if [ -n "$KEYWORDS" ]; then
  IFS=',' read -ra KW_ARRAY <<< "$KEYWORDS"
  for kw in "${KW_ARRAY[@]}"; do
    SEARCH_TERMS+=("$(echo "$kw" | tr -d ' ' | tr '[:upper:]' '[:lower:]')")
  done
fi

# Count hits per FP pattern
BEST_SCORE=0
BEST_PATTERN=""
BEST_REASON=""

while IFS= read -r line; do
  [ -z "$line" ] && continue

  # Extract fields using grep (no jq dependency)
  PATTERN_ID=$(echo "$line" | grep -oP '"pattern_id":\s*"\K[^"]+' || echo "")
  DETECTION_KW=$(echo "$line" | grep -oP '"detection_keywords":\s*\[\K[^\]]+' | tr -d '"' | tr ',' ' ' | tr '[:upper:]' '[:lower:]' || echo "")
  TARGET_FN=$(echo "$line" | grep -oP '"target_function":\s*"\K[^"]+' | tr '[:upper:]' '[:lower:]' || echo "")
  WHY=$(echo "$line" | grep -oP '"why_false_positive":\s*"\K[^"]+' || echo "")

  # Score: count how many search terms appear in this pattern's keywords + function
  PATTERN_TEXT="${DETECTION_KW} ${TARGET_FN}"
  HITS=0
  TOTAL=${#SEARCH_TERMS[@]}

  for term in "${SEARCH_TERMS[@]}"; do
    if echo "$PATTERN_TEXT" | grep -qi "$term" 2>/dev/null; then
      HITS=$((HITS + 1))
    fi
  done

  if [ $TOTAL -gt 0 ]; then
    # Score = hits / total (simple Jaccard-style)
    SCORE=$(echo "scale=2; $HITS / $TOTAL" | bc 2>/dev/null || echo "0")
  else
    SCORE="0"
  fi

  # Track best match
  SCORE_INT=$(echo "$SCORE * 100" | bc 2>/dev/null | cut -d'.' -f1 || echo "0")
  BEST_INT=$(echo "$BEST_SCORE * 100" | bc 2>/dev/null | cut -d'.' -f1 || echo "0")

  if [ "${SCORE_INT:-0}" -gt "${BEST_INT:-0}" ]; then
    BEST_SCORE="$SCORE"
    BEST_PATTERN="$PATTERN_ID"
    BEST_REASON="$WHY"
  fi

done < "$FP_FILE"

# Determine recommendation
RECOMMENDATION="proceed"
EXIT_CODE=0
if (( $(echo "$BEST_SCORE > 0.8" | bc -l 2>/dev/null || echo 0) )); then
  RECOMMENDATION="flag_for_review"
  EXIT_CODE=1
elif (( $(echo "$BEST_SCORE > 0.5" | bc -l 2>/dev/null || echo 0) )); then
  RECOMMENDATION="proceed_with_caution"
  EXIT_CODE=0
fi

# Output JSON
if [ -n "$BEST_PATTERN" ]; then
  PATTERN_JSON="\"${BEST_PATTERN}\""
else
  PATTERN_JSON="null"
fi

cat <<EOF
{
  "match_score": ${BEST_SCORE:-0},
  "matched_pattern": ${PATTERN_JSON},
  "recommendation": "${RECOMMENDATION}",
  "reason": "${BEST_REASON:-No close match found in negative memory}"
}
EOF

exit $EXIT_CODE
