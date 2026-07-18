# ToolAdapter — Deterministic Tool Invocation Contract

## Purpose

Defines how the harness invokes deterministic tools (Foundry, Slither, Echidna, etc.)
and what output format each tool must produce for downstream agents.

## Tool Catalog

| Tool | Phase | Agent | Purpose |
|------|-------|-------|---------|
| `slither` | 1 | SAST Integrator | Static vulnerability detection |
| `aderyn` | 1 | SAST Integrator | Additional static analysis |
| `semgrep` | 1 | SAST Integrator | Pattern-based detection |
| `forge build` | All | SAST Integrator | Compilation check |
| `forge test` | 3 | Verifier | Unit PoC execution |
| `forge test --fuzz` | 4 | Verifier | Foundry stateful invariants |
| `cast call` | 3 | Economic Analyst | On-chain state query |
| `cast balance` | 3 | Economic Analyst | ETH balance query |
| `medusa fuzz` | 5 | Verifier | Long-sequence fuzzing |
| `echidna` | 6 | Verifier | Property fuzzing |
| `halmos` | 7 | Verifier | Symbolic proof |
| `forge script` | 9 | Verifier | Fork-based exploit script |

## Tool Output Contract

Every tool invocation must produce:

```
tool_call_id:  UUID
tool:          string (tool name)
command:       string (exact shell command, reproducible)
exit_code:     int
output:        string (stdout + stderr, truncated to 10k chars if longer)
output_path:   string (path to full output file)
output_hash:   string (SHA256 of full output)
duration_sec:  float
succeeded:     bool (exit_code == 0)
```

## Invocation Rules

1. **Always capture exact command** — enough to reproduce on a fresh machine
2. **Always store full output** — truncate in display, never in storage
3. **Always hash output** — immutable evidence audit trail
4. **Pin fork block numbers** — `--fork-block-number $FORK_BLOCK` for reproducibility
5. **Never modify contracts** to make tools pass

## Standard Commands

```bash
# Slither — JSON output for parsing
slither . --json specs/sast/raw/slither-output.json \
  --exclude-informational \
  2>specs/sast/raw/slither-stderr.log

# Aderyn
aderyn . --output specs/sast/raw/aderyn-report.md

# Semgrep (Solidity rules)
semgrep --config p/solidity specs/sast/raw/semgrep-output.json

# Forge build
forge build 2>&1 | tee specs/sast/raw/forge-build.log

# Forge test (PoC)
forge test --match-test test_exploit -vvvv 2>&1 | tee specs/verification/TASK-{N}-forge.log

# Forge test (invariants)
forge test --match-test invariant_ --fuzz-runs 10000 -vvv 2>&1

# Cast — on-chain query (pin block)
cast call $CONTRACT "totalAssets()(uint256)" \
  --rpc-url $RPC_URL \
  --block $FORK_BLOCK

# Medusa
medusa fuzz --config medusa.json 2>&1 | tee specs/verification/TASK-{N}-medusa.log

# Echidna
echidna . --contract TargetEchidna --config echidna.yaml \
  2>&1 | tee specs/verification/TASK-{N}-echidna.log

# Halmos
halmos --function check_{invariant} --loop 3 \
  2>&1 | tee specs/verification/TASK-{N}-halmos.log
```

## Tool Failure Handling

| Exit Code | Meaning | Action |
|-----------|---------|--------|
| 0 | Success | Proceed |
| 1 | Tool error / test failure | Capture stderr, log to tool_calls table |
| 127 | Tool not found | Halt + instruct user to install |
| Timeout | Tool hung | Kill after 5 min, mark INCONCLUSIVE-TOOL-TIMEOUT |

If a critical tool (forge, slither) is unavailable:
```
Report: "TOOL-UNAVAILABLE: {tool_name}. Install instructions: {url}"
Do not proceed with verification until tool is available.
```
