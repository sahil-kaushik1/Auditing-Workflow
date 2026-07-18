# SAW Audit Database

SQLite persistence layer for the Smart Contract Auditing Harness.

## Files

| File | Purpose |
|------|---------|
| `schema.sql` | Full database schema — tables, indexes, views |
| `init.sh` | Initialization script |
| `saw.db` | The database (created by init.sh, git-ignored) |

## Setup

```bash
# Initialize (run once)
bash db/init.sh

# Verify
sqlite3 db/saw.db ".tables"

# Reset (destroys all data)
bash db/init.sh --reset
```

## Schema Overview

```
runs           ← Top-level audit campaigns
flows          ← Business-flow slices (deposit, withdraw, liquidation, ...)
tasks          ← Proof obligation tasks (19-field schema)
findings       ← Confirmed vulnerability reports
artifacts      ← Immutable evidence store (PoCs, forge output, traces)
tool_calls     ← Every deterministic tool invocation
gate_results   ← Per-gate evidence for each finding (10 gates)
false_positives ← Negative memory: known false-positive patterns
harness_versions ← Self-improvement audit trail
gap_cycles     ← Orchestrator gap analysis per cycle
```

## Useful Queries

```sql
-- Run summary
SELECT * FROM v_run_summary;

-- Which flows have no tasks (coverage gaps)
SELECT * FROM v_uncovered_flows;

-- All confirmed Critical findings
SELECT finding_id, title, economic_impact_usd
FROM findings WHERE severity = 'Critical' AND is_duplicate = 0;

-- Gate pass rates
SELECT gate_name, COUNT(*) as checks,
       SUM(CASE WHEN result='PASS' THEN 1 ELSE 0 END) as passes
FROM gate_results GROUP BY gate_name;

-- Cost per task
SELECT task_id, target, cost_usd, tokens_used
FROM tasks WHERE run_id = 'your-run-id'
ORDER BY cost_usd DESC;

-- False positive patterns (negative memory)
SELECT contract_type, apparent_vuln, why_false_positive
FROM false_positives ORDER BY added_at DESC;

-- Harness evolution history
SELECT component, change_type, benchmark_before, benchmark_after, rolled_back
FROM harness_versions ORDER BY applied_at DESC;
```

## Immutability Rules

- `artifacts.content_hash` — SHA256 of artifact file. Never modify an artifact.
- `false_positives` — append-only. Never delete FP records.
- `harness_versions` — append-only. Use `rolled_back=1` instead of deleting.
- `gate_results` — append-only per task. Once a gate result is written, it is evidence.

## .gitignore

`saw.db` is git-ignored. The schema is committed. Reconstructing the DB from
a clean state: `bash db/init.sh`.

For team audits where the DB must be shared, use a shared network path or
export findings: `sqlite3 saw.db ".dump findings" > findings.sql`.
