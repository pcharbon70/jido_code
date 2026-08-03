# Architecture

This directory contains the accepted implementation boundaries for JidoCode.
The documents distinguish architectural authority from research and delivery
planning:

1. Accepted ADRs under [`docs/adr`](../adr/) define binding decisions.
2. Architecture documents in this directory define the current evidence and
   module boundaries that implement those decisions.
3. [`docs/research`](../research/) records analysis and recommendations.
4. [`.planning`](../../.planning/) sequences implementation work but does not
   override an accepted ADR or tested backend constraint.

## Phase 1 Baseline

- [Current-state inventory](./current-state-inventory.md)
- [Module and plane boundaries](./module-boundaries.md)
- [Backend compatibility contract](./backend-compatibility.md)
- [Failure, health, and telemetry contract](./failure-health-and-telemetry.md)
- [Architecture guardrails](./architecture-guardrails.md)
- [Phase 1 architecture and compatibility receipt](./phase-01-receipt.md)
- [ADR 0001: Graph-only source of truth](../adr/0001-graph-only-source-of-truth.md)
- [ADR 0002: TripleStore backend contract](../adr/0002-triple-store-backend-contract.md)

The Phase 1 baseline starts at commit
`54cda0fd34cc687f0c1be6322513a790d3a9c37e`, immediately after the graph-native
implementation plan was merged.

## Phase 2 Substrate

- [Authoritative store lifecycle](./store-lifecycle.md)
- [Atomic writes and revisions](./atomic-writes-and-revisions.md)
- [Backup, restore, export, and integrity](./backup-restore-and-integrity.md)
- [Knowledge store operations runbook](../operations/knowledge-store-runbook.md)
- [Phase 2 durable substrate receipt](./phase-02-receipt.md)

## Phase 3 Semantic Contract

- [Factory ontology contract](./factory-ontology.md)
- [Graph identity and topology](./graph-identity-and-topology.md)
- [Semantic validation and evolution](./semantic-validation-and-evolution.md)
- [Claims, time, transitions, and inference](./claims-time-transitions-and-inference.md)
- [Phase 3 semantic contract receipt](./phase-03-receipt.md)

## Phase 4 Controlled Mutation

- [Semantic command contract](./semantic-command-contract.md)
- [Governed command pipeline](./governed-command-pipeline.md)
- [Authority, bootstrap, and audit](./authority-bootstrap-and-audit.md)
- [Change delivery and command recovery](./change-delivery-and-command-recovery.md)
- [Phase 4 controlled mutation receipt](./phase-04-receipt.md)

## Phase 5 Bounded Reads

- [Reviewed query catalog and execution boundary](./reviewed-query-catalog.md)
- [Query consistency and temporal state](./query-consistency-and-temporal-state.md)
- [Bounded projections, cache, and subscriptions](./bounded-projections-cache-and-subscriptions.md)
- [Derived graphs and read diagnostics](./derived-graphs-and-read-diagnostics.md)
- [Phase 5 bounded interpretation receipt](./phase-05-receipt.md)

## Phase 6 Repository Knowledge

- [Source analysis boundary](./source-analysis.md)
- [Phase 6 repository knowledge receipt](./phase-06-receipt.md)

## Phase 7 Factory Control Loop

- [Factory control loop](./factory-control-loop.md)
- [Phase 7 factory control loop receipt](./phase-07-receipt.md)

## Phase 8 Governed Execution

- [Execution runtime boundary](./execution-runtime-boundary.md)
- [Execution attempt lifecycle](./execution-attempt-lifecycle.md)
- [Governed execution effects and artifacts](./execution-effects-provenance.md)
- [Execution provenance and recovery](./execution-provenance-and-recovery.md)
- [Phase 8 governed execution receipt](./phase-08-receipt.md)
