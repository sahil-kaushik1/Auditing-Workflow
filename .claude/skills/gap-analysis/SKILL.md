---
name: gap-analysis
description: >
  Identify high-value insufficiently explored areas after each audit cycle.
  Used by the Orchestrator between cycles to drive supplemental task generation.
---

# Gap Analysis Skill

## Purpose

After each reasoning + verification cycle, identify what was NOT sufficiently covered
and direct the next cycle's budget toward the most valuable remaining uncertainty.

## When to Use

- After Cycle 1 completes (all initial tasks reasoned + verified)
- After any subsequent cycle
- When the Orchestrator needs to decide whether another cycle is warranted

## Gap Identification Criteria

Check each of these systematically:

### 1. Never-Covered Paths
- Functions that no task targeted
- Cross-contract call paths not examined
- Fallback / receive functions not analyzed

### 2. Shallow Proofs
- Tasks completed but with "INCONCLUSIVE" verification
- Reasoning that produced "no bug found" without actively proving safety
- Safety arguments that depend on assumptions

### 3. Unchallenged Safety Conclusions
- "This is safe because of modifier X" — was modifier X actually tested?
- "The check on line Y prevents this" — was the check tested at boundary values?

### 4. Missing Cross-Module Combinations
- Contract A looks safe, Contract B looks safe — was A+B tested together?
- Interactions between governance and core logic
- Oracle consumers + oracle update paths

### 5. Boundary Values Not Examined
- Zero values, maximum values, dust amounts
- First/last element in arrays
- Block timestamp edge cases

### 6. Missing State Transitions
- Can the system reach states that were assumed impossible?
- Were all state machine paths exercised?

### 7. Missing Differential Comparisons
- Multiple implementations of the same logic
- Version upgrades where behavior should be preserved

## Output

Save to: `specs/cycles/GAP-ANALYSIS-{N}.md` using the gap record template.

## Decision Matrix

| Gap Category | Priority | Action |
|-------------|----------|--------|
| High-value, unexplored path | Critical | Generate supplemental task immediately |
| Shallow proof on critical invariant | High | Deepen with more focused task |
| Missing cross-module test | High | Generate cross-contract task |
| Boundary value gap | Medium | Add to existing task or create lightweight task |
| Low-value area not covered | Low | Document and skip |
