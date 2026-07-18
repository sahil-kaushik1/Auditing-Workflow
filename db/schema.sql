-- ============================================================
-- SAW Audit Database Schema v1
-- Smart Contract Auditing Harness — Persistence Layer
-- ============================================================
-- Usage: sqlite3 saw.db < schema.sql
-- ============================================================

PRAGMA journal_mode = WAL;
PRAGMA foreign_keys = ON;

-- ============================================================
-- RUNS — top-level audit campaign record
-- ============================================================
CREATE TABLE IF NOT EXISTS runs (
  run_id          TEXT PRIMARY KEY,   -- e.g. "audit-2026-07-08-1inch-cross-chain"
  protocol        TEXT NOT NULL,      -- protocol name
  repo_url        TEXT,               -- git URL of audited repo
  started_at      TEXT NOT NULL,      -- ISO-8601
  completed_at    TEXT,
  mode            TEXT NOT NULL,      -- audit_grade | discovery | contest_rush | smoke_scan | fast_triage | conservative | bug_bounty_sequence
  provider        TEXT NOT NULL,      -- anthropic | openai | google | custom
  active_provider_model_json TEXT,    -- JSON snapshot of model-config.yml provider section
  total_cost_usd  REAL DEFAULT 0,
  total_tokens    INTEGER DEFAULT 0,
  status          TEXT DEFAULT 'running', -- running | complete | failed | paused
  notes           TEXT
);

-- ============================================================
-- FLOWS — business-flow slices (output of Flow Mapper)
-- ============================================================
CREATE TABLE IF NOT EXISTS flows (
  flow_id         TEXT PRIMARY KEY,   -- e.g. "FLOW-001-withdraw"
  run_id          TEXT NOT NULL REFERENCES runs(run_id),
  flow_type       TEXT NOT NULL,      -- deposit | withdraw | mint_burn | redemption | liquidation | claim_reward | settlement | bridge_message | oracle_update | admin_config
  key_contracts   TEXT,               -- JSON array of contract names
  key_functions   TEXT,               -- JSON array of function signatures
  assets_at_risk  TEXT,               -- JSON array
  economic_risk_score REAL,           -- 0.0-1.0, used for task prioritization
  artifact_path   TEXT,               -- path to specs/flows/FLOW-{N}.md
  created_at      TEXT NOT NULL
);

-- ============================================================
-- TASKS — proof obligation tasks (output of Threat Modeler)
-- ============================================================
CREATE TABLE IF NOT EXISTS tasks (
  task_id         TEXT PRIMARY KEY,   -- e.g. "TASK-001-share-inflation"
  run_id          TEXT NOT NULL REFERENCES runs(run_id),
  flow_id         TEXT REFERENCES flows(flow_id),
  priority        TEXT NOT NULL,      -- Critical | High | Medium | Low
  phase           TEXT NOT NULL,      -- 1-static | 2-flow-model | 3-foundry-unit | 4-foundry-invariant | 5-medusa-fuzz | 6-echidna | 7-halmos | 8-differential | 9-exploit | 10-report
  target          TEXT NOT NULL,      -- "ContractName.functionName()"
  invariant       TEXT,
  failure_predicate TEXT,
  attacker_model_json TEXT,           -- JSON: {can_be_trusted_role, can_flashloan, ...}
  token_model_json TEXT,              -- JSON: {assume_standard_erc20, ...}
  out_of_scope_cases TEXT,            -- JSON array
  stop_rule       TEXT,
  verification_tools TEXT,            -- JSON array: ["foundry_poc", "foundry_invariant"]
  budget_tokens   INTEGER DEFAULT 8000,
  economic_impact_estimate TEXT,      -- JSON: {asset, max_extractable, impact_class}
  negative_memory_match_score REAL,   -- 0.0-1.0 from pre-check
  status          TEXT DEFAULT 'pending', -- pending | reasoning | skeptic_review | verifying | economic_analysis | done | skipped | rejected
  verdict         TEXT,               -- CONFIRMED | REFUTED | INCONCLUSIVE | SKIPPED | REJECTED-OUT-OF-SCOPE | REJECTED-TRUSTED-ROLE | REJECTED-TOKEN-ASSUMPTION
  severity        TEXT,               -- Critical | High | Medium | Low | Informational
  cost_usd        REAL DEFAULT 0,
  tokens_used     INTEGER DEFAULT 0,
  created_at      TEXT NOT NULL,
  completed_at    TEXT,
  model_reasoner  TEXT,
  model_verifier  TEXT,
  artifact_path   TEXT                -- path to specs/tasks/TASK-{N}.md
);

