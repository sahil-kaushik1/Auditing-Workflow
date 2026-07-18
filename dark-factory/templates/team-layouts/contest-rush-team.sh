#!/usr/bin/env bash
# Dark Factory: Contest-Rush Team — Time-Constrained Parallel Hypotheses
# Spawns core agents + hypothesis generator for maximum recall under time pressure.
# Budget split: 40/60 (decomposition/reasoning), no gap cycles.
#
# Usage: ./contest-rush-team.sh <project-path>

set -euo pipefail

PROJECT_PATH="${1:-.}"
SESSION_NAME="contest-rush-$(date +%s)"

echo "🏁 Starting Contest-Rush pipeline on: $PROJECT_PATH"
echo "📋 Session: $SESSION_NAME"
echo ""

# Stage 1: Fast SAST + Decomposition (40% budget — streamlined)
echo "=== STAGE 1: FAST DECOMPOSITION ==="
echo "Spawning: SAST Integrator → Decomposer (key dimensions only)"

tmux new-session -d -s "$SESSION_NAME" -n "sast" \
  "echo 'SAST Integrator: Fast structural scan...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "decomposer" \
  "echo 'Decomposer: Priority dimensions (entrypoints, assets, invariants)...' && sleep 1"

# Parallel: Hypothesis Generator runs alongside decomposition
echo "=== PARALLEL: HYPOTHESIS GENERATION ==="
echo "Spawning: Hypothesis Generator (creative divergent scan)"

tmux new-window -t "$SESSION_NAME" -n "hypothesis" \
  "echo 'Hypothesis Generator: Creative divergent vulnerability cloud...' && sleep 1"

# Stage 2: Task Definition (from decomposition + hypotheses)
echo "=== STAGE 2: TASK DEFINITION ==="
echo "Spawning: Threat Modeler (consuming both decomposition + hypotheses)"

tmux new-window -t "$SESSION_NAME" -n "threat-modeler" \
  "echo 'Threat Modeler: Tasks from decomposition + hypothesis clusters...' && sleep 1"

# Stage 3: Parallel Reasoning + Verification (60% budget — maximized)
echo "=== STAGE 3: PARALLEL REASONING + VERIFICATION ==="
echo "Spawning: Multiple Reasoners + Verifiers for parallel task processing"

tmux new-window -t "$SESSION_NAME" -n "reasoner-1" \
  "echo 'Deep Reasoner 1: Critical priority tasks...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "reasoner-2" \
  "echo 'Deep Reasoner 2: High priority tasks...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "verifier" \
  "echo 'Verifier: Parallel PoC generation for confirmed hypotheses...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "judge" \
  "echo 'Judge: Fast classification, skip inconclusive...' && sleep 1"

# Report Compiler
tmux new-window -t "$SESSION_NAME" -n "reporter" \
  "echo 'Report Compiler: Rapid finding compilation...' && sleep 1"

echo ""
echo "✅ Contest-Rush team launched in tmux session: $SESSION_NAME"
echo "   Attach with: tmux attach -t $SESSION_NAME"
echo ""
echo "Pipeline: SAST → Decompose ║ Hypotheses → Tasks → Reason×2 → Verify → Judge → Report"
echo "Mode: Contest-Rush (40/60 budget split, parallel hypotheses, no gap cycles)"
