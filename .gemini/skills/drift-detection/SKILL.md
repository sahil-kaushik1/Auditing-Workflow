---
name: drift-detection
description: Detect when the Deep Reasoner shifts away from the assigned task target. Monitors output against drift anchors and task boundaries.
trigger: During reasoning — after the Deep Reasoner produces output for a task.
agents: [deep-reasoner, judge]
---

# Drift Detection Skill

> **Trigger**: During and after reasoning — self-check (Reasoner) and gate check (Judge).
> **Purpose**: Prevent vulnerability drift — when the Reasoner discusses issues outside the task.

---

## What Is Drift?

Drift occurs when the Reasoner's output:
1. Discusses a **different function** than the task's Target
2. Analyzes a **different execution path** than the task's Execution Path
3. Proposes a vulnerability related to a **different invariant**
4. Uses **none of the drift anchors** in its analysis

### Drift vs. Legitimate Discovery

| Scenario | Drift? | Action |
|----------|--------|--------|
| Task targets `withdraw()`, output analyzes `deposit()` | YES | Reject |
| Task targets `withdraw()`, output traces into `_burn()` called by withdraw | NO | Legitimate |
| Task targets reentrancy, output finds access control issue | YES | Log as new hypothesis, reject |

---

## Reasoner Self-Check Protocol

Execute BEFORE finalizing output:

```markdown
## Drift Self-Check
1. Task Target: [copy] → My output discusses: [list] → Match: YES/NO
2. Task Execution Path: [copy] → My analysis follows: [list] → Match: YES/NO
3. Task Invariant: [copy] → My hypothesis relates to: [state] → Match: YES/NO
4. Task Drift Anchors: [list] → Present in output: [list] → Coverage: {X}/{Y}
5. Verdict: All pass → ON-TARGET / Any fail → DRIFT → discard and re-focus
```

If drift detected: do NOT include drifted analysis. Note it as "New Hypothesis for separate task." Re-focus on original task.

---

## Judge Gate Check Protocol

```markdown
## Judge Drift Gate — TASK-{N}

1. **Target Function Analyzed**: Task={target}, Reasoner={functions} → MATCH?
2. **Execution Path Followed**: Task={path}, Reasoner={path} → MATCH?
3. **Invariant Under Test**: Task={invariant}, Reasoner={invariant} → MATCH?
4. **Drift Anchor Coverage**: Required={list}, Present={list}, Coverage={X}/{Y}
   Minimum threshold: 60% (3/5 anchors)
5. **Self-Check Honesty**: Reported? Matches my assessment?

Verdict:
- PASS → proceed to Verifier
- FAIL → "Drift detected. Output discusses {topic} but task targets {target}. Resubmit."
```

---

## Drift Severity Scoring

| Score | Meaning | Action |
|-------|---------|--------|
| 0 | No drift — all anchors present, target matches | PASS |
| 1 | Minor — target correct, path deviated slightly | PASS with note |
| 2 | Moderate — target correct, invariant shifted | FAIL — revise |
| 3 | Major — different function entirely | FAIL — resubmit |
| 4 | Complete — different contract, unrelated topic | FAIL — investigate |

---

## Handling Drifted Discoveries

When drift reveals something interesting:
1. Do NOT suppress it
2. Do NOT include in current task
3. Log to `specs/hypotheses/DRIFT-DISCOVERY-TASK-{N}-{topic}.md`
4. Route to Threat Modeler for potential task formalization

---

## Common Drift Patterns

| Pattern | Prevention |
|---------|------------|
| "While analyzing X, I noticed Y has..." | Strict target matching |
| "The real issue isn't X, it's Y" | Invariant anchoring |
| "Let me also check the governance..." | Execution path fencing |
| "The more interesting question is..." | Task boundary enforcement |
