# Phase 5 Bounded Interpretation Receipt

## Status

This receipt records the Phase 5 candidate verified locally on 2026-07-31.
Reviewed catalog queries, explicit consistency and temporal boundaries,
attributable projections, disposable caches, revision-aware subscriptions,
governed derived graphs, and bounded read diagnostics are implemented and pass
the local repository gates.

Pull request 7 passed clean-checkout CI and was merged as
`97690f4796433baca759e5f294e71b0bda9a7991`. G4 is complete and Phase 6 is
authorized. No evidence found a caller-controlled SPARQL path, unattributed result,
authoritative cache or notification dependency, stale strict read, or
projection that remains accessible after grant revocation.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G3 | `b99826b447260cef998b62b3053586aa857eea4f` |
| Section 5.1 | `28a5128` - implement reviewed query catalog boundary |
| Section 5.2 | `47776e2` - implement temporal query consistency |
| Section 5.3 | `c9c24c6` - implement bounded projection delivery |
| Section 5.4 | `7e6617e` - implement derived graph lifecycle |
| Section 5.5 | This receipt and its integration tests; exact commit recorded by Git history |
| Merged candidate | `97690f4796433baca759e5f294e71b0bda9a7991` |

## Contract Pins

| Contract | Accepted candidate value |
| --- | --- |
| Query catalog version | `1.0.0` |
| Query catalog SHA-256 | `edf29901a205f5f2677184b7217a0c3a31d0d30bd75f0ca49d8b02009d2fa41e` |
| Reviewed queries | 17 |
| Projection catalog version | `1.0.0` |
| Projection catalog SHA-256 | `7c88321d64ffa67c8c6cd26603ed5bbb9337104d949348c114435dc9a85bf282` |
| Consistency modes | `strict`, `warn`, `historical`, `best_effort` |
| Factory ontology version | `1.0.0` |
| Operational shape version | `1.0.0` |
| Ontology package SHA-256 | `5ce8be304d026d5eeaaf3693caceee6dc675e4325089f33e1e3f8b73535c5903` |
| Canonical ontology N-Quads SHA-256 | `fe260c98204872ace7369728c4db13696f76c724cc5f06b4bfe7bf5b18569e41` |
| Ontology manifest SHA-256 | `90414444e0034823f1a4d411a8a7b6611415af3e35f167da2591db5d0c07ed56` |
| TripleStore pin | `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` |
| Projection cache | Process memory, maximum 1,000 entries |
| Notification transport | Phoenix PubSub revision hints; non-authoritative |

The query catalog covers dataset and graph metadata, ontology compatibility,
command and audit references, graph health, bounded resource neighborhoods,
provenance, supporting and contradicting claims, supersession, transition
endpoint and history, temporal as-of, completeness, and derived freshness.

## Accepted Contract

- Callers supply a fixed query name/version, exact typed parameters, authority,
  scope, and optional consistency constraints. They cannot supply query text,
  graph clauses, decoder functions, mutation forms, or federation clauses.
- Every result identifies its query, evaluated dataset and graph revisions,
  ontology, completeness, freshness, truncation, cursor, warnings, execution
  class, and consistency receipt.
- Authorization is evaluated from the policy graph in the same serialized
  store request as the graph snapshot and reviewed query execution.
- Missing facts remain unknown unless one current completeness assertion
  exactly covers the requested subject, scope, graph, revision, and terms.
- Current state follows one accepted predecessor chain. Temporal helpers retain
  concurrent incompatible claims and separate recorded, observed, valid, and
  invalidated time.
- Projection envelopes are JSON-safe attributable copies. Canonical IRIs are
  preserved separately from escaped display labels.
- Cache hits require the same dataset, graph, ontology, authority, and
  consistency context. Eviction, reset, process loss, or a newer change hint
  causes a canonical re-query.
- Subscription events are disposable wake-up hints. Duplicate, reordered,
  coalesced, missed, and reconnect events converge by running the current
  authorized query; revoked authority fails closed.
- Derived graphs bind exact source revisions and rule/query/ontology versions.
  Strict consumers reject stale derivations, while warning consumers receive
  explicit stale diagnostics and rebuild guidance.

## Fixture Identity

| Evidence fixture | SHA-256 |
| --- | --- |
| Shared real-substrate Phase 5 graph fixture | `b4d6802954ff29d8d8383f5616fd45f28784ad574826f158be6f235a7d5b970b` |
| Catalog, temporal, injection, and concurrency integration | `6fa30d8c0599dd19b06e59e95662d49c8f565359d0af748067ec592dcb343dc8` |
| Projection, cache, subscription, authorization, and performance integration | `b3278575c292fd9b43927e5631f06e275809836ed9262c32a77fa1e5c525290a` |

The fixtures start the real StoreServer, Writer, QueryRunner, PubSub, and
TripleStore substrate; load the pinned ontology; bootstrap graph authority;
and create all facts through semantic commands and governed derived
publication. They do not obtain a raw store handle or persist a second read
model.

## Executable Evidence

The Phase 5 integration and retained unit suites prove:

- every initial query executes over authorized multi-graph data and fails
  closed for an ungranted actor;
- quotes, braces, control characters, encoded escapes, query keywords, graph
  widening, undeclared parameters, malformed cursors, and over-limit history
  cannot alter reviewed query structure or scope;
- concurrent reads return only coherent before-commit or after-commit dataset
  and source-graph revision pairs;
- historical and bitemporal selection preserve bounds and contradictory
  claims, while uncovered absence remains unknown;
- projection cache warm, hit, eviction, commit invalidation, reset, deletion,
  and restart preserve canonical uncached answers;
- duplicate, reordered, coalesced, missed, and reconnect change hints converge
  to the latest authorized dataset revision;
- derived publication, stale detection, explicit stale marking, rebuild,
  logical deletion, and strict/warn behavior preserve asserted graph authority;
- revoking the persisted observation grant during an active subscription makes
  its next query and projection inaccessible; and
- 25 bounded graph-metadata reads finish within the 10-second integration
  baseline and emit only allowlisted low-cardinality telemetry.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 5 integration files | 9 tests, 0 failures |
| `mix precommit` | 163 tests, 0 failures; compile, architecture, lock, and format gates passed |
| `mix jido_code.ontology verify` | Package and canonical digests verified |
| `mix hex.audit` | No retired packages found |
| `npm audit --omit=dev` | 0 vulnerabilities |
| `MIX_ENV=prod mix assets.build` | Vite client and SSR bundles built successfully |

## Operational Limits

- Every catalog definition defaults to a 5-second timeout, 200 rows, 500
  triples, 256,000 decoded bytes, traversal depth 2, 20 graphs, and 100 values
  in one parameter collection. One extra row or triple is fetched only to
  identify truncation.
- Consistency requests admit at most 20 exact, minimum, complete, or historical
  graphs. Valid-time intervals cannot exceed 3,660 days.
- Temporal selection admits at most 10,000 assertions and returns at most 1,000
  results. It does not fabricate retained historical graphs.
- Projection caches are optional process state and evict after 1,000 entries.
  PubSub events carry at most 20 affected graph-family revisions and no answer
  payload.
- Derived replacement is restricted to the reviewed `PublishDerivedGraph`
  command at version `1.1.0`; ordinary asserted graph mutation remains
  append/supersession/invalidation based.
- Repository, goal, execution, and product-surface query vocabularies remain
  owned by later phases.

## Gate G4

G4 is complete. The bounded-interpretation evidence passed clean-checkout CI,
and the accepted merge commit is pinned above. Phase 6 is authorized from that
immutable baseline.
