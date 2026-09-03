# Graph Lens And Visualization Contract

- Status: Accepted architecture contract under ADR 0011; implementation gated
- Specification version: `1.0.0`
- Accepted: 2026-09-03 through HUI-A3 merged-candidate governance
- Owners: JidoCode Product, Knowledge, wiki, security, and accessibility
  maintainers
- Milestone: F — Knowledge And Wiki Lenses
- Decision: [ADR 0011](../adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md)

## Purpose

This specification maps the seventeen graph families into task-oriented,
reviewed, bounded, authorized product lenses and defines provenance,
visualization selection, accessibility, expansion, export, and wiki behavior.

## Closed Lens Catalog

| Lens | Graph families | Default views |
|---|---|---|
| Factory/capacity | ontology, factory catalog, factory policy | Tables, policy/capability matrix, health summaries |
| Source | observation batch, source revision, repository control | Repository tree, file/symbol tables, revision comparison |
| Project domain | ontology and accepted repository knowledge | Glossary/entity table, bounded neighborhood |
| Work/execution | run attempt, run event segment, control facts | Work table, lifecycle rail, timeline |
| Evidence/decision | evidence and governed decision facts | Review queue, evidence matrix, lineage |
| Memory/experience | memory, experience, content lifecycle, episode content | Proposition/case table, citations, lifecycle |
| Wiki/dependencies | repository wiki plus source/dependency facts | Page tree/search, guide/dependency table/matrix/graph, history |
| Cross-project learning | memory dataset | Dataset catalog and coverage matrix |
| Security/audit | security audit and policy/control facts | Append-only table and incident timeline |
| Derived diagnostics | derived | Dependency/rebuild diagnostic tables |

The catalog is closed and versioned. Browser input selects only a lens key and
its allowed filters; it cannot select graph IRIs, SPARQL, query modules, joins,
or arbitrary expansion predicates.

## Projection Envelope

Every lens response includes safe:

- principal/scope digest and human scope label;
- lens/query/profile version;
- dataset, graph-family, source, and projection revisions;
- evaluated/as-of time and freshness;
- completeness, contradiction, truncation, maintenance, and recovery state;
- returned/limit/cursor information;
- citations/derivations and safe provenance family labels; and
- export availability under a separate grant.

Named graph context, authority, and contradiction are never silently flattened.

## Representation Selection

- Table: inventory, ownership, state, sorting, comparison.
- Tree: repository/containment hierarchy.
- Timeline: causal/temporal records.
- Matrix: dependencies, capabilities, project/coverage comparison.
- Small multiples: revision/state/cost comparison.
- Node-link: bounded paths, lineage, or small neighborhoods only.

Node-link requests specify allowed direction, relation set, depth, node/edge
count, bytes, query time, and expansion budget. Layout is stable for selected
nodes. Every visualization has a synchronized keyboard-readable table or
outline and never uses color/motion alone.

## Wiki And Dependency Requirements

The wiki lens preserves:

- source-backed authored user/developer/operator/architecture/contributing
  guides;
- deterministic Mix project and complete direct/transitive dependency facts;
- synthesized explanations with citations/confidence/conflicts/omissions; and
- live operational panels backed by current reviewed queries.

Dependencies show resolved version, direct/transitive role, scope/environment,
lock provenance, package/source/docs links, license when known, and project
relationship. Private previews remain bound to repository, task, interaction
session, attempt, candidate, fence, and audience.

Wiki enrollment/generation opt-out and cost are authoritative project policy,
not a UI preference. Disabled/not-enrolled, compiling, current, stale, budget-
paused, and recovery states remain explicit.

## Memory And Sensitive Lenses

Complete memory/episode content uses a separately authorized route and time-
bounded grant. Ordinary project access reveals neither content nor concealed
record counts/existence. Search snippets, export, citations, and graph neighbors
receive independent classification/redaction.

## Search, Pagination, And Export

All lenses use closed filters, stable ordering, opaque cursor, count/byte/time
limits, and explicit truncation. Search is authorized before aggregation.
Export is a separate POST operation with exact lens/query/scope/revision,
classification, row/byte/cost limits, expiry, audit, and content digest.

## Acceptance And Reopening

Milestone F closes when every enabled lens has a reviewed query, envelope,
bounds, table/outline, authorization/redaction tests, provenance and
contradiction cases, hostile content, pagination, private-preview isolation,
wiki dependency/guide completeness, and accessible browser evidence. It
reopens on arbitrary graph/query access, cross-family flattening, unbounded
expansion/export, missing accessible alternative, concealed aggregate leakage,
or preview/citation scope loss.
