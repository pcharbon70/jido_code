# Query Consistency And Temporal State

Graph answers are meaningful only with their evaluated revision, time, and
completeness boundary. Phase 5 therefore makes these inputs and outputs explicit
rather than allowing callers to infer freshness from wall time or absence.

## Consistency Contract

`QueryConsistency` supports four modes:

- `strict` requires every stated revision, ontology, completeness, and derived
  rule-set condition. A mismatch returns a redacted `stale_precondition` plus
  the evaluated `ConsistencyReceipt`.
- `warn` returns bounded data with a degraded receipt and explicit gap warnings.
- `historical` requires an exact retained named-graph set and otherwise fails
  like strict mode.
- `best_effort` is the default and still records the evaluated revisions and
  any requested constraint gaps.

Exact and minimum revisions cannot be combined for the same boundary. Valid
instants and intervals are mutually exclusive. Historical graph count and time
range are bounded. Authorization runs before constraint evaluation so revision
receipts cannot disclose graphs outside the actor's current scope.

Every result includes its consistency receipt. Truncation cursors bind query
identity, dataset revision, graph revisions, and the constraint digest; later
pages must retain that exact context.

## Causal Current State

`CurrentStateResolver` reads `StateTransition` and `Decision` relationships and
delegates chain validation to the Phase 3 transition contract. It requires:

- one genesis transition and contiguous monotonic subject revisions;
- each accepted transition to name the expected accepted predecessor;
- legal state concepts and edges;
- one unambiguous decision disposition per transition;
- one unique accepted endpoint.

The result contains state, endpoint transition, chain revision, actor, cause,
and evaluated graph revision. Missing links, forks, cycles, revision regression,
illegal concepts, and decision ambiguity are integrity conflicts. A
`CurrentStateCache` may retain a result only under its exact graph revision;
cache loss or a different revision is a miss and requires graph recomputation.

## Closed-World Boundaries

`CompletenessBoundary` attributes coverage to one assertion, subject, scope,
graph family, source graph revision, predicate/class set, producer, and validity
interval. Operational negation is known only when exactly one current assertion
covers the entire requirement. Missing, stale, invalidated, or contradictory
coverage returns `unknown`, never `false`.

## Bitemporal Selection

`TemporalSelection` independently constrains transaction revision, retained
historical graph set, source-observed time, valid time, invalidation,
supersession, and result count. It returns concurrent incompatible assertions
with their attribution and flags contradiction instead of selecting the newest
literal. This preserves the distinction between what the factory knew and what
was externally valid.
