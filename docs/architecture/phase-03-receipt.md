# Phase 3 Semantic Contract Receipt

## Status

This receipt records the Phase 3 candidate verified locally on 2026-07-31.
Versioned ontology and shapes, canonical identities, closed named-graph
topology, pre-commit validation, bitemporal claims, causal transitions,
ontology evolution, and derived authority are implemented and pass the local
repository gates. Pull request 5 passed clean-checkout CI and was merged as
`3b59f8e659f5bcc9453897236b70893351157b81`.

G2 is complete and Phase 4 is authorized. No evidence found an object-record
codec, ownerless application graph, invalid visible assertion, literal
foreign-key join, or derived authority escalation.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G1 | `cd49d7799cfa7c726d38ff699aaf758e0ff245d4` |
| Section 3.1 | `95da345` - define versioned factory ontology |
| Section 3.2 | `b57535b` - implement canonical graph topology |
| Section 3.3 | `74ed8b0` - implement semantic validation and evolution |
| Section 3.4 | `7f2896b` - define temporal claims and inference authority |
| Section 3.5 | This receipt and its integration tests; exact commit recorded by Git history |
| Merged candidate | `3b59f8e659f5bcc9453897236b70893351157b81` |

## Semantic Pins

| Contract | Accepted candidate value |
| --- | --- |
| Factory ontology version | `1.0.0` |
| Operational shape version | `1.0.0` |
| Ontology package SHA-256 | `5ce8be304d026d5eeaaf3693caceee6dc675e4325089f33e1e3f8b73535c5903` |
| Canonical ontology N-Quads SHA-256 | `fe260c98204872ace7369728c4db13696f76c724cc5f06b4bfe7bf5b18569e41` |
| Canonical ontology quad count | `971` |
| Ontology graph | `https://jido.run/graph/ontology/1.0.0` |
| Resource namespace | `https://jido.run/id/` |
| Named-graph namespace | `https://jido.run/graph/` |
| Graph registry revision | `1.0.0` |
| Validator version | `1.0.0` |
| TripleStore pin | `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` |

`manifest.json` is itself SHA-256
`90414444e0034823f1a4d411a8a7b6611415af3e35f167da2591db5d0c07ed56`.
Imports remain declarative and are never fetched at runtime.

## Accepted Contract

- Product facts exist only as RDF resources and relationships in registered
  named graphs. The default graph remains empty, and no object-record codec or
  parallel persistence dependency is admitted.
- Every application graph has graph-local kind, ownership, ontology,
  creation, lifecycle, completeness, revision, and retention metadata committed
  atomically with its payload.
- Stable provider, repository, locator, Git object, digest, scope, local,
  validation, and graph-revision-reference IRIs replace foreign-key literals.
- Consequential, disputable, temporal, assessed, or governed propositions are
  first-class claims. Confidence never implies acceptance; acceptance and
  rejection require a complete decision resource.
- `recordedAt` transaction time is distinct from source generation,
  observation, validity, and invalidation time. Command callers supply clocks;
  causal order never comes from wall time.
- Current operational state is the endpoint of one contiguous accepted
  predecessor/revision chain. Rejected and superseded concurrent proposals
  remain history.
- Ontology changes are classified before use. Transform-required changes
  create attributed target graphs without rewriting source graphs, and stale
  preconditions leave no partial target.
- Derived graphs name rule set, ontology, generation activity, invalidation
  state, and first-class source graph revisions. They are disposable and
  advisory unless an asserted governed decision consumes them.

## Fixture Identity

| Evidence fixture | SHA-256 |
| --- | --- |
| Semantic round-trip and derived rebuild | `70fd4414069cbd6bc9286454e76f235e8298b77aaa9a6ea91b6869fd4d1cb447` |
| Invalid visibility, transition race, and migration recovery | `785093414a1289ff6bf7f69fdfdc4d052883d6f9f09f580bdbc093a9ac7bbedc` |

These files use only public semantic commands, fixed maintenance operations,
and parsed standards-based exports. They do not expose a raw store handle or
provide an alternate mutation path.

## Executable Evidence

The Phase 3 integration suite proves:

- local source verification, canonicalization, checksum, ontology load,
  N-Quads export, checkpoint restore, value-aware term equality, and exact
  canonical export-byte equality before and after restore;
- repository enrollment, policy, observation, goal/task, execution attempt,
  evidence, accepted claim, and decision resources across six application
  graph families, with every required fixture relationship joined by IRI;
- ontology and instance graph separation, graph-local ownership metadata, and
  an empty default graph after restore;
- rejection of malformed or cross-scope identities, unregistered graph links,
  missing metadata, wrong graph-family classes, invalid claim cardinality,
  unknown epistemic state, invalid datatype/confidence, and secret-like
  literals without dataset or graph revision change;
- two same-time accepted transition successors produce a conflict, while one
  explicit accepted decision and one rejected decision produce one endpoint
  and retain the losing proposal;
- additive compatibility and transform-required migration plans, stale
  interrupted migration with no partial target, successful retry, validation
  report and rollback posture, and unchanged immutable source graph;
- checkpoint disposal of a stale derived graph followed by creation of a new
  derived revision from unchanged asserted graph revisions; and
- the complete Phase 1-2 invariant suites continue to pass with the Phase 3
  semantic startup and write gates enabled.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 3 integration files | 4 tests, 0 failures |
| `mix precommit` | 121 tests, 0 failures; compile, architecture, lock, and format gates passed |
| `mix jido_code.ontology verify` | Package and canonical digests verified |
| `mix hex.audit` | No retired packages found |
| `npm audit --omit=dev` | 0 vulnerabilities |
| `MIX_ENV=prod mix assets.build` | Vite client and SSR bundles built successfully |

`mix precommit` compiles with warnings as errors, enforces architecture and
graph-only persistence, checks unused dependency locks, formats the tree, and
runs the complete ExUnit suite.

## Operational Limits

- Shape validation is the closed-world write-admission subset; RDFS and OWL
  remain open-world semantic guidance.
- Validation evaluates at most 10,000 effective quads and returns at most 100
  bounded issues. Temporal projections are bounded to 10,000 inputs and 1,000
  results.
- Derived metadata reads admit at most eight distinct source graph revision
  references. Larger reasoning sets require a future paged manifest graph.
- Ordinary writes do not delete assertions. Immutable history is superseded,
  migrations create target graphs, and derived disposal uses verified dataset
  recovery until a dedicated bounded derived-maintenance command is accepted.
- G2 authorizes Phase 4 from the pinned clean-CI merge commit.

## Gate G2

G2 is **complete**. The semantic contract, local integration evidence,
clean-checkout CI, and merged candidate are pinned.
