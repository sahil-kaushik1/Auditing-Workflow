# Adapter Layer — SAW Harness

The adapter layer defines **protocol contracts** — typed interfaces that any
model provider or tool integration must satisfy. These are not code; they are
formal specifications that make the harness provider-agnostic.

## Adapters

| File | Purpose | Used By |
|------|---------|---------|
| `model_adapter.md` | Model invocation + capability contract | Orchestrator, all agents |
| `tool_adapter.md` | Tool invocation + output format contract | Verifier, SAST Integrator |
| `prompt_adapter.md` | Prompt versioning + structure contract | All agents |
| `memory_adapter.md` | 7-layer memory access policy | All agents |
| `verifier_adapter.md` | Blind verification INPUT/OUTPUT contract | Orchestrator, Verifier |
| `report_adapter.md` | Report format contract | Report Compiler |

## Design Principle

> No security logic is hardcoded inside model-specific prompts.
> The adapter layer absorbs provider and model volatility.
> Swap the provider in model-config.yml — the harness works identically.

## Relationship to model-config.yml

`model-config.yml` specifies WHICH model to use per agent role.
The adapter files specify WHAT INTERFACE that model must satisfy.
Together, they form the complete model-independence contract.
