# Phase 6 Repository Knowledge Receipt

## Status

This receipt records the Phase 6 candidate verified locally on 2026-08-01.
Conceptual repository enrollment, provider locators, external observation
batches, exact Git snapshots, deterministic source analysis, immutable source
graphs, and bounded source projections are implemented through the graph-only
authority boundary.

G5 is closed. Pull request #8 passed clean-checkout CI and merged as
`394657afdb1ad2453f7f21a0ceef61351d60860e` on 2026-08-03. No local
evidence found a durable identity dependent on a checkout path, a provider or
analyzer with direct commit authority, schema mixed into a source graph,
duplicate delivery effects, partial source publication, accepted control truth
created from provider output, or credentials/raw source in persisted or public
surfaces.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Phase baseline and merged G4 | `97690f4796433baca759e5f294e71b0bda9a7991` |
| Section 6.1 | `4925116` - implement repository enrollment semantics |
| Section 6.2 | `039bf6a` - add repository observation adapters |
| Section 6.3 | `7f403f6` - persist immutable repository observations |
| Section 6.4 | `16d6405` - publish revision-scoped source semantics |
| Section 6.5 | This receipt and its integration tests; exact commit recorded by Git history |
| Merged candidate | `394657afdb1ad2453f7f21a0ceef61351d60860e` |

## Contract Pins

| Contract | Accepted candidate value |
| --- | --- |
| Command registry version | `1.1.0` |
| Registered intent commands | 16 |
| Repository/query catalog version | `1.1.0` |
| Reviewed queries | 34 |
| Query catalog SHA-256 | `6b02cedc4409da1ddd181ecd635a969fedcef599d9ba6780cb66e2248fbb2ae6` |
| Factory ontology / operational shapes | `1.0.0` / `1.0.0` |
| Ontology package SHA-256 | `5ce8be304d026d5eeaaf3693caceee6dc675e4325089f33e1e3f8b73535c5903` |
| TripleStore pin | `6dc1b6d985f4805f9856858e0c0047b9f2d5ad7f` |
| HTTP provider boundary | Req `~> 0.5`; bounded fake profile `fake-provider/1.0.0` |
| Git fixture runtime | `git version 2.49.0` |
| Source analyzer | `elixir-ast/1.0.0`, pinned Elixir parser/Macro profile |
| Initial fixture commit | `3aa4af81fe56b0aeb5c4ed900bdfe96d0b74034d` |
| Initial fixture tree | `abab0e5418ae59d6c7640d93e053833a982978e0` |
| Initial observation graph SHA-256 | `13caebf6a1a9fd2b3c44c777ff21aef981b505345be1e5dc4917ba4a2888a493` |
| Initial source graph SHA-256 | `0f98d99e78e6847085acd289bf265fa2aec90696bc416c2930a3cec38a7fe489` |
| Analyzer dataset SHA-256 | `c1e8688f2de36f3620195685924f0d3ce82821a915a7e1b092f89173e09035b6` |

The source graph and analyzer dataset digests are distinct by design. The
former includes closed named-graph metadata, coverage, counts, and publication
provenance; the latter covers only the analyzer's canonical RDF result.

## Accepted Contract

- A conceptual repository IRI is independent of provider address and local
  checkout. Provider-stable external IDs identify locators; transfer, redirect,
  archival, deletion, alias, mirror, and fork facts remain explicit history.
- Enrollment is a governed accepted transition chain. Suspended, retiring,
  retired, or invalidated enrollment blocks new observation admission without
  deleting prior observations or source graphs.
- Provider, Git, webhook, secret, clock, and analyzer adapters return bounded
  transient evidence. None receives a store handle, graph mutation API, or
  authority to accept claims or desired state.
- Polling and webhook ingress bind one authenticated delivery to one enrollment
  and locator. The semantic mapper rechecks both bindings before command
  construction to reject cross-enrollment or cross-locator substitution.
- Observation batches are immutable closed graphs with exact delivery,
  adapter, retrieval, source, completeness, claim, contradiction, and snapshot
  provenance. Duplicate logical delivery returns the original receipt;
  divergent reuse conflicts.
- Repository snapshots derive from conceptual repository and verified Git tree
  identity. Branch names and worktree paths are observations or disposable
  cache handles, never identity material.
- Source requests require a clean inspected Git snapshot matching the declared
  tree and snapshot IRI. Analysis parses but never compiles/executes source and
  has no publication authority.
- `PublishSourceGraph` validates a closed predicate/value vocabulary,
  canonical snapshot-scoped artifacts/symbols/activity, exact observation read
  revision, analyzer identity, coverage/count agreement, and statement/literal
  bounds before one atomic immutable create.
