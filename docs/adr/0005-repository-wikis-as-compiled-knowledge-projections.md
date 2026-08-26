# ADR 0005: Repository Wikis As Compiled Knowledge Projections

- Status: Accepted
- Date: 2026-08-26
- Owners: JidoCode knowledge, product, and documentation maintainers
- Decision scope: Per-repository wiki authority, graph topology, editions, and source ownership
- Depends on:
  [ADR 0001](./0001-graph-only-source-of-truth.md) and
  [ADR 0002](./0002-triple-store-backend-contract.md)
- Research:
  [Repository Wikis As Compiled Knowledge Projections](../research/11-repository-wikis-as-compiled-knowledge-projections.md)
- Follow-on governance:
  [ADR 0007](./0007-repository-wiki-enrollment-and-cost-governance.md)
- Specifications:
  [graph and edition contract](../architecture/repository-wiki-graph-and-edition-contract.md),
  [compilation protocol](../architecture/repository-wiki-compilation-and-update-protocol.md),
  [Mix and dependency catalog](../architecture/repository-wiki-mix-project-and-dependency-catalog.md),
  [enrollment, budget, and accounting](../architecture/repository-wiki-enrollment-budget-and-accounting.md), and
  [product and qualification](../architecture/repository-wiki-product-and-qualification.md)

## Context

JidoCode can already enroll repositories, observe exact Git snapshots, publish
revision-scoped source graphs, retain accepted knowledge, and expose bounded
product projections. Those capabilities answer precise questions but do not
provide one navigable body of project knowledge for a human or coding agent.
Repository information remains distributed across source code, tests,
`mix.exs`, `mix.lock`, README files, user and developer guides, ADRs,
operations material, accepted graph decisions, memory, and current work.

A coding factory that manages many projects needs a project-level knowledge
surface that compounds as each codebase changes. A filesystem or Markdown wiki
maintained beside a disposable worktree would either be lost or become a
second application-owned persistence path. Treating generated prose as source
truth would erase the distinction between authored documentation, extracted
facts, synthesized explanation, evidence, and accepted knowledge.

The current graph registry also has no family whose closed placement,
lifecycle, and retention semantics fit addressable wiki pages, whole-edition
manifests, citations, dependency catalogs, guide coverage, drift findings, and
atomic activation.

## Decision

Every enrolled conceptual repository may own one repository wiki. A wiki is a
derived knowledge product compiled from exact external source identities and
authorized graph revisions. It is not an authority for source code, policy,
work, evidence, decisions, or accepted memory.

“May own” is deliberate. Repository enrollment alone does not create or
maintain a wiki. ADR 0007 defines explicit disabled, manual, automatic,
deterministic-only, synthesis, preview, accounting, and budget posture.

JidoCode will add a closed `repository_wiki` graph family. Each graph instance
represents one immutable wiki edition for exactly one repository and one
content-addressed edition identity. Editions are constructed through bounded
segments, closed once, linted, and then separately activated through a
repository-control transition. Readers never observe a partially built
edition.

One repository has at most one active wiki edition at an evaluated control
revision. Earlier active, release, preview, superseded, incomplete, and failed
editions remain distinct resources under explicit retention policy. A newer
edition changes presentation selection; it does not rewrite prior editions or
their source provenance.

Multiple coding sessions may work on the same repository concurrently. Each
session captures an exact wiki edition as input and may request a private
preview bound to its own coding attempt, candidate tree, fence, and audience.
Sessions never share a mutable preview or moving wiki context. Their previews
cannot overwrite one another or compete for the active-edition pointer. Only
the externally observed repository history determines which merged snapshot
is eligible for a new active edition.

### Source Authority

The wiki preserves these source boundaries:

1. Git remains authoritative for source code and repository-authored
   documentation at an exact snapshot.
2. `mix.exs` records declared project and direct-dependency intent, while the
   exact evaluated meaning of dynamic configuration requires an authorized
   sandbox under a pinned toolchain.
3. `mix.lock` records the committed dependency resolution for that snapshot;
   resolved Mix traversal adds environment- and target-specific dependency
   evidence.
4. Source, observation, evidence, decision, and memory graphs retain their
   accepted meanings. Wiki citations point to them without copying their
   authority.
5. Synthesized wiki sections are derived, citation-required, uncertainty-
   preserving, and replaceable.
6. Current work, attempt, health, and release posture are live reviewed query
   panels rather than copied mutable status in wiki prose.

Repository-authored README, user, developer, operator, architecture,
contributing, ADR, upgrade, and release documents are first-class wiki pages.
Their authored content is retrieved or rendered from the exact repository
snapshot. The wiki may add navigation, backlinks, summaries, citations,
freshness, and drift annotations, but it cannot silently rewrite the authored
text.

### Project And Dependency Contract

Every admitted Elixir repository wiki will include a project overview derived
from the exact `mix.exs` and a dependency catalog derived from `mix.exs`,
`mix.lock`, and the authorized resolved Mix graph.

The dependency catalog includes every admitted direct and transitive
dependency for each supported environment and target. Each repository-scoped
dependency use records exact resolution, parents and bounded root paths,
scope, SCM, integrity, project use, metadata provenance, and verified links to
the package, exact-version documentation, immutable source revision,
homepage, changelog or release, issues, and advisory information where those
resources exist and are authorized.

Missing, private, or unverifiable metadata remains explicit. The compiler
never guesses a homepage, documentation URL, package version, or source
revision.

### Content And Presentation

