# Pattern: Coverage Map

## Purpose
Honest documentation of what WAS examined and to what depth.

## Structure

```markdown
# Audit Coverage Map

## Contract Coverage
| Contract | Functions Covered | Functions Not Covered | Coverage % |
|----------|------------------|----------------------|------------|

## Invariant Coverage
| ID | Invariant | Tasks Testing It | Verdict |
|----|-----------|-----------------|---------|

## Business Flow Coverage
| Flow | Contracts | Depth | Status |
|------|-----------|-------|--------|

## Legend
- **Full**: Analyzed with deep reasoning + verification
- **Partial**: Fast scan or single task
- **None**: Not targeted by any task
```

## Honesty Rule
- `Partial` ≠ `Full`. A fast scan that found nothing is NOT full coverage.
- `None` items MUST appear in the gap record.
