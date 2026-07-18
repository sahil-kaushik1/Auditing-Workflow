# Pattern: Regression Check

## Purpose
Verify that a component change doesn't cause previously-detected vulnerabilities
to be missed.

## Protocol

1. Maintain a benchmark set of contracts with known vulnerabilities
2. Before any change: run the full pipeline on the benchmark. Record findings.
3. After the change: run the same pipeline. Record findings.
4. Compare: Are all previously-found vulnerabilities still found?
5. If ANY previously-found vulnerability is now missed → REJECT the change

## Rule
**No change is worth a regression.** An improvement that causes a miss is a net loss
because regressions are harder to detect than improvements.
