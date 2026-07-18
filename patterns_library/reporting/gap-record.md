# Pattern: Gap Record

## Purpose
Document what was NOT examined. Transparency about coverage gaps is as important
as documenting findings.

## Structure

```markdown
# Gap Record — Cycle {N}

## Uncovered Entrypoints
| Contract | Function | Reason Not Covered |
|----------|----------|--------------------|

## Shallow Proofs
| Task ID | What Was Shallow | Risk |
|---------|-----------------|------|

## Unverified Assumptions
| Assumption | Made In | Impact If Wrong |
|-----------|---------|-----------------|

## Missing Cross-Contract Combinations
| Contract A | Contract B | Untested Interaction |
|-----------|-----------|---------------------|

## Recommended Supplemental Tasks
1. [Specific task with target and invariant]
```