Wiki graphs may contain bounded generated summaries and structured page
sections after classification and redaction. They do not become a generic
source-body store. Full source code remains provider-owned. Authored guide
content remains Git-authoritative and is served through an exact bounded
source-content boundary or represented by a verified external artifact.

Large generated exports are provider-owned artifacts with graph-visible
digests and provenance unless a later ADR accepts another application-owned
content boundary. No JSON snapshot, filesystem wiki database, vector database,
or browser mirror is authoritative.

The product exposes wiki pages only through reviewed, repository-authorized,
bounded projections. Search authorizes the repository partition before
candidate generation. A page slug, dependency name, source URL, or backlink
does not grant visibility.

### Activation Is Not Acceptance

Activating a wiki edition means the edition is complete and safe enough for
the admitted presentation policy. It does not accept every section as truth,
satisfy a goal, adopt knowledge, authorize an effect, or certify source
correctness. Consequential claims still require the existing evidence,
decision, and knowledge-adoption boundaries.

A candidate worktree may produce a private preview edition. Parallel sessions
retain distinct previews even when they share a base revision, and acceptance
of one candidate does not invalidate or promote another. The active wiki can
advance only after external source application is observed, the matching
source analysis and wiki edition close, required lint passes, and the current
control transition authorizes activation.

## Consequences

### Positive

- every repository that enables the feature gains a stable, navigable
  knowledge surface without a second database;
- project, dependency, user, developer, and operator knowledge retains exact
  source and temporal provenance;
- a whole edition can be verified and activated atomically while compilation
  remains segmented and bounded;
- candidate documentation can be checked without presenting unmerged work as
  current;
- historical release wikis remain reproducible; and
- agent contexts can retrieve small attributed wiki neighborhoods rather than
  rediscovering the repository from scratch.

### Costs And Constraints

- ontology, shapes, graph registry, semantic commands, queries, migrations,
  retention, and product projections require new versioned contracts;
- deterministic extraction must precede model synthesis;
- repository opt-out, generation mode, token/cost accounting, and hard budgets
  require the additional governance in ADR 0007;
- authored docs, generated sections, live panels, and accepted knowledge need
  visibly different presentation states;
- whole-edition lint and activation add latency after a merge;
- dependency metadata and external links need bounded provider observation and
  can become unavailable independently of the locked source; and
- edition retention increases graph size and requires explicit release,
  preview, failed, and superseded retention classes.

## Alternatives Rejected

- **Generate and commit the complete wiki into every repository:** this grants
  derived maintenance source-write authority, creates high-churn diffs, and
  confuses generated output with authored documentation.
- **Keep one filesystem wiki beside each worktree:** worktrees are disposable
  and cannot contain the sole durable wiki state.
- **Use one global fleet wiki:** this creates cross-repository visibility,
  retention, and tenant-isolation hazards.
- **Generate every page on demand:** repeated synthesis is not reproducible,
  does not compound, and cannot provide whole-wiki lint or atomic publication.
- **Use accepted memory as the wiki:** accepted memory intentionally excludes
  unresolved, contradictory, navigational, authored-guide, and reference
  material required by a useful wiki.
- **Use a vector database as the wiki:** embeddings do not supply durable page
  identity, source revisions, citation closure, graph authorization, or
  deterministic reconstruction.
- **Copy all source and guide bodies into RDF:** this unnecessarily expands
  sensitive-content, retention, backup, erasure, and command-size exposure.

## Compatibility And Migration

Existing repositories have no wiki graph and remain valid. Absence means
`not_compiled`, never an empty or complete wiki. The first accepted version is
additive: existing ontology/shape pairs remain readable, and only the new wiki
commands can create `repository_wiki` graphs.

Changing the page identity function, edition root, source authority,
segmentation, activation, or content-storage posture requires a new wiki
protocol and an explicit rebuild/migration decision. Old closed editions are
never rewritten to claim new completeness or provenance.

Rollback disables new compilation and selects the last still-authorized closed
edition whose source and visibility posture is valid. It cannot point current
source at an edition compiled from a different snapshot without an explicit
stale presentation state.

## Acceptance Conditions

This ADR may move to `Accepted` only when:

1. ontology, shapes, graph registry, identity, link-direction, and startup
   compatibility tests admit the `repository_wiki` family without weakening
   earlier families;
2. segmented creation, exact-set closure, immutable edition roots, lint, and
   control-graph activation are atomic, replay-safe, fenced, and restart-safe;
3. authored guides remain Git-attributed and full source bodies do not enter
   the graph through an unreviewed path;
4. static and sandbox-evaluated Mix extraction cannot execute untrusted
   repository code on the host;
5. every resolved dependency has an exact repository-scoped page or an
   explicit unsupported/incomplete outcome, with no fabricated links;
6. reviewed queries and search prove authorization before page candidate
   generation and pass cross-repository leakage tests;
7. parallel same-repository sessions retain isolated captured contexts,
   candidates, previews, audiences, leases, and fences, while external merge
   observation, post-change compile, lint, and activation preserve
   verification and publication separation;
8. active, release, preview, failed, and superseded edition retention plus
   backup/restore behavior are proven;
9. deterministic rebuild from the same exact inputs reproduces the same
   project, guide, dependency, and reference edition root;
10. repository enrollment defaults to no wiki work, deterministic-only mode
    proves zero model calls/tokens, and synthesis satisfies ADR 0007's consent,
    reservation, attribution, accounting, and hard-budget gates; and
11. the implementation pull request passes clean-checkout CI, merges, and its
    full merge commit is pinned in an accepted receipt without weakening any
    gate reopening condition.

Until these conditions pass, the research document and specifications are
non-authoritative proposals and no repository wiki graph is enabled.
