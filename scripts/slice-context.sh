#!/usr/bin/env bash
# =============================================================================
# scripts/slice-context.sh — Per-Task Context Slicer
# =============================================================================
# Extracts ONLY the functions and state variables relevant to a specific task.
# This is the primary fix for context window overflow on large codebases.
#
# Usage:
#   bash scripts/slice-context.sh \
#     --task  specs/tasks/TASK-001.md \
#     --src   /path/to/contracts/ \
#     --out   specs/context/TASK-001-context.md \
#     [--depth 2]    # how many levels of callees to follow (default: 2)
#     [--max-tokens 6000]  # hard budget cap (default: 6000)
#
# Output: A single compact context package that fits in one task's window.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARNESS_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Args ──────────────────────────────────────────────────────
TASK_FILE=""
SRC_DIR=""
OUT_FILE=""
MAX_DEPTH=2
MAX_TOKENS=6000

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task)       TASK_FILE="$2";   shift 2 ;;
    --src)        SRC_DIR="$2";     shift 2 ;;
    --out)        OUT_FILE="$2";    shift 2 ;;
    --depth)      MAX_DEPTH="$2";   shift 2 ;;
    --max-tokens) MAX_TOKENS="$2";  shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

[ -z "$TASK_FILE" ] && { echo "ERROR: --task required" >&2; exit 1; }
[ -z "$SRC_DIR"   ] && { echo "ERROR: --src required" >&2; exit 1; }
[ -z "$OUT_FILE"  ] && { echo "ERROR: --out required" >&2; exit 1; }
[ -f "$TASK_FILE" ] || { echo "ERROR: Task file not found: $TASK_FILE" >&2; exit 1; }
[ -d "$SRC_DIR"   ] || { echo "ERROR: Source dir not found: $SRC_DIR" >&2; exit 1; }

mkdir -p "$(dirname "$OUT_FILE")"

# ── Extract Task Metadata ─────────────────────────────────────
# Parse the target, relevant_state, and execution_path from the task file
# Multi-pattern target extraction: supports YAML-style (target: "Foo.bar()") and
# markdown-style (** Target**: `Foo.bar()`) task formats.
TARGET_RAW=$(
  grep -oP '(?i)(?:target\s*:\s*["\x27]?)\K[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*(?=\()' "$TASK_FILE" 2>/dev/null | head -1 || \
  grep -oP '(?<=Target[^\n]{0,20}\`)[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*' "$TASK_FILE" 2>/dev/null | head -1 || \
  echo ""
)
TARGET_CONTRACT=$(echo "$TARGET_RAW" | cut -d'.' -f1 || echo "")
TARGET_FUNCTION=$(echo "$TARGET_RAW" | cut -d'.' -f2 | sed 's/(.*//' || echo "")

# Extract relevant state variable names
RELEVANT_STATE=$(
  grep -A 10 -iE '^relevant.state|## Relevant State' "$TASK_FILE" 2>/dev/null | \
  grep -oP '(?<=-\s{0,5}|: )[a-z_][a-zA-Z0-9_]+(?=:| -)' | \
  tr '\n' '|' || echo ""
)

# Extract execution path contracts
EXECUTION_PATH=$(
  grep -A 10 -iE '^execution.path|## Execution Path' "$TASK_FILE" 2>/dev/null | \
  grep -v -iE '^execution' | head -6 | tr -d '*' | tr '\n' ' ' || echo ""
)

echo "=== Context Slicer ==="
echo "Task:     $TASK_FILE"
echo "Contract: $TARGET_CONTRACT"
echo "Function: $TARGET_FUNCTION"
echo "Src Dir:  $SRC_DIR"
echo ""

# ── Find Relevant Files ───────────────────────────────────────
declare -a RELEVANT_FILES=()

# 1. Find files containing the target contract
if [ -n "$TARGET_CONTRACT" ]; then
  while IFS= read -r -d '' f; do
    RELEVANT_FILES+=("$f")
  done < <(grep -rl "$TARGET_CONTRACT" "$SRC_DIR" --include="*.sol" -Z 2>/dev/null || true)
fi

# 2. Find files containing the target function name
if [ -n "$TARGET_FUNCTION" ]; then
  while IFS= read -r -d '' f; do
    # Avoid duplicates
    if [[ ! " ${RELEVANT_FILES[*]} " =~ " $f " ]]; then
      RELEVANT_FILES+=("$f")
    fi
  done < <(grep -rl "function ${TARGET_FUNCTION}" "$SRC_DIR" --include="*.sol" -Z 2>/dev/null || true)
fi

