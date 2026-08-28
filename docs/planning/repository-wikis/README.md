---
id: plan.jido_code_repository_wikis
status: completed
intent: feature
source:
  - docs/research/11-repository-wikis-as-compiled-knowledge-projections.md
  - docs/adr/0005-repository-wikis-as-compiled-knowledge-projections.md
  - docs/adr/0006-per-repository-wiki-maintainer-agents.md
  - docs/adr/0007-repository-wiki-enrollment-and-cost-governance.md
  - docs/architecture/repository-wiki-graph-and-edition-contract.md
  - docs/architecture/repository-wiki-compilation-and-update-protocol.md
  - docs/architecture/repository-wiki-mix-project-and-dependency-catalog.md
  - docs/architecture/repository-wiki-maintainer-runtime.md
  - docs/architecture/repository-wiki-product-and-qualification.md
  - docs/architecture/repository-wiki-enrollment-budget-and-accounting.md
---

# Repository Wikis Implementation Plan

This five-phase plan turns each enrolled coding repository into an optional,
reviewed wiki compiled from the repository, its accepted factory knowledge,
and bounded external dependency metadata. The wiki is a versioned projection,
not a second authority: source code, manifests, accepted documentation, and
the TripleStore remain authoritative while wiki editions make that knowledge
navigable for people and agents.

The factory can operate many repositories and many coding sessions in
parallel. Each repository therefore receives its own graph, edition history,
current-source fence, preview namespace, and optional maintainer coordination.
Wiki generation is disabled unless the repository is explicitly enrolled.

## Goal

Deliver an initial deterministic repository-wiki capability that:

1. leaves every repository unenrolled and token-free by default;
2. compiles one isolated wiki and history per enrolled repository;
3. inventories repository identity, accepted architecture, source layout,
   `mix.exs`, the complete resolved dependency graph, and user/developer guides;
4. records provenance, freshness, confidence, source revisions, compiler
   profile, and update reasons for every published edition;
5. supports manual and automatic deterministic updates without model tokens;
6. isolates previews from parallel sessions and admits only one fenced current
   edition per repository;
7. implements token reservation, measured usage, attribution, cost accounting,
   and budget enforcement before any synthesis provider is enabled;
8. supports one optional coordinator-owned maintainer runtime per enrolled
   repository without making the process durable authority;
9. exposes the same reviewed wiki reads to people, product surfaces, and agent
   context assembly; and
10. qualifies and releases only deterministic wiki generation in V1.

Hosted synthesis, provider/model pricing, and synthesis-backed production
activation remain disabled in V1 even though their safety and accounting
boundaries are implemented and tested.

## Governing Inputs And Baseline

The governing decisions and specifications are:

- [Research: Repository wikis as compiled knowledge projections](../../research/11-repository-wikis-as-compiled-knowledge-projections.md)
- [ADR 0005: Repository wikis as compiled knowledge projections](../../adr/0005-repository-wikis-as-compiled-knowledge-projections.md)
- [ADR 0006: Per-repository wiki maintainer agents](../../adr/0006-per-repository-wiki-maintainer-agents.md)
- [ADR 0007: Repository wiki enrollment and cost governance](../../adr/0007-repository-wiki-enrollment-and-cost-governance.md)
- [Repository wiki graph and edition contract](../../architecture/repository-wiki-graph-and-edition-contract.md)
- [Repository wiki compilation and update protocol](../../architecture/repository-wiki-compilation-and-update-protocol.md)
- [Repository wiki Mix project and dependency catalog](../../architecture/repository-wiki-mix-project-and-dependency-catalog.md)
- [Repository wiki maintainer runtime](../../architecture/repository-wiki-maintainer-runtime.md)
- [Repository wiki product and qualification](../../architecture/repository-wiki-product-and-qualification.md)
- [Repository wiki enrollment, budget, and accounting](../../architecture/repository-wiki-enrollment-budget-and-accounting.md)

Phase 1 begins only after the delegated-coding-agents Phase 1 receipt pins its
merged candidate. That shared baseline owns ontology `1.4.0` and semantic
command/query protocol `2.9.0`; this plan advances them without conflicting
parallel edits. Every later phase begins from the prior repository-wiki phase's
pinned merged closure.