- Publication idempotency is snapshot-analysis scoped. Identical replay returns
  the original receipt, divergent output for the same analysis identity
  conflicts, and another snapshot does not collide under the same analyzer
  configuration.
- Reviewed source queries always require an exact graph and snapshot; entity
  queries also require the exact source entity. Results expose graph/dataset
  revisions, ontology, analyzer/configuration/tree, coverage, freshness,
  degradation, truncation, and safe warnings.

## Fixture Identity

| Evidence fixture | SHA-256 |
| --- | --- |
| Shared provider/Git/observation/source fixture | `54f5ac62777f6f85aba887a087396fe7e11a58062581043b85a78d76c0a8c2fe` |
| End-to-end lifecycle, failure, force-push, crash, and restore integration | `2c404592b8208d36c6ccfa741805540b14f45ce516632327a927cd22c49ea192` |
| Source publication and bounded-query falsification | `3eaf2c94497009583bd4d6e8cc6ccbdee5b631b93a71190e309cc4f163af9af6` |
| Source analyzer determinism and bounds | `1e017fce1443cfa759ef9175a82d4f0790b98353aa8dc76b490cd802ae7c1c58` |

The fixtures start the real StoreServer, Writer, QueryRunner, Maintenance, and
embedded TripleStore; load the pinned ontology; bootstrap graph authority; and
commit product facts only through reviewed semantic commands. Local Git
repositories and worktrees are deterministic disposable external fixtures.

## Executable Evidence

The Phase 6 integration and retained focused suites prove:

- bootstrap, multi-locator enrollment, fake provider polling, hardened real Git
  inspection, immutable observation, exact snapshot, source analysis,
  publication, and bounded projection execute as one vertical flow;
- duplicate observation/source replay, delayed observation, locator transfer,
  suspend/resume, retiring/retired state, and historical queries preserve one
  accepted chain without duplicate effects or erased graphs;
- invalid webhook signature, stale credentials, partial pagination, rate
  limit, provider deletion, enrollment/locator substitution, missing ref,
  unsafe path, malformed source, unsupported profile, and oversize limits fail
  closed or retain explicit incomplete coverage;
- submodule, LFS, and limited snapshot flags make analyzer coverage partial
  with closed warning codes rather than silently complete;
- deleting and recreating an exact checkout produces byte-identical canonical
  analyzer RDF; force-pushed old/new commits, trees, observations, snapshots,
  and source graphs remain distinct and queryable;
- writer death before source publication leaves no partial graph; retry commits
  once, writer death after commit recovers status, and replay returns the
  original receipt;
- checkpoint restore preserves catalog, observation, source graph content and
  revisions while removing post-backup observations; and
- exported RDF, captured logs, inspected envelopes, receipts, events, and
  fixtures exclude credentials, authorization material, absolute private paths,
  raw provider bodies, and unapproved source text.

## Verification Record

| Command or gate | Result |
| --- | --- |
| Phase 6 final integration file | 3 tests, 0 failures |
| Phase 6 focused enrollment/adapter/observation/source files | 17 tests, 0 failures |
| `mix precommit` | 183 tests, 0 failures; compile, architecture, lock, format, and test gates passed |
| `mix jido_code.ontology verify` | Package and canonical ontology digests verified |
| `mix hex.audit` | No retired packages found |
| `npm audit --omit=dev` | 0 vulnerabilities |
| `MIX_ENV=prod mix assets.build` | Vite client and SSR bundles built successfully |

## Operational Limits

- Provider calls bound receive timeout, retries, redirects, response bytes,
  pages, and normalized observations. Webhooks admit at most 1,000,000 bytes
  and a five-minute delivery age.
- Git materialization bounds operation IDs, refs, clone depth, command time,
  disk use, and fixture roots; disables ambient config, credentials, prompts,
  hooks, and LFS smudging; and cleans operation-scoped paths.
- The Elixir analyzer defaults to 100 files, 5,000,000 aggregate bytes,
  500,000 bytes per file, 100 symbols, 100,000 expressions, 400 RDF statements,
  and 10 seconds. Caller overrides remain within fixed upper bounds.
- Source publication admits at most 400 analyzer statements and 512 bytes per
  literal, plus graph metadata/publication facts within the command pipeline's
  1,000-addition and 262,144-byte payload limits.
- Reviewed queries retain the Phase 5 defaults of 5 seconds, 200 rows, 500
  triples, 256,000 decoded bytes, 20 graphs, and 100 collection parameters.
- Local clones, projection values, adapter values, and wake-up work are
  disposable. The named graph dataset remains the only durable product truth.

## Gate G5

G5 is closed at merged candidate
`394657afdb1ad2453f7f21a0ceef61351d60860e`. Clean-checkout CI passed before
merge, the graph-only repository knowledge invariants remain satisfied, and
Phase 7 is authorized from this exact baseline.
