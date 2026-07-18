# VerifierAdapter — Blind Verification Protocol Contract

## The Principle

The Verifier is an independent witness, not a re-validator.
If it reads the Reasoner's full analysis, it becomes biased toward confirmation.
This adapter defines EXACTLY what the Verifier receives and produces.

## INPUT CONTRACT (immutable — never modify)

```
ALLOWED:
  ✓ specs/tasks/TASK-{N}.md           full 19-field task
  ✓ specs/verification/TASK-{N}-claim.md   normalized claim (Orchestrator-stripped)
  ✓ specs/reasoning/TASK-{N}-skeptic.md   skeptic verdict (verdict line only)
  ✓ [contract source files]           listed in task.target and task.execution_path

BLOCKED:
  ✗ specs/reasoning/TASK-{N}-reasoning.md
  ✗ Reasoner's execution trace or state analysis
  ✗ Reasoner's explanation of WHY the path is vulnerable
  ✗ Any prior verification artifact for this task
  ✗ Working memory from the Reasoner's task
```

## OUTPUT CONTRACT (immutable — validate-outputs.sh enforces this)

Every verification artifact MUST contain:

```yaml
## Required Fields

task_id:                string    # TASK-{N}
verdict:                string    # CONFIRMED | REFUTED | INCONCLUSIVE | SKIPPED-SKEPTIC-KILLED
evidence_type:          string    # foundry_poc | invariant_test | fuzz_corpus | symbolic | manual_trace
tool_used:              string    # forge | echidna | medusa | halmos | slither
tool_command:           string    # exact command (reproducible)
tool_exit_code:         int       # actual exit code
tool_output_path:       string    # path to stored output
tool_output_hash:       string    # SHA256

violated_invariant:     string | null
balance_delta:          string | null   # "attacker gains 500k USDC"
gas_cost_of_exploit:    int | null      # gas units from forge output

counterfactual_fix_tested: bool   # was the fix applied and tested?
counterfactual_fix_result: string | null   # "PoC fails after fix" | null

gate_results_table:     string    # markdown table (for CONFIRMED findings)
gates_passed:           int       # 0-10

independent_reasoning:  string    # why THIS verdict, independent of Reasoner
caveats:                string[]  # verification limitations (fork block, mock limitations)

poc_file_path:          string | null   # path to .t.sol file
```

## Skeptic-Killed Handling

If `specs/reasoning/TASK-{N}-skeptic.md` contains `Verdict: KILLED`:

```yaml
# Write immediately without running any tools:
task_id:    TASK-{N}
verdict:    SKIPPED-SKEPTIC-KILLED
evidence_type: none
tool_used:  none
independent_reasoning: >
  Skeptic killed this finding. Challenges that failed:
  {list from skeptic report}
  No verification attempted per blind-verification protocol.
```

## Determinism Requirement

For CONFIRMED verdicts:
- PoC must pass 3 consecutive runs without modification
- If it passes 2/3: `INCONCLUSIVE-FLAKY-POC`
- If it passes 1/3: `REFUTED`

```bash
# Document all 3 runs in the artifact:
Run 1: forge test --match-test test_exploit -vvvv → exit 0 ✓
Run 2: forge test --match-test test_exploit -vvvv → exit 0 ✓
Run 3: forge test --match-test test_exploit -vvvv → exit 0 ✓
```