-- ============================================================
-- FINDINGS — confirmed vulnerability reports
-- ============================================================
CREATE TABLE IF NOT EXISTS findings (
  finding_id      TEXT PRIMARY KEY,   -- "FINDING-001-critical-share-inflation"
  run_id          TEXT NOT NULL REFERENCES runs(run_id),
  task_id         TEXT NOT NULL REFERENCES tasks(task_id),
  severity        TEXT NOT NULL,
  title           TEXT NOT NULL,
  root_cause      TEXT,
  violated_invariant TEXT,
  attack_path_summary TEXT,
  is_duplicate    INTEGER DEFAULT 0,
  duplicate_of    TEXT REFERENCES findings(finding_id),
  economic_impact_usd REAL,
  impact_class    TEXT,               -- direct_loss | value_extraction | griefing | dos
  gate_results_json TEXT,             -- JSON: {gate1: PASS, gate2: PASS, ...}
  gates_passed    INTEGER DEFAULT 0,  -- count 0-10
  poc_path        TEXT,               -- path to PoC file
  created_at      TEXT NOT NULL,
  artifact_path   TEXT                -- path to findings/FINDING-{ID}.md
);

-- ============================================================
-- ARTIFACTS — immutable evidence store
-- ============================================================
CREATE TABLE IF NOT EXISTS artifacts (
  artifact_id     TEXT PRIMARY KEY,
  task_id         TEXT REFERENCES tasks(task_id),
  run_id          TEXT NOT NULL REFERENCES runs(run_id),
  artifact_type   TEXT NOT NULL,      -- poc | invariant_test | fuzz_corpus | forge_output | slither_json | aderyn_json | halmos_log | skeptic_report | economic_report | reasoning | verification | gate_decision
  file_path       TEXT NOT NULL,
  content_hash    TEXT NOT NULL,      -- SHA256 — immutable audit trail
  size_bytes      INTEGER,
  created_at      TEXT NOT NULL,
  tool_used       TEXT,
  tool_version    TEXT,
  phase           TEXT
);

-- ============================================================
-- TOOL_CALLS — every deterministic tool invocation
-- ============================================================
CREATE TABLE IF NOT EXISTS tool_calls (
  call_id         TEXT PRIMARY KEY,
  task_id         TEXT REFERENCES tasks(task_id),
  run_id          TEXT NOT NULL REFERENCES runs(run_id),
  tool            TEXT NOT NULL,      -- slither | forge | echidna | medusa | halmos | aderyn | semgrep | cast | hevm
  command         TEXT NOT NULL,      -- exact shell command
  exit_code       INTEGER,
  duration_sec    REAL,
  output_path     TEXT,               -- path to stored output
  output_hash     TEXT,               -- SHA256
  called_at       TEXT NOT NULL,
  succeeded       INTEGER             -- 1 | 0
);

-- ============================================================
-- GATE_RESULTS — per-gate evidence for each finding
-- ============================================================
CREATE TABLE IF NOT EXISTS gate_results (
  gate_result_id  TEXT PRIMARY KEY,
  task_id         TEXT NOT NULL REFERENCES tasks(task_id),
  gate_number     INTEGER NOT NULL,   -- 1-10
  gate_name       TEXT NOT NULL,      -- In-Scope | Reachability | Controllability | ...
  result          TEXT NOT NULL,      -- PASS | FAIL | WAIVED
  evidence        TEXT,               -- brief evidence text
  checked_at      TEXT NOT NULL
);

-- ============================================================
-- FALSE_POSITIVES — negative memory store
-- ============================================================
CREATE TABLE IF NOT EXISTS false_positives (
  fp_id               TEXT PRIMARY KEY,
  task_id             TEXT REFERENCES tasks(task_id),
  run_id              TEXT REFERENCES runs(run_id),
  pattern_hash        TEXT NOT NULL,  -- SHA256 of (target_function + invariant) for dedup
  target_function     TEXT,
  contract_type       TEXT,           -- ERC4626 | AMM | Lending | Bridge | ...
  apparent_vuln       TEXT,
  why_false_positive  TEXT NOT NULL,
  detection_keywords  TEXT,           -- JSON array of keywords for similarity check
  added_by            TEXT DEFAULT 'judge',
  added_at            TEXT NOT NULL
);

