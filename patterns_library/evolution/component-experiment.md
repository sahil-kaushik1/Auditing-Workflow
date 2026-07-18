# Pattern: Component Experiment

## Purpose
Protocol for safely testing a local change to a scanner component.

## Steps

1. **Identify** the component to change and the hypothesis for improvement
2. **Baseline**: Run benchmark with current component. Record hit rate.
3. **Modify**: Make the local change to ONE component only
4. **Test**: Run same benchmark with modified component. Record hit rate.
5. **Compare**: Did hit rate improve? Any regressions?
6. **Decide**: INHERIT (promote) / REJECT (rollback) / EXTEND (more testing)

## Template

```markdown
# Experiment: {ID}

**Component**: {file path}
**Hypothesis**: {what improvement is expected}
**Baseline Hit Rate**: {X}/{Y} on benchmark set
**Modified Hit Rate**: {X'}/{Y'} on benchmark set
**Regressions**: {list any findings that were previously caught but now missed}
**Verdict**: {INHERIT / REJECT / EXTEND}
**Rollback**: git checkout {commit} -- {file_path}
```
