---
id: plan.jido_code_graph_factory_phase_05
intent: feature
source:
  - docs/research/graph-native-managed-repository-factory.md
---

# Phase 5 - Query Catalog, Temporal Projections, And Change Delivery

This phase implements the only supported product read boundary: a reviewed,
versioned query catalog with typed parameters, authorized named-graph scopes,
temporal and completeness constraints, bounded results, disposable projection
caches, revision-aware subscriptions, and rebuildable derived graph support.

Back to plan: [README](./README.md)

- [ ] 5 Phase - Make graph interpretation bounded, consistent, explainable, and safe for product and runtime consumers.

  This phase prevents raw SPARQL and full-dataset mirroring from spreading
  through the application while preserving the expressive joins that justify
  a knowledge-graph architecture.

  - [x] 5.1 Section - Implement the reviewed query catalog and execution boundary.

    This section gives each supported graph question a stable identity,
    version, parameter contract, graph scope, authorization rule, and bounded
    decoder.

    - [x] 5.1.1 Task {#jcf-p05-query-definition} [repo: jido_code] [after: {#jcf-p04-phase-receipt}] - Define the versioned query-catalog contract.

      This task turns SPARQL into reviewed application code with explicit
      semantics rather than accepting arbitrary strings from callers.

      - [x] 5.1.1.1 Subtask {#jcf-p05-5-1-1-1} - Define query name/version, purpose, query form, parameter schema, required actor capability, allowed graph families, completeness assumptions, timeout, row/triple/byte limits, and decoder.
      - [x] 5.1.1.2 Subtask {#jcf-p05-5-1-1-2} - Store query text in knowledge-owned modules or resources and bind source digests to the catalog version.
      - [x] 5.1.1.3 Subtask {#jcf-p05-5-1-1-3} - Distinguish scalar/tabular `SELECT` or `ASK`, bounded semantic-neighborhood `CONSTRUCT`, and privileged internal diagnostics.
      - [x] 5.1.1.4 Subtask {#jcf-p05-5-1-1-4} - Reject unknown versions, undeclared parameters, unbounded forms, mutation statements, service/federation clauses, and graph variables outside catalog policy.
      - [x] 5.1.1.5 Subtask {#jcf-p05-5-1-1-5} - Require compatibility notes and fixture updates for every query behavior or decoder change.

    - [x] 5.1.2 Task {#jcf-p05-query-parameters} [repo: jido_code] [after: {#jcf-p05-query-definition}] - Implement typed SPARQL parameter binding and graph selection.

      This task prevents string concatenation, injection, scope widening, and
      user-selected graph authority at every query call site.

      - [x] 5.1.2.1 Subtask {#jcf-p05-5-1-2-1} - Convert validated resource/graph IRIs, literals, controlled concepts, times, limits, and cursors into RDF/SPARQL terms through one binder.
      - [x] 5.1.2.2 Subtask {#jcf-p05-5-1-2-2} - Resolve allowed graph IRIs from authorized actor scope and graph registry rather than caller-supplied `GRAPH` text.
      - [x] 5.1.2.3 Subtask {#jcf-p05-5-1-2-3} - Reject control characters, malformed datatypes, unauthorized historical graphs, over-limit collections, and terms outside declared namespaces.
      - [x] 5.1.2.4 Subtask {#jcf-p05-5-1-2-4} - Add injection fixtures for quotes, braces, comments, prefixes, subqueries, graph clauses, update verbs, and encoded IRI escapes.

    - [x] 5.1.3 Task {#jcf-p05-query-executor} [repo: jido_code] [after: {#jcf-p05-query-parameters}] - Implement bounded catalog query execution.

      This task executes one reviewed query against one consistent dataset
      revision and returns normalized results plus provenance and limits.

      - [x] 5.1.3.1 Subtask {#jcf-p05-5-1-3-1} - Acquire an appropriate read snapshot or revision boundary through `StoreServer` and record evaluated dataset/graph revisions.
      - [x] 5.1.3.2 Subtask {#jcf-p05-5-1-3-2} - Enforce timeout, row, triple, byte, traversal-depth, and pagination bounds before decoding.
      - [x] 5.1.3.3 Subtask {#jcf-p05-5-1-3-3} - Return query/version, source graph revisions, ontology version, completeness, freshness, truncation, cursor, warnings, and execution class.
      - [x] 5.1.3.4 Subtask {#jcf-p05-5-1-3-4} - Redact raw query text and unauthorized resource identities from errors and telemetry.
      - [x] 5.1.3.5 Subtask {#jcf-p05-5-1-3-5} - Fail closed when authorization, graph metadata, ontology compatibility, or required completeness cannot be established.

    - [x] 5.1.4 Task {#jcf-p05-initial-query-set} [repo: jido_code] [after: {#jcf-p05-query-executor}] - Implement substrate and semantic-contract queries.

      This task supplies the minimal queries needed to test and operate later
      domain slices without predefining the product route surface.

      - [x] 5.1.4.1 Subtask {#jcf-p05-5-1-4-1} - Add graph metadata, dataset revision, ontology compatibility, command receipt, audit reference, and graph health queries.
      - [x] 5.1.4.2 Subtask {#jcf-p05-5-1-4-2} - Add resource description, bounded incoming/outgoing neighborhood, provenance chain, supporting/contradicting claim, and supersession queries.
      - [x] 5.1.4.3 Subtask {#jcf-p05-5-1-4-3} - Add transition-chain endpoint, transition history, temporal-as-of, graph completeness, and derived-graph freshness queries.
      - [x] 5.1.4.4 Subtask {#jcf-p05-5-1-4-4} - Keep repository, goal, execution, and UI-specific queries in their owning later phases.

  - [x] 5.2 Section - Implement temporal, current-state, and closed-world consistency.

    This section makes every operational answer explicit about time,
    completeness, revision, and unknown state instead of treating missing
    triples or wall-clock recency as truth.

    - [x] 5.2.1 Task {#jcf-p05-consistency-contract} [repo: jido_code] [after: {#jcf-p05-initial-query-set}] - Define query consistency and freshness modes.

      This task lets callers request exact, minimum, historical, or best-effort
      graph state without hidden waiting or silent stale fallback.

      - [x] 5.2.1.1 Subtask {#jcf-p05-5-2-1-1} - Accept exact dataset/graph revisions, minimum revisions, ontology version, required complete graphs, valid-time instant/interval, and derived-rule-set revision.
      - [x] 5.2.1.2 Subtask {#jcf-p05-5-2-1-2} - Define strict mode as fail-with-state, warn mode as bounded results with explicit degradation, and historical mode as an authorized exact graph set.
      - [x] 5.2.1.3 Subtask {#jcf-p05-5-2-1-3} - Reject ambiguous constraint combinations, unavailable history, stale derived graphs where prohibited, and unauthorized revision discovery.
      - [x] 5.2.1.4 Subtask {#jcf-p05-5-2-1-4} - Preserve the evaluated consistency receipt across pagination and projection decoding.

    - [x] 5.2.2 Task {#jcf-p05-current-state} [repo: jido_code] [after: {#jcf-p05-consistency-contract}] - Implement current-state resolution from transition chains.

      This task derives operational state causally and reports contradictions
      rather than reading a mutable status property.

      - [x] 5.2.2.1 Subtask {#jcf-p05-5-2-2-1} - Traverse from genesis through expected-predecessor and monotonic revision links to the unique valid, non-superseded endpoint.
      - [x] 5.2.2.2 Subtask {#jcf-p05-5-2-2-2} - Detect missing links, forks, cycles, illegal concepts, supersession ambiguity, and revision regression as integrity failures.
      - [x] 5.2.2.3 Subtask {#jcf-p05-5-2-2-3} - Return current state plus endpoint transition, chain revision, actor/cause references, and evaluated graph revision.
      - [x] 5.2.2.4 Subtask {#jcf-p05-5-2-2-4} - Add optional disposable current-state materialization keyed by exact source revision and prove it is never authoritative.

    - [x] 5.2.3 Task {#jcf-p05-completeness-boundary} [repo: jido_code] [after: {#jcf-p05-current-state}] - Implement declared closed-world query boundaries.

      This task permits safe operational negation only over explicitly complete
      graph families and revisions.

      - [x] 5.2.3.1 Subtask {#jcf-p05-5-2-3-1} - Define completeness assertions by subject/scope, graph family, source snapshot, predicate/class coverage, producer, and validity interval.
      - [x] 5.2.3.2 Subtask {#jcf-p05-5-2-3-2} - Require closed-world eligibility, authorization, and acceptance queries to name their complete input set.
      - [x] 5.2.3.3 Subtask {#jcf-p05-5-2-3-3} - Return unknown or incomplete rather than false when required coverage is absent, stale, contradictory, or invalidated.
      - [x] 5.2.3.4 Subtask {#jcf-p05-5-2-3-4} - Add negative fixtures proving a missing triple outside a complete boundary never satisfies a policy or precondition.

    - [x] 5.2.4 Task {#jcf-p05-temporal-querying} [repo: jido_code] [after: {#jcf-p05-completeness-boundary}] - Implement transaction-time and valid-time query helpers.

      This task lets product and control code ask what was known and what was
      externally valid without conflating the two timelines.

      - [x] 5.2.4.1 Subtask {#jcf-p05-5-2-4-1} - Select assertions by recorded/commit revision, source-observed time, valid interval, invalidation, and supersession.
      - [x] 5.2.4.2 Subtask {#jcf-p05-5-2-4-2} - Return concurrent incompatible claims with epistemic/provenance context rather than choosing the newest literal.
      - [x] 5.2.4.3 Subtask {#jcf-p05-5-2-4-3} - Support exact historical source snapshot and decision-context reconstruction where retained graphs exist.
      - [x] 5.2.4.4 Subtask {#jcf-p05-5-2-4-4} - Bound historical graph count, time range, result size, and authorization separately from current reads.

  - [ ] 5.3 Section - Implement bounded projections, caching, and subscriptions.

    This section converts query products into consumer-specific read models
    while ensuring every cache and notification can be discarded safely.

    - [ ] 5.3.1 Task {#jcf-p05-projection-contract} [repo: jido_code] [after: {#jcf-p05-temporal-querying}] - Define bounded graph projection envelopes.

      This task permits temporary structs and JSON-safe maps only as
      attributable views over exact graph revisions.

      - [ ] 5.3.1.1 Subtask {#jcf-p05-5-3-1-1} - Include projection name/version, actor scope, source graphs/revisions, ontology/query versions, generated time, completeness, freshness, truncation, warnings, and cursor.
      - [ ] 5.3.1.2 Subtask {#jcf-p05-5-3-1-2} - Define scalar, table, timeline, tree, and bounded-subgraph result shapes without exposing RDF/backend structs to web or runtime consumers.
      - [ ] 5.3.1.3 Subtask {#jcf-p05-5-3-1-3} - Preserve canonical resource IRIs for semantic actions while supplying separately escaped display labels.
      - [ ] 5.3.1.4 Subtask {#jcf-p05-5-3-1-4} - Reject projections whose decoder drops provenance, widens scope, invents status, or silently resolves contradictions.

    - [ ] 5.3.2 Task {#jcf-p05-projection-cache} [repo: jido_code] [after: {#jcf-p05-projection-contract}] - Implement optional disposable projection caching.

      This task improves repeated reads without creating a second source of
      truth or serving results under mismatched authority and revision.

      - [ ] 5.3.2.1 Subtask {#jcf-p05-5-3-2-1} - Key caches by projection/query version, normalized parameters, actor authorization scope, graph revisions, ontology version, and consistency mode.
      - [ ] 5.3.2.2 Subtask {#jcf-p05-5-3-2-2} - Keep cache values in memory or a graph-tagged rebuildable derived graph only; do not add a durable cache database.
      - [ ] 5.3.2.3 Subtask {#jcf-p05-5-3-2-3} - Invalidate or bypass entries when any source revision, grant, ontology/query version, completeness assertion, or derived rule set changes.
      - [ ] 5.3.2.4 Subtask {#jcf-p05-5-3-2-4} - Prove cache eviction, process restart, and complete cache deletion do not change product behavior.

    - [ ] 5.3.3 Task {#jcf-p05-subscription-boundary} [repo: jido_code] [after: {#jcf-p05-projection-cache}] - Implement revision-aware projection subscriptions.

      This task lets LiveViews and workers react to relevant commits while
      treating PubSub as a lossy optimization.

      - [ ] 5.3.3.1 Subtask {#jcf-p05-5-3-3-1} - Subscribe by authorized low-cardinality factory, enrollment, repository, goal, or attempt scope as those resources become available.
      - [ ] 5.3.3.2 Subtask {#jcf-p05-5-3-3-2} - Track the consumer's last evaluated revision and re-query when a notification indicates a newer relevant commit.
      - [ ] 5.3.3.3 Subtask {#jcf-p05-5-3-3-3} - Coalesce bursts without skipping the newest revision and recover on reconnect or mailbox loss with a fresh query.
      - [ ] 5.3.3.4 Subtask {#jcf-p05-5-3-3-4} - Reauthorize subscriptions and projections when grants, actor scope, or session authority changes.

  - [ ] 5.4 Section - Establish derived graph and diagnostic query infrastructure.

    This section prepares safe inference/materialization and operator diagnosis
    without implementing repository policy or learning rules prematurely.

    - [ ] 5.4.1 Task {#jcf-p05-derived-graph-manager} [repo: jido_code] [after: {#jcf-p05-subscription-boundary}] - Implement rebuildable derived graph lifecycle.

      This task creates, validates, publishes, invalidates, and replaces
      materialized views or inferences under exact source revisions.

      - [ ] 5.4.1.1 Subtask {#jcf-p05-5-4-1-1} - Define derivation requests with rule/query version, ontology version, source graph revisions, target derived graph, and expected prior derivation.
      - [ ] 5.4.1.2 Subtask {#jcf-p05-5-4-1-2} - Build into an isolated target, validate metadata and shape, then atomically publish the complete derived graph.
      - [ ] 5.4.1.3 Subtask {#jcf-p05-5-4-1-3} - Mark derived graphs stale on relevant source commits and prohibit strict consumers from treating stale output as current.
      - [ ] 5.4.1.4 Subtask {#jcf-p05-5-4-1-4} - Delete and rebuild derived graphs without changing asserted graph revisions or command history.

    - [ ] 5.4.2 Task {#jcf-p05-read-diagnostics} [repo: jido_code] [after: {#jcf-p05-derived-graph-manager}] - Implement bounded query and projection diagnostics.

      This task helps operators explain stale, incomplete, truncated, invalid,
      or unauthorized results without exposing raw store internals.

      - [ ] 5.4.2.1 Subtask {#jcf-p05-5-4-2-1} - Report catalog/query/projection versions, evaluated graph revisions, consistency result, completeness gaps, truncation, cache disposition, and safe error code.
      - [ ] 5.4.2.2 Subtask {#jcf-p05-5-4-2-2} - Add privileged read-only diagnostic queries with strict graph allowlists and limits.
      - [ ] 5.4.2.3 Subtask {#jcf-p05-5-4-2-3} - Prohibit diagnostic query text, backend IDs, source bodies, secrets, unauthorized graph names, and arbitrary exception details from ordinary users.
      - [ ] 5.4.2.4 Subtask {#jcf-p05-5-4-2-4} - Document when to re-query, rebuild a derived graph, restore completeness, or escalate integrity failure.

  - [ ] 5.5 Section - Phase 5 Integration Tests.

    This final section proves reviewed reads remain bounded, revision-correct,
    authorization-scoped, temporally explicit, and recoverable despite cache
    loss, notification loss, concurrent commits, and incomplete knowledge.

    - [ ] 5.5.1 Task {#jcf-p05-query-integration} [repo: jido_code] [after: {#jcf-p05-read-diagnostics}] - Exercise catalog queries over real multi-graph datasets.

      This task validates query parameterization, source-revision attribution,
      temporal behavior, completeness, and projection decoding end to end.

      - [ ] 5.5.1.1 Subtask {#jcf-p05-5-5-1-1} - Execute every initial catalog query against valid, empty, contradictory, superseded, historical, incomplete, and unauthorized fixtures.
      - [ ] 5.5.1.2 Subtask {#jcf-p05-5-5-1-2} - Attempt SPARQL injection, graph-scope widening, update statements, service clauses, excessive limits, expensive traversals, and malformed cursors.
      - [ ] 5.5.1.3 Subtask {#jcf-p05-5-5-1-3} - Advance source graphs during reads and verify each result is labeled with one coherent evaluated revision.
      - [ ] 5.5.1.4 Subtask {#jcf-p05-5-5-1-4} - Prove missing statements outside declared complete boundaries remain unknown and cannot satisfy closed-world checks.

    - [ ] 5.5.2 Task {#jcf-p05-projection-delivery-integration} [repo: jido_code] [after: {#jcf-p05-query-integration}] - Exercise projection caches, derived graphs, and lossy subscriptions.

      This task proves projection optimizations can disappear or fail without
      changing authoritative answers.

      - [ ] 5.5.2.1 Subtask {#jcf-p05-5-5-2-1} - Warm, hit, invalidate, evict, restart, and delete caches while comparing canonical uncached projection results.
      - [ ] 5.5.2.2 Subtask {#jcf-p05-5-5-2-2} - Drop, duplicate, reorder, and coalesce notifications and prove consumers converge to the latest authorized graph revision.
      - [ ] 5.5.2.3 Subtask {#jcf-p05-5-5-2-3} - Build, stale, invalidate, delete, and rebuild a derived graph while strict/warn readers report correct state.
      - [ ] 5.5.2.4 Subtask {#jcf-p05-5-5-2-4} - Revoke actor authority during a subscription and verify subsequent re-query and projection fail closed.
      - [ ] 5.5.2.5 Subtask {#jcf-p05-5-5-2-5} - Run query performance baselines at configured bounds and verify telemetry cardinality/redaction.
      - [ ] 5.5.2.6 Subtask {#jcf-p05-5-5-2-6} - Rerun Phases 1-4 suites and `mix precommit`.

    - [ ] 5.5.3 Task {#jcf-p05-phase-receipt} [repo: jido_code] [after: {#jcf-p05-projection-delivery-integration}] - Publish the Phase 5 bounded-read receipt.

      This task binds G4 to exact query, projection, consistency, cache,
      derived-graph, authorization, and notification evidence before external
      repository facts enter the dataset.

      - [ ] 5.5.3.1 Subtask {#jcf-p05-5-5-3-1} - Record query/projection catalog versions and digests, ontology/shape versions, consistency modes, fixture digests, limits, and candidate commit.
      - [ ] 5.5.3.2 Subtask {#jcf-p05-5-5-3-2} - Attach temporal, completeness, injection, concurrency, cache-loss, event-loss, derived-graph, authorization, and performance results.
      - [ ] 5.5.3.3 Subtask {#jcf-p05-5-5-3-3} - Keep G4 blocked if callers can submit raw SPARQL, results can lose source revisions, or cache/notifications can become authoritative.
      - [ ] 5.5.3.4 Subtask {#jcf-p05-5-5-3-4} - Pin the merged candidate commit before authorizing Phase 6.
