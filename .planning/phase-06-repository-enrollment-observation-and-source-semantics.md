---
id: plan.jido_code_graph_factory_phase_06
intent: feature
source:
  - docs/research/graph-native-managed-repository-factory.md
---

# Phase 6 - Repository Enrollment, Observation, And Source Semantics

This phase delivers the first vertical factory slice: conceptual repository
identity, provider locators, time-bounded management enrollment, external
observation batches, exact Git snapshots, and revision-scoped source-code
semantics, all persisted through semantic commands and exposed through bounded
projections.

Back to plan: [README](./README.md)

- [ ] 6 Phase - Enroll repositories and establish reproducible observed repository knowledge.

  This phase makes external repository reality available to later policy and
  reconciliation code without treating provider payloads, local clones, or a
  mutable global source graph as product truth.

  - [x] 6.1 Section - Implement repository identity, locators, and management enrollment.

    This section models one conceptual software repository independently from
    provider locations and expresses factory management as an explicit,
    governed relationship with lifecycle and policy.

    - [x] 6.1.1 Task {#jcf-p06-repository-identity} [repo: jido_code] [after: {#jcf-p05-phase-receipt}] - Implement repository and locator semantic commands.

      This task creates and relates repository identities without duplicating
      `SourceRepo` and `ManagedRepo` object records.

      - [x] 6.1.1.1 Subtask {#jcf-p06-6-1-1-1} - Define command payloads and shapes for `SoftwareRepository` and one or more provider, remote, or local-discovery `RepositoryLocator` resources.
      - [x] 6.1.1.2 Subtask {#jcf-p06-6-1-1-2} - Derive stable locator IRIs from normalized provider/host/external identity and keep aliases, mirrors, forks, and migrated owners as explicit relationships.
      - [x] 6.1.1.3 Subtask {#jcf-p06-6-1-1-3} - Reconcile an observed locator to an existing conceptual repository only through explicit identity evidence and guarded commands.
      - [x] 6.1.1.4 Subtask {#jcf-p06-6-1-1-4} - Preserve stale, redirected, inaccessible, archived, transferred, or deleted locator observations without deleting repository identity.
      - [x] 6.1.1.5 Subtask {#jcf-p06-6-1-1-5} - Reject provider payload structs, URL strings, or local filesystem paths as canonical repository identity.

    - [x] 6.1.2 Task {#jcf-p06-enrollment-lifecycle} [repo: jido_code] [after: {#jcf-p06-repository-identity}] - Implement management enrollment and retirement commands.

      This task records when and under which authority, scope, and policy the
      factory manages a repository.

      - [x] 6.1.2.1 Subtask {#jcf-p06-6-1-2-1} - Implement `EnrollRepository` with factory, repository, initial locator, actor, policy references, validity, and expected catalog revision.
      - [x] 6.1.2.2 Subtask {#jcf-p06-6-1-2-2} - Create an enrollment transition chain covering proposed, active, suspended, retiring, retired, and invalidated concepts.
      - [x] 6.1.2.3 Subtask {#jcf-p06-6-1-2-3} - Enforce one active enrollment per factory/repository policy boundary unless an accepted use case explicitly permits overlap.
      - [x] 6.1.2.4 Subtask {#jcf-p06-6-1-2-4} - Implement suspension, resume, policy reassignment, locator change, and `RetireEnrollment` as governed transitions/supersession.
      - [x] 6.1.2.5 Subtask {#jcf-p06-6-1-2-5} - Stop new observation/reconciliation/execution admission when an enrollment is suspended or retired without erasing prior history.

    - [x] 6.1.3 Task {#jcf-p06-enrollment-projections} [repo: jido_code] [after: {#jcf-p06-enrollment-lifecycle}] - Implement repository catalog and enrollment projections.

      This task gives product and factory services bounded views over identity,
      management state, locators, policy references, and observed freshness.

      - [x] 6.1.3.1 Subtask {#jcf-p06-6-1-3-1} - Add queries for repository by canonical IRI, locator resolution, active enrollment, enrollment transition history, and factory repository cohort.
      - [x] 6.1.3.2 Subtask {#jcf-p06-6-1-3-2} - Project locator/provider state, current enrollment state, applicable policy refs, latest observed snapshot refs, and safe warnings.
      - [x] 6.1.3.3 Subtask {#jcf-p06-6-1-3-3} - Preserve multiple locators and contradictory provider observations rather than flattening them into one record.
      - [x] 6.1.3.4 Subtask {#jcf-p06-6-1-3-4} - Add actor/enrollment subscriptions that re-query on catalog, policy, or observation graph revisions.

  - [ ] 6.2 Section - Implement provider, Git, and observation adapter boundaries.

    This section normalizes external systems into bounded observations while
    keeping network clients, credentials, webhooks, and local worktrees outside
    semantic authority.

    - [ ] 6.2.1 Task {#jcf-p06-observation-ports} [repo: jido_code] [after: {#jcf-p06-enrollment-projections}] - Define provider, Git, clock, secret-reference, and observation ports.

      This task gives integrations explicit inputs and outputs without letting
      adapters write graphs or claim acceptance.

      - [ ] 6.2.1.1 Subtask {#jcf-p06-6-2-1-1} - Define provider repository, issue/pull request, branch, webhook, CI, and capability observation values with external IDs, source time, retrieval time, ETag/revision, and bounded raw-reference metadata.
      - [ ] 6.2.1.2 Subtask {#jcf-p06-6-2-1-2} - Define Git remote resolution, commit/tree identity, branch/ref state, diff scope, worktree materialization, and cleanup contracts.
      - [ ] 6.2.1.3 Subtask {#jcf-p06-6-2-1-3} - Define secret lookup by `CredentialReference` with values confined to adapter call scope and never returned in observation values.
      - [ ] 6.2.1.4 Subtask {#jcf-p06-6-2-1-4} - Require adapters to return evidence and limitations, never graph IRIs chosen outside identity policy, control transitions, or accepted claims.
      - [ ] 6.2.1.5 Subtask {#jcf-p06-6-2-1-5} - Supply deterministic fake adapters for pagination, rate limits, stale ETags, force pushes, missing refs, redirects, and provider failures.

    - [ ] 6.2.2 Task {#jcf-p06-provider-adapter} [repo: jido_code] [after: {#jcf-p06-observation-ports}] - Implement the first HTTP repository provider adapter.

      This task uses the repository's supported HTTP boundary to obtain
      authenticated, bounded provider observations without persisting API
      responses as hidden state.

      - [ ] 6.2.2.1 Subtask {#jcf-p06-6-2-2-1} - Use `Req` for HTTP calls with explicit base URL, authentication injection, timeouts, retry policy, pagination bounds, response size limits, and safe telemetry.
      - [ ] 6.2.2.2 Subtask {#jcf-p06-6-2-2-2} - Normalize repository identity, default branch, refs, visibility, archive/fork state, issues/pull requests, CI checks, permissions, and provider capability revisions needed by accepted observations.
      - [ ] 6.2.2.3 Subtask {#jcf-p06-6-2-2-3} - Preserve external object IDs, delivery IDs, ETags, source timestamps, and response digests for idempotency/provenance without retaining unbounded response bodies.
      - [ ] 6.2.2.4 Subtask {#jcf-p06-6-2-2-4} - Handle rate limits, partial pagination, permissions, deletion, transfer, stale credentials, transient failures, and unknown fields with explicit completeness/warnings.
      - [ ] 6.2.2.5 Subtask {#jcf-p06-6-2-2-5} - Redact tokens, authorization headers, private URLs, and confidential provider content from logs, telemetry, errors, graph literals, and fixtures.

    - [ ] 6.2.3 Task {#jcf-p06-git-adapter} [repo: jido_code] [after: {#jcf-p06-provider-adapter}] - Implement disposable local Git materialization and snapshot inspection.

      This task obtains exact source revisions for analysis and execution while
      ensuring local clones are caches, not persistent product truth.

      - [ ] 6.2.3.1 Subtask {#jcf-p06-6-2-3-1} - Materialize into explicit per-operation directories with bounded clone/fetch depth, ref allowlists, credential redaction, timeout, disk limit, and cleanup.
      - [ ] 6.2.3.2 Subtask {#jcf-p06-6-2-3-2} - Resolve commit SHA, tree SHA, parents, branch/ref identity, submodule/LFS presence, repository format, and worktree cleanliness.
      - [ ] 6.2.3.3 Subtask {#jcf-p06-6-2-3-3} - Verify provider-advertised and Git-resolved revisions agree or record an explicit contradiction/stale observation.
      - [ ] 6.2.3.4 Subtask {#jcf-p06-6-2-3-4} - Treat clone/fetch/worktree paths as ephemeral adapter state and prove deletion/recreation does not affect graph identity.
      - [ ] 6.2.3.5 Subtask {#jcf-p06-6-2-3-5} - Reject unsafe repository paths, local protocol abuse, hostile Git config, credential helpers, hooks, and oversized/unsupported repositories according to policy.

    - [ ] 6.2.4 Task {#jcf-p06-observation-ingress} [repo: jido_code] [after: {#jcf-p06-git-adapter}] - Implement polling and webhook observation ingress.

      This task converts external delivery into one normalized observation
      command path with stable idempotency and no direct provider mutation of
      graph state.

      - [ ] 6.2.4.1 Subtask {#jcf-p06-6-2-4-1} - Authenticate webhook deliveries, bind them to an enrolled locator, validate content type/size/signature/time window, and derive stable delivery identity.
      - [ ] 6.2.4.2 Subtask {#jcf-p06-6-2-4-2} - Normalize polling and webhook results into the same observation envelope and command semantics.
      - [ ] 6.2.4.3 Subtask {#jcf-p06-6-2-4-3} - Handle duplicate, delayed, reordered, replayed, partial, and unknown delivery types without mutating desired state.
      - [ ] 6.2.4.4 Subtask {#jcf-p06-6-2-4-4} - Queue only ephemeral wake-up work; durable pending/retry/last-observed state belongs in graph transitions and observation resources.

  - [ ] 6.3 Section - Persist observation batches, claims, and repository snapshots.

    This section records external reality as immutable, provenance-bearing
    graphs with explicit completeness and temporal semantics.

    - [ ] 6.3.1 Task {#jcf-p06-observation-batch} [repo: jido_code] [after: {#jcf-p06-observation-ingress}] - Implement `RecordObservationBatch` semantics.

      This task commits normalized observations under one immutable batch
      graph and retains enough source identity to explain and replay them.

      - [ ] 6.3.1.1 Subtask {#jcf-p06-6-3-1-1} - Create observation activity/batch IRIs from provider/delivery or poll identity, enrollment, retrieval revision, and idempotency policy.
      - [ ] 6.3.1.2 Subtask {#jcf-p06-6-3-1-2} - Record actor/adapter version, locator, external source refs, retrieval/source times, prior batch relation, request/response digests, coverage, completeness, limitations, and generated claims.
      - [ ] 6.3.1.3 Subtask {#jcf-p06-6-3-1-3} - Close the batch graph atomically and reject later mutation; corrections become new batches and superseding claims.
      - [ ] 6.3.1.4 Subtask {#jcf-p06-6-3-1-4} - Return the original receipt for duplicate delivery/poll identity and conflict on divergent logical content.
      - [ ] 6.3.1.5 Subtask {#jcf-p06-6-3-1-5} - Apply payload retention and redaction before RDF construction; do not persist unneeded raw provider bodies.

    - [ ] 6.3.2 Task {#jcf-p06-observed-claims} [repo: jido_code] [after: {#jcf-p06-observation-batch}] - Map observations into sourced repository claims.

      This task preserves what an adapter observed without upgrading it into
      accepted repository knowledge or control intent.

      - [ ] 6.3.2.1 Subtask {#jcf-p06-6-3-2-1} - Emit direct immutable statements where batch-level provenance suffices and first-class claims where confidence, validity, contradiction, or later acceptance matters.
      - [ ] 6.3.2.2 Subtask {#jcf-p06-6-3-2-2} - Link claims to repository, locator, branch/ref, external object, check, dependency, policy dimension, or source artifact subjects directly by IRI.
      - [ ] 6.3.2.3 Subtask {#jcf-p06-6-3-2-3} - Record observed/asserted epistemic state, source/valid time, confidence/limitations, and producer version without acceptance.
      - [ ] 6.3.2.4 Subtask {#jcf-p06-6-3-2-4} - Detect incompatible claims across batches and add contradiction relationships without deleting either source.
      - [ ] 6.3.2.5 Subtask {#jcf-p06-6-3-2-5} - Add queries for latest complete observation, claim history, contradictions, and provider freshness at an enrollment scope.

    - [ ] 6.3.3 Task {#jcf-p06-repository-snapshot} [repo: jido_code] [after: {#jcf-p06-observed-claims}] - Implement immutable repository snapshot identity and metadata.

      This task creates the exact source-state anchor used by semantic analysis,
      planning, execution, evidence, and reproducibility.

      - [ ] 6.3.3.1 Subtask {#jcf-p06-6-3-3-1} - Identify snapshots by conceptual repository plus verified commit/tree identity, not branch name or local checkout path.
      - [ ] 6.3.3.2 Subtask {#jcf-p06-6-3-3-2} - Record parent lineage, observed refs, source observation batch, analyzer readiness, manifest/language summary, and validity/freshness metadata.
      - [ ] 6.3.3.3 Subtask {#jcf-p06-6-3-3-3} - Reuse the same snapshot resource for identical repository/tree identity while preserving each observation activity that encountered it.
      - [ ] 6.3.3.4 Subtask {#jcf-p06-6-3-3-4} - Mark force-push/ref movement as new observations rather than changing immutable snapshot identity.

  - [ ] 6.4 Section - Analyze and publish revision-scoped source semantics.

    This section converts an exact disposable checkout into a coherent source
    graph that remains separate from ontology schema and from later control
    truth.

    - [ ] 6.4.1 Task {#jcf-p06-source-analysis-port} [repo: jido_code] [after: {#jcf-p06-repository-snapshot}] - Define and implement the source analyzer boundary.

      This task makes semantic extraction deterministic, versioned, bounded,
      and attributable without giving the analyzer direct store access.

      - [ ] 6.4.1.1 Subtask {#jcf-p06-6-4-1-1} - Define analyzer input as repository/snapshot IRI, verified worktree, language/profile, include/exclude scopes, limits, ontology version, and expected output graph.
      - [ ] 6.4.1.2 Subtask {#jcf-p06-6-4-1-2} - Evaluate and pin the source ontology/analyzer dependency needed for Elixir modules, functions, expressions, OTP patterns, dependencies, and optional Git evolution.
      - [ ] 6.4.1.3 Subtask {#jcf-p06-6-4-1-3} - Return an RDF dataset plus analyzer version, configuration, input tree digest, coverage, warnings, resource counts, and no commit authority.
      - [ ] 6.4.1.4 Subtask {#jcf-p06-6-4-1-4} - Bound files, bytes, symbols, expressions, time, memory, and unsupported language behavior.
      - [ ] 6.4.1.5 Subtask {#jcf-p06-6-4-1-5} - Exclude raw source text by default and require an explicit accepted policy before storing any source literal.

    - [ ] 6.4.2 Task {#jcf-p06-source-graph-publication} [repo: jido_code] [after: {#jcf-p06-source-analysis-port}] - Publish immutable source revision graphs.

      This task validates and atomically closes source semantics for one exact
      repository snapshot.

      - [ ] 6.4.2.1 Subtask {#jcf-p06-6-4-2-1} - Target `repo/{repo}/source/{revision}` and require repository/snapshot scope on every generated source entity IRI.
      - [ ] 6.4.2.2 Subtask {#jcf-p06-6-4-2-2} - Validate source ontology compatibility, graph metadata, entity scope, result limits, and analyzer provenance before commit.
      - [ ] 6.4.2.3 Subtask {#jcf-p06-6-4-2-3} - Publish the complete graph atomically, close it immutable, and link snapshot/analyzer activity/coverage without mixing ontology schema.
      - [ ] 6.4.2.4 Subtask {#jcf-p06-6-4-2-4} - Make identical analysis replay idempotent and divergent output for one analyzer/input identity a conflict requiring a new analyzer revision.
      - [ ] 6.4.2.5 Subtask {#jcf-p06-6-4-2-5} - Preserve prior revision graphs and mark latest/current source selection as a bounded query, not a mutable global graph replacement.

    - [ ] 6.4.3 Task {#jcf-p06-source-projections} [repo: jido_code] [after: {#jcf-p06-source-graph-publication}] - Implement bounded repository and source-semantic projections.

      This task exposes exact-snapshot semantic context to later workflows and
      product surfaces without permitting arbitrary dataset traversal.

      - [ ] 6.4.3.1 Subtask {#jcf-p06-6-4-3-1} - Add queries for snapshot readiness/freshness, modules, functions, OTP/runtime patterns, dependencies, and bounded source-entity neighborhoods.
      - [ ] 6.4.3.2 Subtask {#jcf-p06-6-4-3-2} - Add exact snapshot/revision, coverage, analyzer/ontology version, stale/degraded state, truncation, and warnings to every result.
      - [ ] 6.4.3.3 Subtask {#jcf-p06-6-4-3-3} - Add bounded impact projection around a source entity while preserving incoming/outgoing predicate identity and graph provenance.
      - [ ] 6.4.3.4 Subtask {#jcf-p06-6-4-3-4} - Reject an explicit source query that omits repository/snapshot scope or attempts unauthorized historical graph access.

  - [ ] 6.5 Section - Phase 6 Integration Tests.

    This final section proves enrollment and observation survive duplicates,
    reordering, provider drift, force pushes, clone loss, analysis failure, and
    restart while remaining reproducible from graph and external revisions.

    - [ ] 6.5.1 Task {#jcf-p06-enrollment-observation-integration} [repo: jido_code] [after: {#jcf-p06-source-projections}] - Execute repository enrollment through immutable observation batches.

      This task validates the first real external-to-graph product flow using
      fakes plus a controlled provider/Git fixture.

      - [ ] 6.5.1.1 Subtask {#jcf-p06-6-5-1-1} - Bootstrap, enroll a repository with multiple locators, observe provider/Git state, and project the active enrollment and latest complete observation.
      - [ ] 6.5.1.2 Subtask {#jcf-p06-6-5-1-2} - Replay duplicate polling/webhook deliveries, reorder delayed events, transfer/redirect a locator, suspend/resume enrollment, and retire without duplicate effects or history loss.
      - [ ] 6.5.1.3 Subtask {#jcf-p06-6-5-1-3} - Exercise invalid signatures, stale credentials, partial pagination, rate limits, provider deletion, locator ambiguity, and cross-enrollment attempts.
      - [ ] 6.5.1.4 Subtask {#jcf-p06-6-5-1-4} - Scan graph/export/log/telemetry/event/fixture outputs for credentials, raw provider bodies, private paths, and unapproved source text.

    - [ ] 6.5.2 Task {#jcf-p06-source-semantics-integration} [repo: jido_code] [after: {#jcf-p06-enrollment-observation-integration}] - Prove snapshot and source-graph reproducibility.

      This task verifies exact Git identity and semantic extraction remain
      coherent across changed refs, repeated analysis, process death, and local
      cache deletion.

      - [ ] 6.5.2.1 Subtask {#jcf-p06-6-5-2-1} - Resolve and analyze a fixture commit, delete its checkout, recreate it, rerun analysis, and compare canonical source graph output and provenance.
      - [ ] 6.5.2.2 Subtask {#jcf-p06-6-5-2-2} - Move/force-push a branch and prove old/new immutable snapshots and source graphs remain distinguishable and queryable by authorization.
      - [ ] 6.5.2.3 Subtask {#jcf-p06-6-5-2-3} - Kill analysis/publication before and after commit and prove no partial graph is current and replay is deterministic.
      - [ ] 6.5.2.4 Subtask {#jcf-p06-6-5-2-4} - Exercise oversized, unsupported, hostile-config, missing-ref, submodule/LFS, malformed analyzer output, and incomplete coverage cases.
      - [ ] 6.5.2.5 Subtask {#jcf-p06-6-5-2-5} - Backup/restore and verify enrollment, observation, snapshot, source graph, and query revisions remain equivalent.
      - [ ] 6.5.2.6 Subtask {#jcf-p06-6-5-2-6} - Rerun Phases 1-5 suites and `mix precommit`.

    - [ ] 6.5.3 Task {#jcf-p06-phase-receipt} [repo: jido_code] [after: {#jcf-p06-source-semantics-integration}] - Publish the Phase 6 repository-knowledge receipt.

      This task binds G5 to exact enrollment, adapter, observation, Git,
      snapshot, analyzer, ontology, query, security, and reproducibility
      evidence.

      - [ ] 6.5.3.1 Subtask {#jcf-p06-6-5-3-1} - Record provider/Git/analyzer versions, ontology/query versions, fixture repository commits, observation/source graph digests, and candidate commit.
      - [ ] 6.5.3.2 Subtask {#jcf-p06-6-5-3-2} - Attach duplicate/reorder, lifecycle, provider failure, force-push, cache deletion, crash, restore, redaction, and bounded-query results.
      - [ ] 6.5.3.3 Subtask {#jcf-p06-6-5-3-3} - Keep G5 blocked if a local clone is required for durable identity, source graphs mix schema, or provider output can directly become accepted/control truth.
      - [ ] 6.5.3.4 Subtask {#jcf-p06-6-5-3-4} - Pin the merged candidate commit before authorizing Phase 7.
