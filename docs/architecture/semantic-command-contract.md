# Semantic Command Contract

Phase 4 introduces one versioned boundary for graph-visible product mutation.
Command envelopes and change sets are bounded transient values; they are never
serialized as the durable model. RDF command, provenance, audit, and receipt
resources committed by the write pipeline remain authoritative.

## Envelope

Every command carries an exact registry name/version, canonical command IRI,
authenticated principal and accountable actor, optional delegated agent and
delegation IRI, scope, idempotency material, correlation and causation IRIs,
ontology and shape versions, expected revisions, a bounded reason, and a time
from an explicit trusted clock. Payloads contain RDF terms and canonical graph
references, not entity records.

`Inspect` and `safe_map/1` omit statement bodies, reasons, and idempotency
material. Callers cannot supply the trusted issued time, dispatch modules, or
atoms.

## Change Set

A change set canonically orders RDF quads and fingerprints the complete logical
request before mutable graph state is read. It distinguishes assertions,
supersession, invalidation, and maintenance-only removal. Ordinary commands
cannot delete graph contents, replace subjects wholesale, target the substrate
system graph, or write a graph family outside their registry definition.

## Registry

Registry version `1.0.0` contains only the twelve intent names accepted by the
architecture plan. Each definition declares ownership, semantic capability,
allowed graph families, and named preconditions. Generic create, update, and
delete entity operations are not part of the public boundary.

## Outcomes

Command receipts distinguish committed, replayed, rejected, conflicted,
unauthorized, invalid, unavailable, and unknown-after-timeout outcomes.
Unauthorized receipts contain no command IRI, current revision, policy, or
issue details. Other failures expose only bounded stable issue codes and retry
guidance.
