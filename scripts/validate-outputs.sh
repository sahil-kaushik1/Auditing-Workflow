#!/usr/bin/env bash
# =============================================================================
# validate-outputs.sh — Agent Output Schema Validation
# =============================================================================
#
# Validates that agent outputs contain all required sections, regardless of
# which model produced them. This is the enforcement layer for model
# independence — if a model's output passes validation, it's structurally
# correct regardless of vendor.
#
# Usage:
#   ./scripts/validate-outputs.sh [component] [file]
#
# Components:
#   reasoning   — Validate a reasoning artifact (specs/reasoning/TASK-*-reasoning.md)
#   task        — Validate a task file (specs/tasks/TASK-*.md)
#   verification — Validate a verification artifact (specs/verification/TASK-*-verification.md)
#   finding     — Validate a finding report (findings/FINDING-*.md)
#   gap         — Validate a gap record (findings/GAP-RECORD-*.md)
#   decomposition — Validate a decomposition artifact (specs/decomposition/*.md)
#   gate        — Validate a gate decision (specs/gates/GATE-*.md)
#   all         — Validate all artifacts in specs/ and findings/
#
# Exit codes:
#   0 — All validations passed
#   1 — Validation failures detected
#   2 — Usage error
# =============================================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# --- Counters ---
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
TOTAL_COUNT=0

# --- Functions ---

log_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo -e "  ${GREEN}✓${NC} $1"
}

log_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  TOTAL_COUNT=$((TOTAL_COUNT + 1))
  echo -e "  ${RED}✗${NC} $1"
}

log_warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  echo -e "  ${YELLOW}⚠${NC} $1"
}

log_header() {
  echo -e "\n${CYAN}━━━ $1 ━━━${NC}"
}

# Check if a file contains a section heading (## or #)
check_section() {
  local file="$1"
  local section_pattern="$2"
  local section_name="$3"

  if grep -qiE "^#{1,3} *${section_pattern}" "$file" 2>/dev/null; then
    log_pass "$section_name"
    return 0
  else
    log_fail "$section_name — MISSING"
    return 1
  fi
}

# Check if a section is non-empty (has content after the heading)
check_section_nonempty() {
  local file="$1"
  local section_pattern="$2"
  local section_name="$3"

  # Find the section heading line number
  local line_num
  line_num=$(grep -niE "^#{1,3} *${section_pattern}" "$file" 2>/dev/null | head -1 | cut -d: -f1)

  if [ -z "$line_num" ]; then
    log_fail "$section_name — MISSING"
    return 1
  fi

  # Check if there's non-empty content within the next 5 lines
  local content
  content=$(sed -n "$((line_num+1)),$((line_num+5))p" "$file" | grep -v '^\s*$' | head -1)

  if [ -n "$content" ]; then
    log_pass "$section_name"
    return 0
  else
    log_fail "$section_name — section exists but is EMPTY"
    return 1
  fi
}

