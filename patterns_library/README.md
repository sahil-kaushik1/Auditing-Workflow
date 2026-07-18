# Patterns Library — Smart Contract Auditing

> Reusable analysis patterns for the 3-stage audit pipeline.
> **37 patterns** across 6 categories.

---

## Decomposition Patterns (9)

How to systematically break down a project across the 10 dimensions.

| Pattern | File | Used By |
|---------|------|---------|
| Module Decomposition | [module-decomposition.md](decomposition/module-decomposition.md) | Decomposer |
| Entrypoint Decomposition | [entrypoint-decomposition.md](decomposition/entrypoint-decomposition.md) | Decomposer |
| Data Flow Decomposition | [data-flow-decomposition.md](decomposition/data-flow-decomposition.md) | Decomposer |
| Asset Lifecycle | [asset-lifecycle.md](decomposition/asset-lifecycle.md) | Decomposer |
| State Machine | [state-machine.md](decomposition/state-machine.md) | Decomposer |
| Permission Flow | [permission-flow.md](decomposition/permission-flow.md) | Decomposer |
| Async / Message Flow | [async-message-flow.md](decomposition/async-message-flow.md) | Decomposer |
| Configuration / Deployment | [config-deployment.md](decomposition/config-deployment.md) | Decomposer |
| Invariant Extraction | [invariant-extraction.md](decomposition/invariant-extraction.md) | Decomposer |

## Vulnerability Class Patterns (11)

Known vulnerability archetypes with detection heuristics and task templates.

| Pattern | File | Used By |
|---------|------|---------|
| Reentrancy (all variants) | [reentrancy.md](vulnerability-classes/reentrancy.md) | Threat Modeler, Deep Reasoner |
| Oracle Manipulation | [oracle-manipulation.md](vulnerability-classes/oracle-manipulation.md) | Threat Modeler |
| Flash Loan Attacks | [flash-loan-attacks.md](vulnerability-classes/flash-loan-attacks.md) | Threat Modeler |
| Arithmetic / Precision Loss | [arithmetic.md](vulnerability-classes/arithmetic.md) | Threat Modeler, Deep Reasoner |
| Access Control | [access-control.md](vulnerability-classes/access-control.md) | Threat Modeler |
| Frontrunning / MEV | [frontrunning-mev.md](vulnerability-classes/frontrunning-mev.md) | Threat Modeler |
| Storage Collision | [storage-collision.md](vulnerability-classes/storage-collision.md) | Threat Modeler |
| Cross-Contract Composability | [cross-contract.md](vulnerability-classes/cross-contract.md) | Threat Modeler |
| Denial of Service | [denial-of-service.md](vulnerability-classes/denial-of-service.md) | Threat Modeler |
| Logic Errors | [logic-errors.md](vulnerability-classes/logic-errors.md) | Threat Modeler, Deep Reasoner |
| Governance Attacks | [governance.md](vulnerability-classes/governance.md) | Threat Modeler |

## Business Flow Patterns (5)

Cross-contract and multi-step operation analysis.

| Pattern | File | Used By |
|---------|------|---------|
| Operation Flow | [operation-flow.md](business-flows/operation-flow.md) | Threat Modeler |
| Asset Lifecycle Flow | [asset-lifecycle-flow.md](business-flows/asset-lifecycle-flow.md) | Threat Modeler |
| State Machine Flow | [state-machine-flow.md](business-flows/state-machine-flow.md) | Threat Modeler |
| Collaboration Flow | [collaboration-flow.md](business-flows/collaboration-flow.md) | Threat Modeler |
| Invariant Flow | [invariant-flow.md](business-flows/invariant-flow.md) | Threat Modeler |

## Verification Patterns (5)

How to prove or disprove a vulnerability hypothesis.

| Pattern | File | Used By |
|---------|------|---------|
| Foundry PoC | [foundry-poc.md](verification/foundry-poc.md) | Verifier |
| State Delta Check | [state-delta-check.md](verification/state-delta-check.md) | Verifier |
| Counterexample Search | [counterexample-search.md](verification/counterexample-search.md) | Verifier |
| Mathematical Proof | [mathematical-proof.md](verification/mathematical-proof.md) | Verifier |
| Differential Testing | [differential-testing.md](verification/differential-testing.md) | Verifier |

## Reporting Patterns (4)

Structured output formats for findings and coverage.

| Pattern | File | Used By |
|---------|------|---------|
| Finding Template | [finding-template.md](reporting/finding-template.md) | Report Compiler |
| Gap Record | [gap-record.md](reporting/gap-record.md) | Report Compiler |
| Coverage Map | [coverage-map.md](reporting/coverage-map.md) | Report Compiler |
| Review Attribution | [review-attribution.md](reporting/review-attribution.md) | Report Compiler, Evolution Manager |

## Evolution Patterns (3)

How to safely change scanner components across audits.

| Pattern | File | Used By |
|---------|------|---------|
| Component Experiment | [component-experiment.md](evolution/component-experiment.md) | Evolution Manager |
| Regression Check | [regression-check.md](evolution/regression-check.md) | Evolution Manager |
| Inheritance Criteria | [inheritance-criteria.md](evolution/inheritance-criteria.md) | Evolution Manager |
