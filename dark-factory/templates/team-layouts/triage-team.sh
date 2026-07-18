#!/usr/bin/env bash
# Dark Factory: Triage Team — Fast Assessment
# Spawns core agents for a quick triage scan.
#
# Usage: ./triage-team.sh <project-path>

set -euo pipefail

PROJECT_PATH="${1:-.}"
SESSION_NAME="triage-$(date +%s)"

echo "⚡ Starting Fast-Triage on: $PROJECT_PATH"
echo "📋 Session: $SESSION_NAME"

# Minimal pipeline: SAST → Decompose → Reason (no gap cycles)
tmux new-session -d -s "$SESSION_NAME" -n "sast" \
  "echo 'SAST Integrator: Quick structural scan...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "decomposer" \
  "echo 'Decomposer: Fast decomposition (key dimensions only)...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "reasoner" \
  "echo 'Deep Reasoner: Pattern-match scan...' && sleep 1"

tmux new-window -t "$SESSION_NAME" -n "judge" \
  "echo 'Judge: Quick classification...' && sleep 1"

echo "✅ Triage team launched: tmux attach -t $SESSION_NAME"
echo "Mode: Fast-Triage (30/70 budget split, no gap cycles)"
