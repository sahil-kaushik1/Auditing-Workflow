# Pattern: Finding Report

## Structure

Every confirmed finding MUST follow this format:

```markdown
# Finding: {ID} — {Title}

## Severity: {Critical | High | Medium | Low}

## Impact
[1-2 sentences: concrete impact, not vague risk]

## Root Cause
[Specific code flaw with file:line reference]

## Attack Path
1. [Concrete step 1 with function call and parameters]
2. [Concrete step 2]
3. [Result: invariant violated, funds stolen, etc.]

## Proof of Concept
[Link to Foundry test or inline the test code]

## Affected Code
[File, lines, code snippet]

## Remediation
[Specific fix with code diff]

## Evidence Chain
- Task: specs/tasks/TASK-{N}.md
- Reasoning: specs/reasoning/TASK-{N}-reasoning.md
- Verification: specs/verification/TASK-{N}-verification.md
```

## Quality Checklist

- [ ] Severity has justification (not just a label)
- [ ] Impact is concrete ("attacker can drain X" not "there may be a risk")
- [ ] Attack path is reproducible (specific calls, values, ordering)
- [ ] PoC is runnable (`forge test --match-test test_exploit`)
- [ ] Remediation is actionable (code diff, not vague advice)
- [ ] Evidence chain links back to task and verification