The completed graph-native factory, secure harness, total-memory, managed
coding, and delegated-agent contracts remain binding. This plan adds no second
durable store, graph mutation bypass, independent authorization path, or wiki
authority over repository truth.

## Exact Initial Profile

| Dimension | V1 value |
| --- | --- |
| Pilot repository | `jido_code` |
| Default enrollment | `off` for every repository, including new registrations |
| Enabled generation modes | `manual_deterministic`, `automatic_deterministic` |
| Production synthesis | disabled |
| Hosted provider/model pricing | no enabled entries |
| Repository topology | one isolated wiki graph and edition lineage per repository |
| Concurrency | isolated session previews; one fenced current-source transition |
| Project introspection | `mix-static/1.0.0` with bounded `mix-sandbox/1.0.0` escalation |
| Dependency metadata | `hex-req/1.0.0`, cached and provenance-bearing |
| Compiler | `wiki-deterministic-elixir/1.0.0` |
| Qualification | `wiki-lint/1.0.0` and `wiki-renderer/1.0.0` |
| Durable authority | existing `TripleStore` only |

## Contract Versions And Public Interfaces

- Ontology and SHACL revision `1.5.0` adds repository-wiki enrollment,
  edition, page, source, dependency, guide, preview, budget, usage, and
  maintainer-resource meanings.
- `GraphRegistry` revision `2.5.0` adds the closed `repository_wiki` graph
  family with deterministic repository identity and no caller-selected graph.
- Semantic command and query protocol `2.10.0` adds closed repository-wiki
  enrollment, compilation, preview, activation, maintenance, accounting, and
  reviewed read operations.
- Wiki edition/compiler protocol `1.0.0` defines segmented edition creation,
  source fencing, compiler profiles, linting, activation, staleness, retention,
  and replay.
- `wiki-deterministic-elixir/1.0.0` is the only V1 production compiler profile.
- `mix-static/1.0.0` parses project and lock inputs without executing repository
  code; `mix-sandbox/1.0.0` is the fixed, separately admitted fallback.
- `hex-req/1.0.0` uses the existing Req client and a closed endpoint registry
  for bounded external dependency metadata.
- `wiki-lint/1.0.0` and `wiki-renderer/1.0.0` define deterministic structural,
  provenance, link, safety, and rendering qualification.
- The authenticated browser product adds a repository Wiki destination and
  settings. V1 adds no public JSON API, raw graph browser, or raw graph editor.

## Gate And Phase Mapping

| Gate | Required result | Phase |
| --- | --- | --- |
| RW1 - isolated deterministic substrate | Enrollment, graph topology, editions, source fencing, retention, and deterministic inventory are closed and repository-scoped | Phase 1 |
| RW2 - trustworthy Mix and dependency knowledge | Static/sandbox project extraction, complete resolved dependency closure, metadata, links, and provenance are deterministic and bounded | Phase 2 |
| RW3 - useful reviewed wiki product | Guides, navigation, search, previews, review, activation, staleness, and current-edition reads work without synthesis | Phase 3 |
| RW4 - bounded maintenance and accounting | Optional maintainers, scheduling, leases, opt-out, reservations, usage, cost, cancellation, and disabled synthesis boundaries are enforced | Phase 4 |
| RW5 - factory-wide deterministic release | Agent context, fleet isolation, hostile-corpus qualification, operations, pilot evidence, and deterministic V1 release are complete | Phase 5 |

## Phase Plans

1. [Phase 1 - Contract, Enrollment, Edition Substrate, And Deterministic Inventory](./phase-01-contract-enrollment-edition-substrate-and-inventory.md)
2. [Phase 2 - Mix Project And Complete Dependency Catalog](./phase-02-mix-project-and-complete-dependency-catalog.md)
3. [Phase 3 - Guides, Product Navigation, Preview, And Activation](./phase-03-guides-product-navigation-preview-and-activation.md)
4. [Phase 4 - Maintainer Automation, Budgeting, And Accounting](./phase-04-maintainer-automation-budgeting-and-accounting.md)
5. [Phase 5 - Agent Context, Fleet Qualification, And Deterministic Release](./phase-05-agent-context-fleet-qualification-and-deterministic-release.md)

Phase evidence is recorded in
`docs/architecture/repository-wiki-phase-01-receipt.md` through
`docs/architecture/repository-wiki-phase-05-receipt.md`.

