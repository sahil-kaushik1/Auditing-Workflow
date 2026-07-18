# Pattern: Review Attribution Report

## Purpose
When a finding is missed, document which pipeline component failed and why.

## Structure

```markdown
# Attribution: {Finding ID}

## Missed Vulnerability
[Description]

## Failure Category
[1-8 from the attribution table]

## Pipeline Trace
1. Was there a task? [YES/NO]
2. Did the task have the right failure predicate? [YES/NO]
3. Did the task require the right witness? [YES/NO]
4. Was relevant context provided? [YES/NO]
5. Did the reasoner analyze correctly? [YES/NO]
6. Was verification attempted? [YES/NO]
7. Was the finding preserved in output? [YES/NO]
8. Was the finding in the final report? [YES/NO]

## Root Cause
[First NO in the trace above]

## Proposed Fix
[Local change to the responsible component]

## Affected File
[Exact file path]
```

## Rule
Fix the FIRST failure point. Downstream failures are symptoms.