-- ============================================================
-- HARNESS_VERSIONS — self-improvement audit trail
-- ============================================================
CREATE TABLE IF NOT EXISTS harness_versions (
  version_id          TEXT PRIMARY KEY,
  component           TEXT NOT NULL,  -- which agent/skill/template changed
  component_path      TEXT,           -- file path
  change_type         TEXT NOT NULL,  -- add | modify | remove
  description         TEXT,
  proposed_by         TEXT,           -- harness-critic | evolution-manager | human
  benchmark_before    REAL,           -- pass rate before change (0.0-1.0)
  benchmark_after     REAL,           -- pass rate after change
  fp_rate_before      REAL,
  fp_rate_after       REAL,
  cost_before_usd     REAL,
  cost_after_usd      REAL,
  applied_at          TEXT NOT NULL,
  rolled_back         INTEGER DEFAULT 0,
  rollback_reason     TEXT,
  rolled_back_at      TEXT,
  git_commit_before   TEXT,
  git_commit_after    TEXT
);

-- ============================================================
-- GAP_CYCLES — orchestrator gap analysis per cycle
-- ============================================================
CREATE TABLE IF NOT EXISTS gap_cycles (
  cycle_id        TEXT PRIMARY KEY,   -- "CYCLE-1-2026-07-08"
  run_id          TEXT NOT NULL REFERENCES runs(run_id),
  cycle_number    INTEGER NOT NULL,
  gaps_json       TEXT,               -- JSON array of gap objects
  supplemental_tasks_generated INTEGER DEFAULT 0,
  budget_remaining_pct REAL,
  decision        TEXT,               -- continue | stop
  stop_reason     TEXT,
  analyzed_at     TEXT NOT NULL,
  artifact_path   TEXT
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_tasks_run       ON tasks(run_id);
CREATE INDEX IF NOT EXISTS idx_tasks_status    ON tasks(status);
CREATE INDEX IF NOT EXISTS idx_tasks_priority  ON tasks(priority);
CREATE INDEX IF NOT EXISTS idx_tasks_verdict   ON tasks(verdict);
CREATE INDEX IF NOT EXISTS idx_findings_run    ON findings(run_id);
CREATE INDEX IF NOT EXISTS idx_findings_sev    ON findings(severity);
CREATE INDEX IF NOT EXISTS idx_fp_hash         ON false_positives(pattern_hash);
CREATE INDEX IF NOT EXISTS idx_artifacts_task  ON artifacts(task_id);
CREATE INDEX IF NOT EXISTS idx_tool_calls_task ON tool_calls(task_id);
CREATE INDEX IF NOT EXISTS idx_gate_task       ON gate_results(task_id);
CREATE INDEX IF NOT EXISTS idx_flows_run       ON flows(run_id);

-- ============================================================
-- VIEWS — common queries pre-built
-- ============================================================

-- Run summary view
CREATE VIEW IF NOT EXISTS v_run_summary AS
SELECT
  r.run_id,
  r.protocol,
  r.mode,
  r.status,
  COUNT(DISTINCT t.task_id) AS total_tasks,
  COUNT(DISTINCT CASE WHEN t.verdict = 'CONFIRMED' THEN t.task_id END) AS confirmed,
  COUNT(DISTINCT CASE WHEN t.verdict = 'REFUTED' THEN t.task_id END) AS refuted,
  COUNT(DISTINCT CASE WHEN t.verdict = 'INCONCLUSIVE' THEN t.task_id END) AS inconclusive,
  COUNT(DISTINCT f.finding_id) AS findings,
  COUNT(DISTINCT CASE WHEN f.severity = 'Critical' THEN f.finding_id END) AS critical,
  COUNT(DISTINCT CASE WHEN f.severity = 'High' THEN f.finding_id END) AS high,
  ROUND(r.total_cost_usd, 4) AS total_cost_usd
FROM runs r
LEFT JOIN tasks t ON t.run_id = r.run_id
LEFT JOIN findings f ON f.run_id = r.run_id AND f.is_duplicate = 0
GROUP BY r.run_id;

-- Coverage view: which flows have tasks
CREATE VIEW IF NOT EXISTS v_flow_coverage AS
SELECT
  f.flow_id,
  f.flow_type,
  f.run_id,
  COUNT(t.task_id) AS task_count,
  COUNT(CASE WHEN t.verdict IN ('CONFIRMED','REFUTED') THEN 1 END) AS resolved_tasks,
  COUNT(CASE WHEN t.verdict = 'CONFIRMED' THEN 1 END) AS confirmed_tasks,
  f.economic_risk_score
FROM flows f
LEFT JOIN tasks t ON t.flow_id = f.flow_id
GROUP BY f.flow_id;

-- High-value uncovered flows
CREATE VIEW IF NOT EXISTS v_uncovered_flows AS
SELECT * FROM v_flow_coverage
WHERE task_count = 0 AND economic_risk_score > 0.5
ORDER BY economic_risk_score DESC;
