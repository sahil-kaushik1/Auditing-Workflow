# Pattern: Inheritance Criteria

## Purpose
Define when a local component change is promoted to the global configuration.

## Criteria (ALL must be true)

1. **Repeatability**: Works on 3+ different projects
2. **Measurability**: Measurable improvement in hit rate (not anecdotal)
3. **No regression**: No previously-found vulnerabilities are now missed
4. **Explainability**: The change can be explained (not "it just worked")
5. **Attributability**: The improvement can be attributed to the specific change
6. **Reversibility**: Can be rolled back with a single git command

## Anti-Pattern: Premature Inheritance

DO NOT promote a change after one success. One-off improvements may be:
- Project-specific (doesn't generalize)
- Coincidental (the benchmark is too small)
- Coupled with other factors (model temperature, context window)

## Promotion Protocol

1. Test on project A → success
2. Test on project B → success
3. Test on project C → success
4. Run full regression suite → no regressions
5. Document in CHANGELOG.md
6. Merge to main configuration