# ==== Task Validation ====
validate_task() {
  local file="$1"
  log_header "Task: $(basename "$file")"

  local fields=(
    # Original 9 fields
    "Target|Field 1: Target"
    "Execution Path|Field 2: Execution Path"
    "Relevant State|Field 3: Relevant State"
    "Attacker Capabilities|Field 4: Attacker Capabilities"
    "Invariant|Field 5: Invariant"
    "Failure Predicate|Field 6: Failure Predicate"
    "Required Witness|Field 7: Required Witness"
    "Completion Contract|Field 8: Completion Contract"
    "Drift Anchors|Field 9: Drift Anchors"
    # New fields 10-19 (v2 schema)
    "flow_id|Field 10: flow_id"
    "phase|Field 11: phase"
    "attacker_model|Field 12: attacker_model"
    "token_model|Field 13: token_model"
    "out_of_scope_cases|Field 14: out_of_scope_cases"
    "stop_rule|Field 15: stop_rule"
    "verification_tools|Field 16: verification_tools"
    "negative_memory_check|Field 17: negative_memory_check"
    "economic_impact_estimate|Field 18: economic_impact_estimate"
    "budget_tokens|Field 19: budget_tokens"
  )

  local all_pass=true
  for field in "${fields[@]}"; do
    local pattern="${field%%|*}"
    local name="${field##*|}"
    if ! check_section_nonempty "$file" "$pattern" "Field: $name"; then
      all_pass=false
    fi
  done

  # Check for Priority
  if grep -qi "priority" "$file"; then
    log_pass "Priority field present"
  else
    log_warn "Priority field missing (optional but recommended)"
  fi

  # Check phase is a valid enum value
  local phase_val
  phase_val=$(grep -oP 'phase:\s*"?\K[0-9]+-[a-z-]+' "$file" | head -1 || echo "")
  if echo "$phase_val" | grep -qE \
    '^(1-static|2-flow-model|3-foundry-unit|4-foundry-invariant|5-medusa-fuzz|6-echidna|7-halmos|8-differential|9-exploit|10-report)$'; then
    log_pass "Phase is valid enum: ${phase_val}"
  elif [ -z "$phase_val" ]; then
    log_fail "Phase field missing or unparseable"
    all_pass=false
  else
    log_fail "Phase value '${phase_val}' is not a valid phase enum"
    all_pass=false
  fi

  # Check negative_memory_check has 'checked: true'
  if grep -qP 'checked:\s*true' "$file"; then
    log_pass "Negative memory check completed (checked: true)"
  else
    log_fail "Negative memory check not marked completed (need 'checked: true')"
    all_pass=false
  fi

  # Check budget_tokens is numeric
  if grep -qP 'budget_tokens:\s*\d+' "$file"; then
    log_pass "budget_tokens is a numeric value"
  else
    log_fail "budget_tokens missing or non-numeric"
    all_pass=false
  fi

  # Check drift anchors are specific (not generic)
  local anchors
  anchors=$(grep -iA 5 "drift.anchor" "$file" | grep -oE '"[^"]+"' | tr -d '"' || true)
  if echo "$anchors" | grep -qiE "^(security|vulnerability|attack|bug|issue)$"; then
    log_fail "Drift anchors contain generic terms — must be task-specific"
  fi

  $all_pass && return 0 || return 1
}

# ==== Reasoning Validation ====
validate_reasoning() {
  local file="$1"
  log_header "Reasoning: $(basename "$file")"

  local sections=(
    "Task Summary|Task Summary"
    "Execution Path Trace|Execution Path Trace"
    "State Analysis|State Analysis"
    "Hypothesis|Hypothesis"
    "Drift Self-Check|Drift Self-Check"
    "Completion Status|Completion Status"
  )

  local all_pass=true
  for section in "${sections[@]}"; do
    local pattern="${section%%|*}"
    local name="${section##*|}"
    if ! check_section "$file" "$pattern" "Section: $name"; then
      all_pass=false
    fi
  done

  # Check drift self-check has YES/NO answers
  if grep -qE "(YES|NO)" "$file"; then
    log_pass "Drift self-check has YES/NO verdicts"
  else
    log_fail "Drift self-check missing YES/NO verdicts"
    all_pass=false
  fi

  # Check completion status has valid value
  if grep -qiE "COMPLETE|INCOMPLETE" "$file"; then
    log_pass "Completion status present (COMPLETE or INCOMPLETE)"
  else
    log_fail "Completion status missing COMPLETE/INCOMPLETE verdict"
    all_pass=false
  fi

  # Check for either witness OR safety argument
  if grep -qiE "Attack Path|Witness|Safety Argument" "$file"; then
    log_pass "Contains attack path/witness OR safety argument"
  else
    log_fail "Missing both attack path/witness AND safety argument"
    all_pass=false
  fi

  # Check for assumptions section
  if grep -qiE "Assumptions" "$file"; then
    log_pass "Assumptions documented"
  else
    log_warn "Assumptions section missing (should document analysis assumptions)"
  fi

  $all_pass && return 0 || return 1
}