# Resolve import remappings from foundry.toml or remappings.txt
declare -A REMAPPINGS=()
_load_remappings() {
  local base="$1"
  # foundry.toml remappings
  if [ -f "${base}/foundry.toml" ]; then
    while IFS= read -r line; do
      key=$(echo "$line" | grep -oP '^"?\K[^"=]+(?="?\s*=)' | tr -d '"' | tr -d ' ')
      val=$(echo "$line" | grep -oP '=\s*"?\K[^"]+' | tr -d '"' | tr -d ' ')
      [ -n "$key" ] && [ -n "$val" ] && REMAPPINGS["$key"]="$val"
    done < <(grep -A50 '\[remappings\]' "${base}/foundry.toml" 2>/dev/null | grep '=' | grep -v '\[' || true)
  fi
  # remappings.txt
  if [ -f "${base}/remappings.txt" ]; then
    while IFS='=' read -r key val; do
      key=$(echo "$key" | tr -d ' ')
      val=$(echo "$val" | tr -d ' ')
      [ -n "$key" ] && [ -n "$val" ] && REMAPPINGS["$key"]="$val"
    done < "${base}/remappings.txt"
  fi
}
_load_remappings "$SRC_DIR"
_load_remappings "$(dirname "$SRC_DIR")"

resolve_import() {
  local import_path="$1"
  local base="$2"
  # Try remappings first
  for prefix in "${!REMAPPINGS[@]}"; do
    if [[ "$import_path" == ${prefix}* ]]; then
      local resolved_rel="${REMAPPINGS[$prefix]}${import_path#$prefix}"
      # Try relative to SRC_DIR, then project root
      for try_base in "$SRC_DIR" "$(dirname "$SRC_DIR")" "$(dirname "$(dirname "$SRC_DIR")")" ; do
        if [ -f "${try_base}/${resolved_rel}" ]; then echo "${try_base}/${resolved_rel}"; return; fi
      done
    fi
  done
  # Try relative to the importing file's directory
  local file_dir="$(dirname "$base")"
  if [ -f "${file_dir}/${import_path}" ]; then echo "${file_dir}/${import_path}"; return; fi
  # Try relative to SRC_DIR
  if [ -f "${SRC_DIR}/${import_path}" ]; then echo "${SRC_DIR}/${import_path}"; return; fi
  echo ""
}

# 3. Resolve imports for all relevant files
for sol_file in "${RELEVANT_FILES[@]}"; do
  while IFS= read -r import_line; do
    imported_path=$(echo "$import_line" | grep -oP '(?<=")[^"]+(?=")' | head -1 || true)
    [ -z "$imported_path" ] && continue
    resolved=$(resolve_import "$imported_path" "$sol_file")
    if [ -n "$resolved" ] && [ -f "$resolved" ] && \
       [[ ! " ${RELEVANT_FILES[*]} " =~ " $resolved " ]]; then
      RELEVANT_FILES+=("$resolved")
    fi
  done < <(grep -E "^import" "$sol_file" 2>/dev/null || true)
done

echo "Relevant files found: ${#RELEVANT_FILES[@]}"
for f in "${RELEVANT_FILES[@]}"; do
  echo "  → $(realpath --relative-to="$SRC_DIR" "$f" 2>/dev/null || echo "$f")"
done
echo ""

# ── Build Context Package ─────────────────────────────────────
TEMP_FULL=$(mktemp)
TEMP_SLICED=$(mktemp)

cat >> "$TEMP_FULL" << HEADER
# Context Package: $(basename "$TASK_FILE" .md)

> **Auto-generated by slice-context.sh**
> Task: $TASK_FILE
> Target: ${TARGET_CONTRACT}.${TARGET_FUNCTION}()
> Strategy: Function-targeted slicing (depth=$MAX_DEPTH)

## Isolation Declaration

The following context was EXCLUDED:
- All contracts not transitively called by ${TARGET_FUNCTION}
- Test files
- Deployment scripts
- Frontend/off-chain code
- Previous audit findings (anchoring prevention)

---

## Task Summary

$(cat "$TASK_FILE")

---

## Relevant Source Code

HEADER

# ── Write python3 function extractor to a temp helper file ──
# (Kept separate so the function definition stays syntactically clean)
SAW_PY_HELPER=$(mktemp /tmp/saw-slice-XXXXXX.py)
cat > "$SAW_PY_HELPER" << 'PYEOF'
import sys, re

filepath = sys.argv[1]
func_name = sys.argv[2]

try:
    with open(filepath, 'r', errors='replace') as f:
        lines = f.readlines()
except Exception:
    sys.exit(1)

pattern = re.compile(
    r'^\s*function\s+' + re.escape(func_name) + r'\s*[\(\s]'
)
natspec_pat = re.compile(r'^\s*(?:///|/\*\*|\*)')

