---
name: cost-tracking
description: >
  Per-task cost accounting protocol. Logs token usage and USD cost to the
  SQLite database for every task, enabling budget control, model comparison,
  and cost efficiency analysis by the Harness Critic and Evolution Manager.
trigger: After every task completes (any verdict). Mandatory in all modes.
agents: [orchestrator, evolution-manager, harness-critic]
---

# Cost Tracking Skill

## Why Track Cost

Without cost data:
- Cannot enforce budget_tokens stop rules
- Cannot compare model efficiency (o3 vs Opus vs Sonnet)
- Cannot calculate ROI per finding
- Cannot optimize scanner mode model assignments
- Harness Critic has no efficiency data

## What to Track Per Task

After each task completes (any verdict: CONFIRMED, REFUTED, INCONCLUSIVE, KILLED):

```
task_id:          string
tokens_input:     int   (tokens in the task prompt + context)
tokens_output:    int   (tokens in the reasoning output)
tokens_total:     int   (input + output)
cost_usd:         float (calculated from model-config.yml pricing)
model_used:       string (actual model name, not alias)
phase:            string (from task.phase)
verdict:          string
over_budget:      bool  (tokens_total > task.budget_tokens)
```

## Cost Calculation

From `model-config.yml`, read the active provider's pricing:

```yaml
# model-config.yml pricing section (per 1M tokens)
providers:
  anthropic:
    pricing:
      claude-opus-4:
        input_per_1m:  15.00
        output_per_1m: 75.00
      claude-sonnet-4:
        input_per_1m:  3.00
        output_per_1m: 15.00
      claude-haiku-3:
        input_per_1m:  0.25
        output_per_1m: 1.25
  openai:
    pricing:
      o3:
        input_per_1m:  10.00
        output_per_1m: 40.00
      gpt-4.1:
        input_per_1m:  2.00
        output_per_1m: 8.00
```

```bash
# Calculate cost after each task
cost_usd=$(echo "scale=6; ($input_tokens * $input_price + $output_tokens * $output_price) / 1000000" | bc)
```

## DB Write Protocol

After each task, the Orchestrator writes to the DB:

```sql
UPDATE tasks
SET tokens_used = {total_tokens},
    cost_usd = {cost_usd},
    status = '{verdict}',
    completed_at = '{timestamp}',
    model_reasoner = '{model_name}'
WHERE task_id = '{task_id}';

-- Also update the run total
UPDATE runs
SET total_cost_usd = total_cost_usd + {cost_usd},
    total_tokens = total_tokens + {total_tokens}
WHERE run_id = '{run_id}';
```

## Budget Enforcement

The Orchestrator enforces the `budget_tokens` field from each task:

```
Before routing to Deep Reasoner:
  - Set context limit = task.budget_tokens
  - Include in Reasoner prompt: "STOP if you have used {budget_tokens} tokens.
    Apply your stop_rule and output current status."

After Reasoner completes:
  - If tokens_used > budget_tokens × 1.2 (20% overrun): flag as over_budget
  - Log to Harness Critic: task over-budget by {N} tokens
  - This is a harness discipline failure, not a finding failure
```

## Cost Efficiency Metrics (for Harness Critic)

```sql
-- Cost per confirmed finding
SELECT
  run_id,
  SUM(cost_usd) as total_cost,
  COUNT(CASE WHEN verdict = 'CONFIRMED' THEN 1 END) as confirmed,
  ROUND(SUM(cost_usd) / NULLIF(COUNT(CASE WHEN verdict = 'CONFIRMED' THEN 1 END), 0), 2)
    as cost_per_confirmed_finding
FROM tasks
GROUP BY run_id;

-- Most expensive tasks (potential over-analysis)
SELECT task_id, target, cost_usd, tokens_used, budget_tokens, verdict
FROM tasks
ORDER BY cost_usd DESC
LIMIT 10;

-- Model cost comparison across runs
SELECT model_reasoner, AVG(cost_usd) as avg_cost, COUNT(*) as task_count,
       COUNT(CASE WHEN verdict = 'CONFIRMED' THEN 1 END) as confirmed
FROM tasks
GROUP BY model_reasoner;

-- Over-budget rate per mode
SELECT r.mode, COUNT(*) as tasks,
       SUM(CASE WHEN t.tokens_used > t.budget_tokens THEN 1 ELSE 0 END) as over_budget,
       ROUND(100.0 * SUM(CASE WHEN t.tokens_used > t.budget_tokens THEN 1 ELSE 0 END) / COUNT(*), 1)
         as over_budget_pct
FROM tasks t JOIN runs r ON t.run_id = r.run_id
GROUP BY r.mode;
```

## Dashboard Cost Section

The Orchestrator updates `findings/DASHBOARD.md` cost section after each task:

```markdown
## Budget Status
- Total cost so far: ${total_cost_usd}
- Budget remaining: ${budget_remaining} ({pct}%)
- Cost per resolved task: ${avg_cost_per_task}
- Cost per confirmed finding: ${cost_per_finding}
- Over-budget tasks: {N} ({pct}%)
```