# ==== Verification Validation ====
validate_verification() {
  local file="$1"
  log_header "Verification: $(basename "$file")"

  local sections=(
    "Claim Under Review|Claim Under Review"
    "Verification Method|Verification Method"
    "Evidence|Evidence"
    "Verdict|Verdict"
    "Reasoning|Reasoning"
  )

  local all_pass=true
  for section in "${sections[@]}"; do
    local pattern="${section%%|*}"
    local name="${section##*|}"
    if ! check_section "$file" "$pattern" "Section: $name"; then
      all_pass=false
    fi
  done

  # Check verdict is valid
  if grep -qiE "CONFIRMED|REFUTED|INCONCLUSIVE" "$file"; then
    log_pass "Valid verdict (CONFIRMED/REFUTED/INCONCLUSIVE)"
  else
    log_fail "Missing valid verdict — must be CONFIRMED, REFUTED, or INCONCLUSIVE"
    all_pass=false
  fi

  # Check for test code or PoC reference
  if grep -qiE "\.t\.sol|forge test|Test Code|solidity|function test_" "$file"; then
    log_pass "Contains test code or Foundry PoC reference"
  else
    log_warn "No Foundry test code found — verification may lack executable evidence"
  fi

  # Check for caveats
  if grep -qiE "Caveat|Limitation" "$file"; then
    log_pass "Caveats/limitations documented"
  else
    log_warn "No caveats section — should document verification limitations"
  fi

  $all_pass && return 0 || return 1
}

# ==== Finding Validation ====
validate_finding() {
  local file="$1"
  log_header "Finding: $(basename "$file")"

  local sections=(
    "Severity|Severity"
    "Impact|Impact"
    "Root Cause|Root Cause"
    "Attack Path|Attack Path"
    "Proof of Concept|Proof of Concept"
    "Affected Code|Affected Code"
    "Remediation|Remediation"
    "References|References"
  )

  local all_pass=true
  for section in "${sections[@]}"; do
    local pattern="${section%%|*}"
    local name="${section##*|}"
    if ! check_section_nonempty "$file" "$pattern" "Section: $name"; then
      all_pass=false
    fi
  done

  # Check severity is valid
  if grep -qiE "Critical|High|Medium|Low|Informational" "$file"; then
    log_pass "Valid severity level"
  else
    log_fail "Missing valid severity (Critical/High/Medium/Low/Informational)"
    all_pass=false
  fi

  # Check for concrete attack steps (numbered list)
  if grep -qE "^[0-9]+\." "$file"; then
    log_pass "Attack path has numbered steps"
  else
    log_warn "Attack path may lack concrete numbered steps"
  fi

  # Check for task/reasoning/verification references
  if grep -qi "specs/tasks/\|specs/reasoning/\|specs/verification/" "$file"; then
    log_pass "References to pipeline artifacts present"
  else
    log_fail "Missing references to pipeline artifacts (task, reasoning, verification)"
    all_pass=false
  fi

  $all_pass && return 0 || return 1
}

# ==== Gap Record Validation ====
validate_gap() {
  local file="$1"
  log_header "Gap Record: $(basename "$file")"

  local sections=(
    "Uncovered Areas|Uncovered Areas"
    "Shallow Proofs|Shallow Proofs"
    "Unverified Assumptions|Unverified Assumptions"
    "Recommended|Recommended Supplemental Tasks"
  )

  local all_pass=true
  for section in "${sections[@]}"; do
    local pattern="${section%%|*}"
    local name="${section##*|}"
    if ! check_section "$file" "$pattern" "Section: $name"; then
      all_pass=false
    fi
  done

  $all_pass && return 0 || return 1
}

# ==== Decomposition Validation ====
validate_decomposition() {
  local file="$1"
  log_header "Decomposition: $(basename "$file")"

  local sections=(
    "Summary|Summary"
    "Detailed Analysis|Detailed Analysis|Analysis"
    "Key Observations|Key Observations for Threat Modeling"
    "Cross-References|Cross-References"
  )

  local all_pass=true
  for section in "${sections[@]}"; do
    local pattern="${section%%|*}"
    local name="${section##*|}"
    if ! check_section "$file" "$pattern" "Section: $name"; then
      all_pass=false
    fi
  done

  $all_pass && return 0 || return 1
}

# ==== Gate Decision Validation ====
validate_gate() {
  local file="$1"
  log_header "Gate Decision: $(basename "$file")"

  local all_pass=true

  # Check for PASS or FAIL verdict
  if grep -qiE "PASS|FAIL" "$file"; then
    log_pass "Gate verdict present (PASS/FAIL)"
  else
    log_fail "Missing gate verdict — must contain PASS or FAIL"
    all_pass=false
  fi

  # Check for checklist items
  if grep -qE "\[[ x]\]" "$file"; then
    log_pass "Checklist items present"
  else
    log_warn "No checklist items found"
  fi

  $all_pass && return 0 || return 1
}

