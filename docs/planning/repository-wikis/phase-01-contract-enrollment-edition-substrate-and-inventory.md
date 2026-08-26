---
id: plan.jido_code_repository_wikis_phase_01
parent_plan: plan.jido_code_repository_wikis
status: approved
intent: feature
---

# Repository Wikis Phase 1 - Contract, Enrollment, Edition Substrate, And Deterministic Inventory

This phase establishes the closed semantic contract, repository-isolated graph
topology, explicit enrollment controls, immutable edition lifecycle, and first
zero-token inventory compiler. It deliberately excludes Mix evaluation,
external metadata, guides, product activation, maintainers, and synthesis.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Establish the isolated deterministic substrate for repository wikis.

  This phase proves RW1 by making enrollment, graph placement, editions,
  source fencing, retention, and deterministic inventory graph-authorized,
  replayable, and safe under parallel sessions.

  - [x] 1.1 Section - Baseline the repository-wiki decisions and shared semantic versions.

    This section pins the governing documents and prevents this plan from
    racing the delegated-agent phase that owns the immediately preceding
    ontology and semantic protocol versions.

    - [x] 1.1.1 Task {#rwi-p01-governance} [repo: jido_code] [after: {#dca-p01-phase-receipt}] - Pin and reconcile the repository-wiki architecture.

      This task makes the projection model, opt-in policy, deterministic V1
      posture, and parallel-session boundary normative.

      - [x] 1.1.1.1 Subtask - Verify the delegated-agent Phase 1 receipt is accepted at a full merged candidate SHA and use that closure as the ontology `1.4.0` and semantic protocol `2.9.0` baseline.
      - [x] 1.1.1.2 Subtask - Pin accepted ADRs 0005, 0006, and 0007 with their consequences, alternatives, and reopening conditions.
      - [x] 1.1.1.3 Subtask - Pin the six approved repository-wiki specifications and research document with canonical revisions and digests.
      - [x] 1.1.1.4 Subtask - Record that all repositories start `off`, V1 production is deterministic-only, and no hosted synthesis or provider/model price is enabled.
      - [x] 1.1.1.5 Subtask - Reconcile vocabulary, version ownership, graph authority, and parallel-session semantics with accepted factory, memory, managed-coding, and delegated-agent architecture indexes.

  - [x] 1.2 Section - Define repository-wiki ontology, shapes, and graph topology.

    This section gives enrollment, editions, pages, sources, budgets, usage,
    and maintenance durable meanings inside a closed repository graph family.

    - [x] 1.2.1 Task {#rwi-p01-ontology} [repo: jido_code] [after: {#rwi-p01-governance}] - Publish ontology and SHACL revision `1.5.0`.

      This task defines the repository-wiki resources and validates their
      identity, lifecycle, provenance, and isolation invariants.

      - [x] 1.2.1.1 Subtask - Define `RepositoryWikiEnrollment`, `WikiGenerationProfile`, `WikiEdition`, `WikiPage`, `WikiSource`, `WikiPreview`, `WikiMaintainer`, `WikiBudget`, `WikiReservation`, and `WikiUsageRecord` classes.
      - [x] 1.2.1.2 Subtask - Define closed lifecycle and reason vocabularies for enrollment, edition state, generation mode, trigger, freshness, source kind, retention class, accounting state, and maintainer state.
      - [x] 1.2.1.3 Subtask - Require repository identity, tenant scope, source revision, compiler profile and digest, edition sequence, creation provenance, timestamps, and current-source fence wherever applicable.
      - [x] 1.2.1.4 Subtask - Add shapes that reject cross-repository references, multiple current editions, mutable finalized editions, unclosed profile keys, incomplete usage terminality, and pages without source provenance.
      - [x] 1.2.1.5 Subtask - Publish compatibility rules for ontology `1.4.0` readers and prove older resources cannot imply wiki enrollment, current-edition authority, or synthesis permission.

    - [x] 1.2.2 Task {#rwi-p01-graph-topology} [repo: jido_code] [after: {#rwi-p01-ontology}] - Publish `GraphRegistry` revision `2.5.0` with the `repository_wiki` family.

      This task makes graph placement deterministic and prevents callers or
      repository content from selecting another repository's wiki graph.

      - [x] 1.2.2.1 Subtask - Define the `repository_wiki` graph family from canonical tenant and repository identity with a deterministic, collision-resistant graph IRI.
      - [x] 1.2.2.2 Subtask - Register ownership, allowed resource roots, lifecycle, backup class, retention class, and reviewed query access for the family.
      - [x] 1.2.2.3 Subtask - Link wiki graphs to repository, policy, run, artifact, and accepted-knowledge graphs only through typed provenance references.
      - [x] 1.2.2.4 Subtask - Reject caller-selected graph IRIs, aliases, path-derived traversal, unknown roots, cross-tenant links, and writes outside the registered family.
      - [x] 1.2.2.5 Subtask - Add startup verification, registry drift detection, graph inventory reporting, backup inclusion, and restore ordering for repository wiki graphs.

  - [x] 1.3 Section - Implement enrollment and reviewed semantic interfaces.

    This section ensures no wiki work, read surface, token spend, or
    maintainer process exists without current repository-scoped enrollment.

    - [x] 1.3.1 Task {#rwi-p01-enrollment} [repo: jido_code] [after: {#rwi-p01-graph-topology}] - Implement closed repository-wiki enrollment and generation profiles.

      This task represents opt-in, update mode, generation permissions, read
      visibility, retention, and budgets as explicit graph policy.

      - [x] 1.3.1.1 Subtask - Add enrollment states `off`, `manual`, and `automatic` with authorized transitions, revision preconditions, idempotency, provenance, and audit history.
      - [x] 1.3.1.2 Subtask - Add exact generation profiles for `manual_deterministic` and `automatic_deterministic`; model-backed profiles remain closed and unavailable.
      - [x] 1.3.1.3 Subtask - Separate generation permission from retained-edition read visibility, preview visibility, accounting retention, and audit retention.
      - [x] 1.3.1.4 Subtask - Make absent configuration equivalent to `off`, prevent inheritance from another repository or tenant, and expose no wiki product entry when reads are disabled.
      - [x] 1.3.1.5 Subtask - Define disable behavior that rejects new work, fences in-flight work, releases reservations, removes current product availability, and preserves required history.

    - [x] 1.3.2 Task {#rwi-p01-command-protocol} [repo: jido_code] [after: {#rwi-p01-enrollment}] - Publish semantic command and query protocol `2.10.0`.

      This task routes all repository-wiki mutations and reads through bounded,
      typed interfaces instead of raw graph access.

      - [x] 1.3.2.1 Subtask - Add commands for enrollment transitions, deterministic compilation admission, segmented edition writes, edition finalization, lint result recording, staleness, invalidation, and current-edition activation.
      - [x] 1.3.2.2 Subtask - Reserve disabled commands for maintainer, reservation, usage, and synthesis lifecycles so later phases extend behavior without inventing incompatible meanings.
      - [x] 1.3.2.3 Subtask - Add reviewed queries for enrollment detail, current edition, edition history, page detail, source coverage, freshness, and bounded compilation status.
      - [x] 1.3.2.4 Subtask - Require authorization, repository scope, exact revision or fence, idempotency key, provenance, bounded payloads, and stable public outcomes on every interface.
      - [x] 1.3.2.5 Subtask - Reject generic SPARQL mutation/read surfaces, raw graph selection, unknown enum values, stale revisions, forged compiler identities, and unsupported protocol combinations.

  - [x] 1.4 Section - Build immutable editions and deterministic repository inventory.

    This section creates the first useful wiki edition using repository and
    accepted-graph facts only, with no repository execution or model call.

    - [x] 1.4.1 Task {#rwi-p01-inventory} [repo: jido_code] [after: {#rwi-p01-command-protocol}] - Implement the bounded repository source inventory.

      This task inventories safe source classes and records explicit coverage
      gaps without treating unexamined content as absent.

      - [x] 1.4.1.1 Subtask - Resolve repository identity, canonical root, accepted source revision, registered documentation roots, source roots, and Mix manifest paths through closed registries.
      - [x] 1.4.1.2 Subtask - Inventory `README`, accepted ADRs/specs/plans, source directory/module names, `mix.exs`, `mix.lock`, configured guide roots, and accepted factory knowledge under fixed file/count/byte limits.
      - [x] 1.4.1.3 Subtask - Classify missing, ignored, binary, oversized, unsupported, unreadable, symlinked, and changed-during-read inputs as explicit bounded gaps.
      - [x] 1.4.1.4 Subtask - Normalize hostile paths, Unicode, line endings, media types, digests, and deterministic ordering without following paths outside the registered repository root.
      - [x] 1.4.1.5 Subtask - Prove this phase never executes `mix.exs`, repository modules, scripts, hooks, build tools, or network requests.

    - [x] 1.4.2 Task {#rwi-p01-editions} [repo: jido_code] [after: {#rwi-p01-inventory}] - Implement wiki edition/compiler protocol `1.0.0` and the minimal deterministic compiler.

      This task creates immutable segmented editions and admits a current
      edition only from the exact current repository source fence.

      - [x] 1.4.2.1 Subtask - Implement start, bounded segment append, finalize, lint, close, stale, invalidate, and activate transitions with immutable edition identity and retry-safe idempotency.
      - [x] 1.4.2.2 Subtask - Enforce at most 800 statements and 192 KiB per reserved segment, exact sequence continuity, segment digests, edition totals, and no partial visibility.
      - [x] 1.4.2.3 Subtask - Compile deterministic Overview, Repository Inventory, Architecture Index, Source Map, Documentation Index, Provenance, and Known Gaps pages with stable page identities.
      - [x] 1.4.2.4 Subtask - Attach every page and material fact to source references, source revision, compiler profile `wiki-deterministic-elixir/1.0.0`, compiler digest, freshness, and confidence.
      - [x] 1.4.2.5 Subtask - Recheck enrollment revision and current-source fence immediately before activation; a stale or competing edition may close as history but cannot become current.

    - [x] 1.4.3 Task {#rwi-p01-recovery} [repo: jido_code] [after: {#rwi-p01-editions}] - Implement edition retention, backup, restore, and interrupted-write recovery.

      This task makes graph state and accepted content-addressed artifacts
      sufficient for recovery while preserving incomplete-work evidence.

      - [x] 1.4.3.1 Subtask - Define retention for current, superseded, preview, incomplete, invalid, source snapshot, render artifact, accounting, and audit classes.
      - [x] 1.4.3.2 Subtask - Detect abandoned open editions and segments after restart, mark them terminal or resumable only by exact fence, and prevent them from appearing in reads.
      - [x] 1.4.3.3 Subtask - Include enrollment, lineage, current pointer, source/provenance, compiler identity, retention, and audit facts in backup and restore verification.
      - [x] 1.4.3.4 Subtask - Rebuild disposable indexes and render caches from graph state and accepted artifacts without trusting process memory, queue state, or filesystem cursors.
      - [x] 1.4.3.5 Subtask - Prove restore cannot manufacture a current edition, revive disabled enrollment, cross-link repositories, or discard a required audit record.

  - [ ] 1.5 Section - Phase 1 Integration Tests.

    This final section proves the repository-wiki substrate is isolated,
    deterministic, opt-in, fenced, and recoverable.

    - [ ] 1.5.1 Task {#rwi-p01-integration} [repo: jido_code] [after: {#rwi-p01-recovery}] - Execute the RW1 contract, concurrency, and recovery matrix.

      This task closes RW1 only when unconfigured repositories do no work and
      parallel writers cannot corrupt or prematurely expose an edition.

      - [ ] 1.5.1.1 Subtask - Exercise enrollment authorization, revision conflicts, duplicates, disable during work, retained reads, unknown profiles, and default-off behavior against the real store.
      - [ ] 1.5.1.2 Subtask - Exercise hostile and Unicode paths, symlinks, oversized files, source changes, malformed segments, duplicate segments, incomplete editions, and deterministic recompilation.
      - [ ] 1.5.1.3 Subtask - Race same-repository sessions, different repositories, stale fences, retries, activation, cancellation, and late results; prove one current edition and no cross-scope disclosure.
      - [ ] 1.5.1.4 Subtask - Exercise backup, restore, abandoned-work recovery, retention, graph registry drift, startup validation, and graph-only reconstruction.
      - [ ] 1.5.1.5 Subtask - Run prior architecture and semantic suites, ontology verification, Dialyzer, `mix precommit`, and clean-checkout CI.

    - [ ] 1.5.2 Task {#rwi-p01-phase-receipt} [repo: jido_code] [after: {#rwi-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records RW1 evidence in
      `docs/architecture/repository-wiki-phase-01-receipt.md`.

      - [ ] 1.5.2.1 Subtask - Record governing document, ontology, SHACL, GraphRegistry, protocol, compiler, query, fixture, and migration revisions and digests.
      - [ ] 1.5.2.2 Subtask - Keep RW1 open if absent enrollment creates work, a caller can select a graph, repository code executes, editions mutate after finalization, or a stale writer can activate.
      - [ ] 1.5.2.3 Subtask - Preserve every gate reopening condition and attach architecture, store, isolation, concurrency, recovery, precommit, Dialyzer, and clean-checkout evidence.
      - [ ] 1.5.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, final Phase 1 Integration Tests section, receipt task, and pinning checkboxes before authorizing Phase 2.
