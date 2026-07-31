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
