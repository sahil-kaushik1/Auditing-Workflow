#!/usr/bin/env bash
# Dark Factory: Discovery Team — Maximum Recall
# Spawns core + hypothesis generator for broad vulnerability discovery.
#
# Usage: ./discovery-team.sh <project-path>

set -euo pipefail

PROJECT_PATH="${1:-.}"
SESSION_NAME="discovery-$(date +%s)"

echo "🔬 Starting Discovery scan on: $PROJECT_PATH"
echo "📋 Session: $SESSION_NAME"

# Discovery pipeline: SAST → Decompose → Hypotheses + Tasks → Reason → Verify
tmux new-session -d -s "$SESSION_NAME" -n "sast" \
  "echo 'SAST Integrator: Full structural analysis...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "decomposer" \
  "echo 'Decomposer: Full 10-dimension decomposition...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "hypothesis" \
  "echo 'Hypothesis Generator: Creative divergent scan...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "threat-modeler" \
  "echo 'Threat Modeler: Tasks from decomposition + hypotheses...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "reasoner" \
  "echo 'Deep Reasoner: Bounded analysis per task...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "verifier" \
  "echo 'Verifier: Lighter verification...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "judge" \
  "echo 'Judge: Classification...' && sleep 1"

echo "✅ Discovery team launched: tmux attach -t $SESSION_NAME"
echo "Mode: Discovery (50/50 budget split, hypothesis generator enabled)"
