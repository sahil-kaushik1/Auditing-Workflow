#!/usr/bin/env bash
# =============================================================================
# init-db.sh — Initialize the SAW Audit Database
# =============================================================================
#
# Usage:
#   ./db/init.sh                    # Creates db/saw.db
#   ./db/init.sh /path/to/saw.db   # Custom location
#   ./db/init.sh --reset            # Drop and recreate (WARNING: destroys data)
#
# The database persists across audits. Run once per harness installation.
# For per-audit isolation, use a separate DB file per audit run.
# =============================================================================

set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${SCRIPT_DIR}/schema.sql"

# Parse args
DB_PATH="${1:-${SCRIPT_DIR}/saw.db}"
RESET=false

for arg in "$@"; do
  if [ "$arg" = "--reset" ]; then
    RESET=true
    DB_PATH="${SCRIPT_DIR}/saw.db"
  fi
done

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║   SAW Audit Database — Initialization Script    ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check sqlite3
if ! command -v sqlite3 &>/dev/null; then
  echo -e "${RED}✗ sqlite3 not found.${NC}"
  echo "  Install: apt install sqlite3  OR  brew install sqlite3"
  exit 1
fi

echo -e "  sqlite3 version: $(sqlite3 --version | cut -d' ' -f1)"
echo -e "  Schema:  ${SCHEMA_FILE}"
echo -e "  DB path: ${DB_PATH}"
echo ""

# Reset if requested
if [ "$RESET" = true ] && [ -f "$DB_PATH" ]; then
  echo -e "${YELLOW}⚠ --reset flag: destroying existing database${NC}"
  read -r -p "  Type 'yes' to confirm: " confirm
  if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
  fi
  rm -f "$DB_PATH"
  echo -e "  ${GREEN}✓ Old database removed${NC}"
fi

# Already exists?
if [ -f "$DB_PATH" ]; then
  echo -e "${YELLOW}⚠ Database already exists at ${DB_PATH}${NC}"
  echo "  Use --reset to destroy and recreate."
  echo "  To check DB health, run: sqlite3 ${DB_PATH} '.tables'"
  exit 0
fi

# Create directory if needed
mkdir -p "$(dirname "$DB_PATH")"

# Initialize
echo -e "  Initializing database..."
sqlite3 "$DB_PATH" < "$SCHEMA_FILE"

# Verify tables created
TABLE_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';")
VIEW_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='view';")
INDEX_COUNT=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM sqlite_master WHERE type='index';")

echo ""
echo -e "  ${GREEN}✓ Database initialized successfully${NC}"
echo -e "  Tables: ${TABLE_COUNT}"
echo -e "  Views:  ${VIEW_COUNT}"
echo -e "  Indexes: ${INDEX_COUNT}"
echo ""
echo -e "  ${BOLD}Tables created:${NC}"
sqlite3 "$DB_PATH" ".tables" | tr ' ' '\n' | grep -v '^$' | while read -r tbl; do
  echo -e "    • ${tbl}"
done

echo ""
echo -e "${GREEN}${BOLD}Database ready.${NC}"
echo ""
echo "Next steps:"
echo "  Start an audit: ./scripts/run-audit.sh <project-path>"
echo "  Query results:  sqlite3 ${DB_PATH} 'SELECT * FROM v_run_summary;'"
echo "  Add to .gitignore: echo 'db/saw.db' >> .gitignore  (if not already)"