## Planning Structure And Closure

Every phase follows this hierarchy:

~~~text
Phase
  description
  Section
    description
    Task
      description
      Subtask
~~~

- Phases use `N`; sections use `N.M`; tasks use `N.M.K`; subtasks use
  `N.M.K.L`.
- Every phase, section, and task begins with its own description.
- Stable anchors use `rwi-pNN-*` and every task declares
  `[repo: jido_code]`.
- Dependencies point to stable anchors. Phase 1 depends on the pinned delegated
  agent Phase 1 receipt; each later phase depends on the prior repository-wiki
  phase receipt.
- Every phase ends with a section named `Phase N Integration Tests`.
- Implementation uses one intentional commit per section and one
  implementation pull request per phase.
- After the implementation PR passes clean-checkout CI and merges, a
  documentation-only closure PR pins the full merge SHA and date, updates the
  receipt from merge-pending to accepted-at-merged-candidate, and checks the
  phase, integration, receipt, and pinning boxes.
- The next phase starts only from that pinned merged closure baseline.

## Non-Negotiable Invariants

1. `TripleStore` remains the only application-owned durable authority.
2. Wiki enrollment is explicit, repository-scoped, off by default, and
   reversible without deleting retained accounting or audit evidence.
3. Repository code, manifests, accepted documentation, and accepted graph
   facts remain authoritative; a wiki is a provenance-bearing projection.
4. Repository graphs, editions, previews, leases, budgets, and usage never
   cross repository or tenant boundaries.
5. Exactly one fenced current edition exists per enrolled repository; parallel
   sessions may prepare isolated previews but cannot overwrite current state.
6. Graph values resolve only closed registry keys and immutable digests. They
   never select modules, commands, paths, endpoints, prompts, or credentials.
7. Static Mix extraction never executes repository code. Escalated
   introspection runs only through the fixed sandbox profile and is labeled.
8. Dependency pages cover the complete resolved lock closure and distinguish
   direct, transitive, path, git, optional, missing, and unresolved inputs.
9. User and developer guides are safe repository-derived wiki content with
   source links, revision identity, freshness, and deterministic rendering.
10. Deterministic compilation consumes zero model tokens and emits explicit
    zero-token usage evidence.
11. Any model-backed attempt requires exact opt-in, an enabled closed profile,
    successful reservation, measured provider usage, attributable cost, and
    durable terminal accounting; V1 enables no hosted profile.
12. Maintainer processes, caches, queues, cursors, previews, and render
    artifacts are disposable and recover only from graph state plus accepted
    content-addressed artifacts.
13. Disabling enrollment stops new work, cancels or fences in-flight work, and
    hides the product surface without erasing required history.
14. No wiki read or generated statement grants command, publication,
    credential, verification, merge, or runtime authority.

## Test And Evidence Rules

- Unit tests accompany every resource, shape, command, query, transition,
  parser, resolver, classifier, renderer, reservation, scheduler, and gate.
- Integration sections use the real TripleStore and real local filesystem
  effects at seams owned by the phase.
- Mocks cannot close graph isolation, source fencing, Mix execution,
  dependency completeness, token accounting, cancellation, recovery, preview
  isolation, activation, or product authorization gates.
- Network tests use the closed Req adapter boundary and immutable recorded
  fixtures; ordinary CI never depends on live Hex or a model provider.
- Fixed clocks, deterministic IRIs, pinned snapshots, immutable fixtures, and
  exact component digests make compilation and replay reproducible.
- Parallel tests include same-repository competing sessions, different
  repositories, stale fences, retries, cancellation, opt-out, and late results.
- Later phases rerun all earlier RW gates and applicable factory, harness,
  memory, managed-coding, delegated-agent, architecture, Dialyzer, precommit,
  and clean-checkout gates.
- A gate reopens whenever any listed invariant fails, regardless of checklist
  state.

## Completion Definition

The plan is complete only when explicitly enrolled repositories can publish
isolated, provenance-bearing, deterministic wikis; the `jido_code` pilot
contains complete Mix/dependency knowledge and safe user/developer guides;
parallel sessions cannot corrupt or prematurely activate editions; wiki reads
can support product navigation and bounded agent context; opt-out and terminal
zero-token accounting are proven; and deterministic V1 passes its signed
qualification and operations gates without enabling hosted synthesis.