i = 0
while i < len(lines):
    if pattern.search(lines[i]):
        j = i - 1
        natspec = []
        while j >= 0 and (natspec_pat.match(lines[j]) or not lines[j].strip()):
            natspec.insert(0, lines[j]); j -= 1
        for nl in natspec:
            sys.stdout.write(nl)
        brace_count = 0
        in_str = False; str_ch = ''
        in_blk = False; found_open = False
        for idx in range(i, len(lines)):
            line = lines[idx]
            sys.stdout.write(line)
            ci = 0
            while ci < len(line):
                ch = line[ci]
                if in_blk:
                    if ch == '*' and ci+1 < len(line) and line[ci+1] == '/': in_blk = False; ci += 1
                elif ch == '/' and ci+1 < len(line) and line[ci+1] == '/':
                    break
                elif ch == '/' and ci+1 < len(line) and line[ci+1] == '*':
                    in_blk = True; ci += 1
                elif in_str:
                    if ch == str_ch and (ci == 0 or line[ci-1] != '\\'): in_str = False
                elif ch in ('"', "'"):
                    in_str = True; str_ch = ch
                else:
                    if ch == '{':
                        brace_count += 1; found_open = True
                    elif ch == '}':
                        brace_count -= 1
                        if found_open and brace_count <= 0:
                            sys.stdout.write('\n'); sys.exit(0)
                ci += 1
        break
    i += 1
PYEOF

# ── Smart Slicing: Extract target function + natspec ──
slice_function() {
  local file="$1"
  local func_name="$2"
  local depth="$3"

  if [ "$depth" -lt 0 ] || [ -z "$func_name" ]; then return; fi

  # Try python3 first (handles assembly, strings, nested braces, NatSpec)
  if command -v python3 &>/dev/null && [ -f "${SAW_PY_HELPER:-}" ]; then
    if python3 "$SAW_PY_HELPER" "$file" "$func_name" 2>/dev/null; then
      return
    fi
  fi

  # Fallback: awk-based brace counter (simpler, handles most cases)
  awk -v func="$func_name" '
    $0 ~ ("function[[:space:]]+"func"[[:space:]]*[\\.(\\ ]") {
      found=1; braces=0
    }
    found {
      print
      n = split($0, chars, "")
      for (i = 1; i <= n; i++) {
        if (chars[i] == "{") braces++
        if (chars[i] == "}") {
          braces--
          if (braces <= 0 && found) { found=0; exit }
        }
      }
    }
  ' "$file" 2>/dev/null || true
}

TOTAL_CHARS=0
MAX_CHARS=$((MAX_TOKENS * 4))  # rough char estimate: 1 token ≈ 4 chars

for sol_file in "${RELEVANT_FILES[@]}"; do
  rel_path="$(realpath --relative-to="$(pwd)" "$sol_file" 2>/dev/null || echo "$sol_file")"

  echo "" >> "$TEMP_FULL"
  echo "### \`$rel_path\`" >> "$TEMP_FULL"
  echo "" >> "$TEMP_FULL"

  # If the target function is in this file, extract just that function
  if [ -n "$TARGET_FUNCTION" ] && grep -q "function ${TARGET_FUNCTION}" "$sol_file" 2>/dev/null; then
    echo "\`\`\`solidity" >> "$TEMP_FULL"
    # Extract: pragma + contract declaration + state vars + target function
    {
      grep -E "^(pragma|contract|import|abstract|interface|library)" "$sol_file" | head -10
      echo "  // [state variables - filtered to task-relevant]"
      # Extract only state vars referenced in Relevant State
      if [ -n "$RELEVANT_STATE" ]; then
        grep -E "(${RELEVANT_STATE//|/|})" "$sol_file" | grep -v "function\|emit\|require\|return" | head -20 || true
      fi
      echo ""
      slice_function "$sol_file" "$TARGET_FUNCTION" "$MAX_DEPTH"
    } >> "$TEMP_FULL"
    echo "\`\`\`" >> "$TEMP_FULL"
  else
    # Not the primary target — include header and exports only (interfaces)
    echo "\`\`\`solidity" >> "$TEMP_FULL"
    grep -E "^(pragma|contract|abstract|interface|library|    function|    event|    error|    struct)" "$sol_file" | head -40 >> "$TEMP_FULL" || true
    echo "  // ... (full body omitted — not primary target)"
    echo "\`\`\`" >> "$TEMP_FULL"
  fi

  TOTAL_CHARS=$(wc -c < "$TEMP_FULL" || echo 0)
  if [ "$TOTAL_CHARS" -gt "$MAX_CHARS" ]; then
    echo "" >> "$TEMP_FULL"
    echo "---" >> "$TEMP_FULL"
    echo "> ⚠️ **Context budget exhausted at ${MAX_TOKENS} tokens.** Remaining files omitted." >> "$TEMP_FULL"
    echo "> Increase --max-tokens or narrow --depth to include them." >> "$TEMP_FULL"
    break
  fi
done

# ── Write final output ────────────────────────────────────────
cp "$TEMP_FULL" "$OUT_FILE"
rm -f "$TEMP_FULL" "$TEMP_SLICED"

FINAL_CHARS=$(wc -c < "$OUT_FILE")
APPROX_TOKENS=$((FINAL_CHARS / 4))

# Cleanup temp python helper
rm -f "${SAW_PY_HELPER:-}"

echo "✅ Context package written: $OUT_FILE"
echo "   Approx tokens: ~${APPROX_TOKENS} / ${MAX_TOKENS}"
echo "   Files included: ${#RELEVANT_FILES[@]}"
