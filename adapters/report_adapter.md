# ReportAdapter — Report Format Contract

## Purpose

Ensures findings reports are consistently structured regardless of which model
produced the underlying reasoning and verification. The Report Compiler must
produce output conforming to this contract.

## Finding Report Fields (FINDING-{ID}.md)

Every finding must contain all of the following:

```yaml
## Required Metadata
finding_id:      string    # FINDING-001-critical-share-inflation
run_id:          string    # audit campaign ID
task_id:         string    # originating task
severity:        string    # Critical | High | Medium | Low | Informational
title:           string    # concise, specific (not "Reentrancy vulnerability")
status:          string    # CONFIRMED | CANDIDATE

## Vulnerability Description
root_cause:         string  # precise technical root cause
violated_invariant: string  # what invariant does this break
attack_path:        string  # numbered steps (attacker-perspective)
impact:             string  # what happens if exploited

## Evidence
poc_path:           string | null  # path to PoC test file
poc_output_hash:    string | null  # SHA256 of forge test output
gate_results:       string         # 10-gate table
gates_passed:       int            # 0-10
economic_impact:    string         # from Economic Analyst report

## Remediation
root_cause_fix:     string   # specific code change required
suggested_diff:     string   # optional: pseudocode diff showing the fix
counterfactual:     string   # "PoC fails after applying this fix"

## Deduplication
is_duplicate:       bool
duplicate_of:       string | null
variant_of:         string | null

## Metadata
confirmed_at:       string   # ISO-8601
auditors:           string[] # agent chain that produced this finding
model_reasoner:     string
model_verifier:     string
```

## Executive Summary (EXECUTIVE-SUMMARY.md)

```markdown
# Executive Summary — {protocol} Audit

## Engagement Overview
- Protocol: {name}
- Audit mode: {mode}
- Duration: {start} to {end}
- Total cost: ${usd}

## Finding Summary
| Severity | Count | Confirmed | Candidates |
|---------|-------|-----------|-----------|
| Critical | N | N | N |
| High | N | N | N |
| Medium | N | N | N |
| Low | N | N | N |

## Coverage
- Flows analyzed: N/M
- Tasks completed: N
- Tasks with confirmed findings: N
- False positive rate: N%

## Critical Findings
{for each Critical: one-paragraph plain English summary}

## Recommendations
{ordered by severity}
```

## What the Report Compiler MUST NOT Do

```
✗ Add findings not present in verification artifacts
✗ Upgrade severity without Economic Analyst support
✗ Omit findings based on subjective importance
✗ Merge findings that Deduplicator marked as INDEPENDENT
✗ Include DUPLICATE findings as separate report items
✗ Reference Reasoner's chain-of-thought prose directly
```
