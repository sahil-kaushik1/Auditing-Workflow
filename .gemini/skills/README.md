# {{PROJECT_SHORT}} Skills

These skills are part of the **{{PROJECT_NAME}}** multi-agent harness for Gemini CLI.

## License

**License:** MIT (see [/LICENSE](/LICENSE))
**Copyright:** © 2026 J. Scott Graham ([@cheddarfox](https://github.com/cheddarfox)) / [ByBren, LLC](https://github.com/bybren-llc)
**Attribution:** Required per [/NOTICE](/NOTICE)

## Intellectual Property

The skill system architecture and {{PROJECT_SHORT}} harness methodology are the intellectual property of J. Scott Graham and ByBren, LLC.

SAFe® is a registered trademark of Scaled Agile, Inc.

## Core Audit Skills (P0)

| Skill | Trigger | Used By |
|-------|---------|---------|
| `solidity-decomposition` | Project ingestion | Decomposer |
| `task-compilation` | After decomposition | Threat Modeler |
| `drift-detection` | During reasoning | Deep Reasoner, Judge |
| `invariant-extraction` | During decomposition | Decomposer |
| `defi-patterns` | During threat modeling | Threat Modeler |
| `foundry-harness` | During verification | Verifier |

## Supporting Audit Skills (P1)

| Skill | Trigger | Used By |
|-------|---------|---------|
| `audit-reporting` | During report compilation | Report Compiler |
| `gap-analysis` | After cycle completion | Orchestrator |
| `state-machine-analysis` | During decomposition | Decomposer |
| `call-graph-analysis` | During SAST phase | SAST Integrator |
| `data-flow-tracking` | During SAST phase | SAST Integrator |
| `storage-layout-analysis` | During decomposition | Decomposer |
| `access-control-patterns` | During threat modeling | Threat Modeler |
| `cross-contract-analysis` | During business-flow decomposition | Threat Modeler |

## Evolution Skills (P2)

| Skill | Trigger | Used By |
|-------|---------|---------|
| `review-attribution` | After missed finding | Evolution Manager, Judge |
| `resource-scheduling` | During orchestration | Orchestrator |
| `evolution-tracking` | During long loop | Evolution Manager |
| `context-isolation` | Always | Context Builder |

## General-Purpose Utility Skills

| Skill | Purpose |
|-------|---------|
| `agent-coordination` | Agent assignment, blocker escalation |
| `git-advanced` | Rebase, bisect, cherry-pick, conflict resolution |
| `orchestration-patterns` | Multi-step task orchestration |
| `pattern-discovery` | Pattern-first development |
| `security-audit` | General security auditing (OWASP, RLS) |
| `team-coordination` | Agent Teams orchestration |
| `testing-patterns` | Unit, integration, E2E test patterns |

## Creating New Skills

See [/docs/guides/GEMINI_CLI_AUTHORING_GUIDE.md](/docs/guides/GEMINI_CLI_AUTHORING_GUIDE.md).