# ==== Validate All ====
validate_all() {
  log_header "FULL VALIDATION SWEEP"
  echo -e "${BOLD}Scanning all pipeline artifacts...${NC}\n"

  # Enable nullglob so unmatched patterns expand to nothing
  shopt -s nullglob

  local found_any=false

  # Tasks
  for f in specs/tasks/TASK-*.md; do
    found_any=true
    validate_task "$f" || true
  done

  # Reasoning
  for f in specs/reasoning/TASK-*-reasoning.md; do
    found_any=true
    validate_reasoning "$f" || true
  done

  # Verification
  for f in specs/verification/TASK-*-verification.md; do
    found_any=true
    validate_verification "$f" || true
  done

  # Findings
  for f in findings/FINDING-*.md; do
    found_any=true
    validate_finding "$f" || true
  done

  # Gap records
  for f in findings/GAP-RECORD-*.md; do
    found_any=true
    validate_gap "$f" || true
  done

  # Decomposition
  for f in specs/decomposition/*.md; do
    found_any=true
    validate_decomposition "$f" || true
  done

  # Gates
  for f in specs/gates/GATE-*.md; do
    found_any=true
    validate_gate "$f" || true
  done

  shopt -u nullglob

  if [ "$found_any" = false ]; then
    echo -e "  ${YELLOW}⚠${NC} No pipeline artifacts found. Run an audit first to generate outputs."
  fi
}

# ==== Main ====
main() {
  echo -e "${BOLD}${CYAN}"
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║       Agent Output Validation — Model Independence       ║"
  echo "║  Validates structural compliance regardless of AI model  ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"

  if [ $# -eq 0 ]; then
    echo "Usage: $0 <component> [file]"
    echo ""
    echo "Components: reasoning, task, verification, finding, gap, decomposition, gate, all"
    echo ""
    echo "Examples:"
    echo "  $0 task specs/tasks/TASK-001-nav-manipulation.md"
    echo "  $0 reasoning specs/reasoning/TASK-001-reasoning.md"
    echo "  $0 all"
    exit 2
  fi

  local component="$1"
  local file="${2:-}"

  case "$component" in
    task)
      [ -z "$file" ] && { echo "Error: file path required"; exit 2; }
      validate_task "$file"
      ;;
    reasoning)
      [ -z "$file" ] && { echo "Error: file path required"; exit 2; }
      validate_reasoning "$file"
      ;;
    verification)
      [ -z "$file" ] && { echo "Error: file path required"; exit 2; }
      validate_verification "$file"
      ;;
    finding)
      [ -z "$file" ] && { echo "Error: file path required"; exit 2; }
      validate_finding "$file"
      ;;
    gap)
      [ -z "$file" ] && { echo "Error: file path required"; exit 2; }
      validate_gap "$file"
      ;;
    decomposition)
      [ -z "$file" ] && { echo "Error: file path required"; exit 2; }
      validate_decomposition "$file"
      ;;
    gate)
      [ -z "$file" ] && { echo "Error: file path required"; exit 2; }
      validate_gate "$file"
      ;;
    all)
      validate_all
      ;;
    *)
      echo "Error: unknown component '$component'"
      echo "Valid: reasoning, task, verification, finding, gap, decomposition, gate, all"
      exit 2
      ;;
  esac

  # --- Summary ---
  echo -e "\n${BOLD}━━━ Validation Summary ━━━${NC}"
  echo -e "  ${GREEN}Passed${NC}: $PASS_COUNT"
  echo -e "  ${RED}Failed${NC}: $FAIL_COUNT"
  echo -e "  ${YELLOW}Warnings${NC}: $WARN_COUNT"
  echo -e "  Total checks: $TOTAL_COUNT"

  if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "\n${RED}${BOLD}VALIDATION FAILED${NC} — $FAIL_COUNT required sections missing or invalid"
    echo -e "Fix the issues above before proceeding to the next pipeline stage."
    exit 1
  else
    echo -e "\n${GREEN}${BOLD}VALIDATION PASSED${NC} — all required sections present"
    exit 0
  fi
}

main "$@"
