# Repository Wiki Governance Baseline

Status: accepted Phase 1 governing input

## Candidate Provenance

Repository-wiki Phase 1 starts from `origin/main` commit
`1347712cb5e922b4ccf22a33677e1da912999c56`, observed on 2026-08-26. That
baseline contains the accepted delegated-agent Phase 1 receipt, which pins
DCG1 to merged candidate
`5d79d798de87a8c652ad429fd677b6e82c69e764` after pull request #77 passed
clean-checkout CI and merged. The Phase 1 closure was merged by pull request
#78.

The repository-wiki decisions, specifications, research, and implementation
plan are accepted together by the first section commit on branch
`agent/repository-wikis-phase-01`. Later sections record their own revisions
without rewriting this governance provenance.

| Governing input | SHA-256 |
| --- | --- |
| ADR 0005 | `f337c4d6906f503c599bd8918d94d3356e9e5b81cc4125e93913687fb9f1a92e` |
| ADR 0006 | `c5ad6007b433214ba2a6a9119ef278f91d540d78408d070071e7591634cd28f1` |
| ADR 0007 | `c1b28b110b8e3bd586fd2365bb4d58c145c340973ea6d0f3c4739a3a5f2570e4` |
| Graph and edition contract | `69d18609ae321b9583e76053110814850804df8c10ea758d60c7b4f0693c584b` |
| Compilation and update protocol | `91a455537a50fe894f8c84ccffbb8f96143b484847e4f390d2c828cfafc78f0d` |
| Mix project and dependency catalog | `b309e869709e8fdc5b480002f7a8ff5ecb922eb038e4d15e979582a56281736d` |
| Maintainer runtime specification | `afa75952bf645ea0533df2d203aa053c24a6c0af83985587d31912a2bc348561` |
| Product and qualification specification | `473ec19f0670c07da516f487e0ec3270f5c413138321f8c432609382f029bcef` |
| Enrollment, budget, and accounting specification | `796d9f913db481f9173aa0d5b5c7c0983a8421cfef58eb1638e01aabf29ca4fa` |
| Implementation plan | `1deb916071791e2122e810bbc576f528b8584020658ae5be2471afb3e26365e1` |
| Research | `91932a84774da9ef916c44895ee70a81cfb78b7b13dc7dd9dd5c319a43d0088f` |

## Accepted V1 Decision

The initial repository-wiki milestone is fixed as:

| Dimension | Accepted value |
| --- | --- |
| Pilot repository | `jido_code` |
| Default enrollment | `off` for every repository |
| Enabled maintenance | manual and automatic deterministic generation |
| Production compiler | `wiki-deterministic-elixir/1.0.0` |
| Project extraction | repository execution prohibited in Phase 1 |
| Model synthesis | unavailable in V1 |
| Hosted provider/model prices | no enabled entries |
| Preview behavior | session-scoped and never current without a later reviewed transition |
| Durable authority | existing `TripleStore` only |

V1 is useful without model synthesis. Every deterministic attempt records
explicit zero model-token usage. Phase 1 implements no provider invocation,
model profile, price profile, budget reservation, maintainer, product
activation, Mix evaluation, or metadata network route.

## Parallel Repository And Session Boundary

- Each conceptual repository receives its own deterministic graph identity,
  edition lineage, source fence, retention scope, and authorization boundary.
- Different repositories may compile concurrently within capacity.
- Sessions working on the same repository may prepare isolated future
  previews, but exactly one current-source transition can succeed at a given
  repository control revision.
- A page segment, finalization, lint result, staleness result, invalidation,
  and activation request always carries the current repository, edition,
  source, enrollment, attempt, lease, and fence identities required by its
  protocol phase.
- Queues, processes, cursors, caches, previews, and render artifacts remain
  disposable. Recovery starts from graph state plus accepted
  content-addressed artifacts.

## Binding Authority And Scope

- Repository code, manifests, authored documentation, and accepted graph facts
  remain authoritative. Wiki resources are attributed projections.
- `TripleStore` remains the only application-owned durable store.
- Graph values select only closed resource identities and registry keys; they
  cannot select modules, graph IRIs, filesystem paths, commands, endpoints,
  prompts, credentials, or prices.
- Absent wiki configuration means `off`. It creates no graph edition, worker,
  queue item, network request, model call, token usage, or product surface.
- Generation permission, retained-edition visibility, preview visibility,
  accounting retention, and audit retention are independent.
- Disabling enrollment fences new and in-flight work without deleting required
  lineage, usage, cost, or audit evidence.
- A wiki fact or page cannot authorize runtime, credential, command,
  verification, publication, accepted-memory, protected-ref, or merge effects.

## Version Ownership

The delegated-agent accepted baseline owns ontology `1.4.0` and semantic
command/query protocol `2.9.0`. Repository-wiki Phase 1 may therefore publish
the additive ontology/shape pair `1.5.0`, `GraphRegistry` `2.5.0`, semantic
command/query protocol `2.10.0`, and wiki edition/compiler protocol `1.0.0`.
Older accepted versions remain readable and cannot imply wiki enrollment,
current-edition authority, or model-synthesis permission.

## Gate Reopening Conditions

RW1 reopens regardless of checklist state if absent enrollment creates work or
visibility; repository, tenant, session, preview, edition, source, retention,
or usage data crosses scope; more than one current edition can exist; a stale
writer can append, finalize, lint, invalidate, or activate; a finalized edition
can mutate; a caller or repository value can select a graph, module, command,
path, endpoint, prompt, credential, price, or executable behavior; repository
code executes outside a later accepted fixed sandbox profile; deterministic
generation produces nonzero model tokens; a model/provider path becomes
reachable in V1; disposable process, queue, cursor, cache, preview, or artifact
state competes with graph authority; disabling enrollment accepts new or late
work; recovery cannot reconstruct from graph state and accepted artifacts; any
governing ADR or specification digest changes without reevaluation; the
delegated-agent Phase 1 prerequisite reopens; or ontology verification,
architecture checks, Dialyzer, precommit, or clean-checkout CI fails at the
merged Phase 1 candidate.
