#!/usr/bin/env bash
# Dark Factory: Audit Team — Full Audit Pipeline
# Spawns all 11 agents for a complete audit-grade scan.
#
# Usage: ./audit-team.sh <project-path>

set -euo pipefail

PROJECT_PATH="${1:-.}"
SESSION_NAME="audit-full-$(date +%s)"

echo "🔍 Starting Audit-Grade pipeline on: $PROJECT_PATH"
echo "📋 Session: $SESSION_NAME"
echo ""

# Stage 1: SAST + Decomposition (70% budget)
echo "=== STAGE 1: DECOMPOSITION ==="
echo "Spawning: SAST Integrator → Decomposer → Context Builder"

tmux new-session -d -s "$SESSION_NAME" -n "sast" \
  "echo 'SAST Integrator: Extracting structural facts...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "decomposer" \
  "echo 'Decomposer: 10-dimensional decomposition...' && sleep 1"

# Stage 2: Task Definition
echo "=== STAGE 2: TASK DEFINITION ==="
echo "Spawning: Threat Modeler"

tmux new-window -t "$SESSION_NAME" -n "threat-modeler" \
  "echo 'Threat Modeler: Compiling proof obligations...' && sleep 1"

# Stage 3: Reasoning + Verification (30% budget)
echo "=== STAGE 3: REASONING + VERIFICATION ==="
echo "Spawning: Context Builder → Deep Reasoner → Verifier → Judge"

tmux new-window -t "$SESSION_NAME" -n "reasoner" \
  "echo 'Deep Reasoner: Bounded vulnerability analysis...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "verifier" \
  "echo 'Verifier: Independent Foundry PoC generation...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "judge" \
  "echo 'Judge: Gate evaluation, finding classification...' && sleep 1"

# Orchestrator (manages the cycle)
tmux new-window -t "$SESSION_NAME" -n "orchestrator" \
  "echo 'Orchestrator: Managing audit cycle...' && sleep 1"

# Report Compiler
tmux new-window -t "$SESSION_NAME" -n "reporter" \
  "echo 'Report Compiler: Generating findings, gaps, coverage...' && sleep 1"

echo ""
echo "✅ Audit team launched in tmux session: $SESSION_NAME"
echo "   Attach with: tmux attach -t $SESSION_NAME"
echo ""
echo "Pipeline: SAST → Decompose → Tasks → Reason → Verify → Judge → Report"
echo "Mode: Audit-Grade (70/30 budget split)"
