---
id: plan.jido_code_graph_factory_phase_01
intent: control_plane_change
source:
  - docs/research/graph-native-managed-repository-factory.md
---

# Phase 1 - Architecture Contract, Compatibility, And Guardrails

This phase turns the proposed research architecture into an accepted,
testable implementation boundary and proves that the selected `TripleStore`,
SPARQL, RDF, RocksDB, Elixir, OTP, Rust, and operating-system combination can
support the required quad-store semantics before product code depends on it.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Ratify the graph-native factory boundary and establish a reproducible compatibility baseline.

  This phase removes foundational ambiguity about source-of-truth scope,
  external-system boundaries, backend capabilities, dependency versions, and
  enforcement so later phases do not build against an assumed store contract.

  - [x] 1.1 Section - Ratify architecture, scope, and ownership.

    This section converts the research recommendations into repository-owned
    decisions and records the exact responsibilities of the knowledge, data,
    control, reconciliation, execution, projection, and presentation planes.

    - [x] 1.1.1 Task {#jcf-p01-current-state-inventory} [repo: jido_code] - Inventory the current application and every potential persistence path.

      This task establishes a verifiable starting point for a minimal Phoenix
      application before graph, runtime, provider, or authentication state is
      introduced.

      - [x] 1.1.1.1 Subtask {#jcf-p01-1-1-1-1} - Record the current supervisor tree, routes, LiveView assigns, LiveVue browser state, local-storage use, filesystem outputs, Mix aliases, dependencies, configuration, and test support.
      - [x] 1.1.1.2 Subtask {#jcf-p01-1-1-1-2} - Classify each current state holder as ephemeral runtime state, device-local presentation preference, external-system state, build artifact, secret material, telemetry, or proposed durable product knowledge.
      - [x] 1.1.1.3 Subtask {#jcf-p01-1-1-1-3} - Verify that no Ecto repository, Ash resource, DETS table, Mnesia table, JSON snapshot, durable queue, or hidden product-state file already exists.
      - [x] 1.1.1.4 Subtask {#jcf-p01-1-1-1-4} - Record the exact starting commit, Elixir/OTP versions, Rust toolchain, RocksDB availability, and supported development/test operating systems.

    - [x] 1.1.2 Task {#jcf-p01-architecture-decision} [repo: jido_code] [after: {#jcf-p01-current-state-inventory}] - Ratify the graph-only source-of-truth and plane boundaries.

      This task creates the accepted repository-local decision that permits
      implementation and resolves any research questions that cannot remain
      optional once code is written.

      - [x] 1.1.2.1 Subtask {#jcf-p01-1-1-2-1} - Accept or amend the invariant that all application-owned durable knowledge, control state, workflow state, user-authored state, and factory history lives in one `TripleStore` quad dataset.
      - [x] 1.1.2.2 Subtask {#jcf-p01-1-1-2-2} - Ratify Git/provider systems as observed external authorities, local clones and sandboxes as disposable work material, and secret providers as the only holders of credential values.
      - [x] 1.1.2.3 Subtask {#jcf-p01-1-1-2-3} - Ratify named graphs as authority/provenance/lifecycle boundaries, append-first evolution, graph-native relationships, explicit epistemic state, and decision-gated acceptance.
      - [x] 1.1.2.4 Subtask {#jcf-p01-1-1-2-4} - Record that the current repository owns its route contract and that no route or object-shaped record model is inherited from the older implementation.
      - [x] 1.1.2.5 Subtask {#jcf-p01-1-1-2-5} - Resolve whether any device-local preference, large binary artifact, or operational history needs an explicit exception or must become graph-backed.

    - [x] 1.1.3 Task {#jcf-p01-boundary-map} [repo: jido_code] [after: {#jcf-p01-architecture-decision}] - Define module ownership and allowed dependency directions.

      This task makes the architectural planes enforceable in the Elixir
      namespace and supervisor topology rather than leaving them as prose.

      - [x] 1.1.3.1 Subtask {#jcf-p01-1-1-3-1} - Assign store lifecycle, writes, queries, ontology, validation, reasoning, backup, and change delivery to `JidoCode.Knowledge`.
      - [x] 1.1.3.2 Subtask {#jcf-p01-1-1-3-2} - Assign enrollment, observation, reconciliation, scheduling, execution, evaluation, and learning coordination to capability-oriented `JidoCode.Factory` services.
      - [x] 1.1.3.3 Subtask {#jcf-p01-1-1-3-3} - Define ports for providers, Git, source analysis, Jido/runtime, tools, sandboxes, secrets, clocks, and identifiers without granting adapters semantic authority.
      - [x] 1.1.3.4 Subtask {#jcf-p01-1-1-3-4} - Prohibit web modules, integration adapters, runtime workers, and projections from opening the store or issuing raw write-capable SPARQL.
      - [x] 1.1.3.5 Subtask {#jcf-p01-1-1-3-5} - Define which structs are permitted as temporary command/projection values and prohibit persisted aggregate-root semantics.

  - [x] 1.2 Section - Prove backend and toolchain compatibility.

    This section tests the actual backend features and build prerequisites that
    the architecture depends on before production modules or graph data exist.

    - [x] 1.2.1 Task {#jcf-p01-dependency-candidate} [repo: jido_code] [after: {#jcf-p01-boundary-map}] - Select and pin a compatible graph dependency set.

      This task chooses reproducible dependency revisions based on tested
      behavior rather than copying the older project's lockfile blindly.

      - [x] 1.2.1.1 Subtask {#jcf-p01-1-2-1-1} - Evaluate the maintained `TripleStore`, SPARQL, RDF, RocksDB, and parser dependencies against the project's supported Elixir and OTP range.
      - [x] 1.2.1.2 Subtask {#jcf-p01-1-2-1-2} - Decide whether the application toolchain must move from its current Elixir constraint and record the upgrade/rollback implications.
      - [x] 1.2.1.3 Subtask {#jcf-p01-1-2-1-3} - Pin exact Git revisions or released versions where reproducibility or unpublished fixes require them.
      - [x] 1.2.1.4 Subtask {#jcf-p01-1-2-1-4} - Document native requirements, supported RocksDB versions, Rust/NIF compilation, CI packages, and developer setup failure messages.
      - [x] 1.2.1.5 Subtask {#jcf-p01-1-2-1-5} - Run dependency security, license, and transitive-persistence review before accepting the candidate.

    - [x] 1.2.2 Task {#jcf-p01-store-capability-spike} [repo: jido_code] [after: {#jcf-p01-dependency-candidate}] - Exercise the required `TripleStore` capabilities in an isolated spike.

      This task proves named-graph, query, update, transaction, reasoning, and
      export behavior using executable fixtures instead of relying on README
      claims.

      - [x] 1.2.2.1 Subtask {#jcf-p01-1-2-2-1} - Open a quad-schema store, load an RDF dataset into multiple named graphs, and verify the default graph remains empty.
      - [x] 1.2.2.2 Subtask {#jcf-p01-1-2-2-2} - Execute bounded `SELECT`, `ASK`, and `CONSTRUCT` queries plus an atomic multi-graph SPARQL Update.
      - [x] 1.2.2.3 Subtask {#jcf-p01-1-2-2-3} - Verify rollback and process-crash visibility at transaction boundaries, including whether a commit-marker fallback is required.
      - [x] 1.2.2.4 Subtask {#jcf-p01-1-2-2-4} - Materialize a minimal OWL 2 RL fixture into an isolated derived graph and prove asserted inputs remain distinguishable.
      - [x] 1.2.2.5 Subtask {#jcf-p01-1-2-2-5} - Backup, close, restore, export to N-Quads/TriG, reopen, and compare named-graph contents and dictionary identity behavior.

    - [x] 1.2.3 Task {#jcf-p01-operational-compatibility} [repo: jido_code] [after: {#jcf-p01-store-capability-spike}] - Define supported storage and runtime operating constraints.

      This task records the practical limits within which the embedded database
      can be treated as authoritative and fail safely.

      - [x] 1.2.3.1 Subtask {#jcf-p01-1-2-3-1} - Verify single-process ownership, filesystem locking, read concurrency, shutdown, reopen, and stale-lock behavior.
      - [x] 1.2.3.2 Subtask {#jcf-p01-1-2-3-2} - Establish durability and sync settings for development, test, and production without weakening accepted-write semantics.
      - [x] 1.2.3.3 Subtask {#jcf-p01-1-2-3-3} - Measure baseline startup, write, query, backup, and restore behavior on a representative small dataset.
      - [x] 1.2.3.4 Subtask {#jcf-p01-1-2-3-4} - Define disk-full, permission, corruption, incompatible-schema, and NIF-load failure outcomes.
      - [x] 1.2.3.5 Subtask {#jcf-p01-1-2-3-5} - Record unsupported deployment topologies, especially concurrent BEAM writers against one local store path.

  - [x] 1.3 Section - Establish architecture enforcement and deterministic test support.

    This section creates the static and dynamic guardrails that keep later work
    from introducing an accidental second model or persistence path.

    - [x] 1.3.1 Task {#jcf-p01-test-store-support} [repo: jido_code] [after: {#jcf-p01-operational-compatibility}] - Implement isolated graph-store test support.

      This task gives every future storage test a deterministic, recoverable,
      non-shared database fixture with explicit cleanup and diagnostics.

      - [x] 1.3.1.1 Subtask {#jcf-p01-1-3-1-1} - Allocate unique temporary store directories without using broad or unresolved cleanup targets.
      - [x] 1.3.1.2 Subtask {#jcf-p01-1-3-1-2} - Supply fixed clocks, deterministic IRI/ID generation, immutable RDF fixtures, and seedable concurrency helpers.
      - [x] 1.3.1.3 Subtask {#jcf-p01-1-3-1-3} - Ensure tests close RocksDB handles before cleanup and retain bounded diagnostics on failure.
      - [x] 1.3.1.4 Subtask {#jcf-p01-1-3-1-4} - Mark real-store integration tests for safe async behavior and prohibit shared store paths across test cases.

    - [x] 1.3.2 Task {#jcf-p01-architecture-gates} [repo: jido_code] [after: {#jcf-p01-test-store-support}] - Add executable dependency and persistence guardrails.

      This task makes prohibited dependencies and storage APIs fail CI as soon
      as they appear.

      - [x] 1.3.2.1 Subtask {#jcf-p01-1-3-2-1} - Add source scans for Ecto repositories, Ash resources, DETS, Mnesia, ad hoc file persistence, direct RocksDB access, and store opens outside the knowledge owner.
      - [x] 1.3.2.2 Subtask {#jcf-p01-1-3-2-2} - Add dependency-direction tests preventing web, runtime, factory, and integration modules from reaching knowledge internals.
      - [x] 1.3.2.3 Subtask {#jcf-p01-1-3-2-3} - Add forbidden-pattern checks for record codecs, generic entity stores, foreign-key-shaped relationship persistence, and raw UI SPARQL.
      - [x] 1.3.2.4 Subtask {#jcf-p01-1-3-2-4} - Integrate the architecture checks into `mix precommit` with actionable, bounded errors.

    - [x] 1.3.3 Task {#jcf-p01-failure-vocabulary} [repo: jido_code] [after: {#jcf-p01-architecture-gates}] - Define baseline errors, health states, and safe telemetry.

      This task gives backend and boundary failures stable meanings before
      higher-level commands depend on them.

      - [x] 1.3.3.1 Subtask {#jcf-p01-1-3-3-1} - Distinguish unavailable, incompatible, locked, corrupt, invalid input, unauthorized, conflict, stale precondition, timeout, and persistence failure.
      - [x] 1.3.3.2 Subtask {#jcf-p01-1-3-3-2} - Define health states that never report ready before store verification and required ontology compatibility pass.
      - [x] 1.3.3.3 Subtask {#jcf-p01-1-3-3-3} - Define low-cardinality telemetry fields that exclude raw SPARQL, graph contents, credentials, filesystem details, and arbitrary IRIs.
      - [x] 1.3.3.4 Subtask {#jcf-p01-1-3-3-4} - Define startup and request behavior when the knowledge substrate cannot accept durable operations.

  - [ ] 1.4 Section - Phase 1 Integration Tests.

    This final section proves the architecture can be built on the selected
    backend/toolchain and that the repository rejects alternate persistence or
    boundary leakage before Phase 2 creates the production store owner.

    - [x] 1.4.1 Task {#jcf-p01-compatibility-integration} [repo: jido_code] [after: {#jcf-p01-failure-vocabulary}] - Run the clean compatibility and backend capability suite.

      This task validates the candidate dependency set from a clean checkout
      and exercises every backend capability required by later phases.

      - [x] 1.4.1.1 Subtask {#jcf-p01-1-4-1-1} - Build native dependencies from a clean dependency cache on every supported CI environment.
      - [x] 1.4.1.2 Subtask {#jcf-p01-1-4-1-2} - Replay named-graph load/query/update/reasoning/export/restore fixtures and compare canonical results.
      - [x] 1.4.1.3 Subtask {#jcf-p01-1-4-1-3} - Kill and reopen the spike around pre-commit, commit, and post-commit boundaries and verify no ambiguous visible state.
      - [x] 1.4.1.4 Subtask {#jcf-p01-1-4-1-4} - Exercise lock contention, incompatible schema, invalid RDF/SPARQL, permission failure, and bounded error redaction.

    - [x] 1.4.2 Task {#jcf-p01-guardrail-integration} [repo: jido_code] [after: {#jcf-p01-compatibility-integration}] - Falsify the architecture guardrails with prohibited fixtures.

      This task proves CI catches realistic attempts to introduce a second
      source of truth or bypass the knowledge boundary.

      - [x] 1.4.2.1 Subtask {#jcf-p01-1-4-2-1} - Verify test fixtures containing Ecto, Ash, DETS, Mnesia, direct store-open, file snapshot, and raw UI SPARQL patterns are rejected.
      - [x] 1.4.2.2 Subtask {#jcf-p01-1-4-2-2} - Verify permitted temporary files, build artifacts, test directories, and external secret references do not create false positives.
      - [x] 1.4.2.3 Subtask {#jcf-p01-1-4-2-3} - Run dependency-boundary tests against intentional reverse imports and raw store-handle leakage.
      - [x] 1.4.2.4 Subtask {#jcf-p01-1-4-2-4} - Run `mix precommit` from the accepted dependency and guardrail candidate.

    - [ ] 1.4.3 Task {#jcf-p01-phase-receipt} [repo: jido_code] [after: {#jcf-p01-guardrail-integration}] - Publish the Phase 1 architecture and compatibility receipt.

      This task records the accepted decision, exact toolchain and dependency
      revisions, capability results, constraints, and guardrail proof required
      to authorize the production knowledge substrate.

      - [x] 1.4.3.1 Subtask {#jcf-p01-1-4-3-1} - Record accepted ADR/spec references, backend pins, toolchain matrix, fixture digests, commands, and test results.
      - [x] 1.4.3.2 Subtask {#jcf-p01-1-4-3-2} - Record transaction limitations and the selected atomicity strategy, including any commit-marker requirement.
      - [x] 1.4.3.3 Subtask {#jcf-p01-1-4-3-3} - Keep G0 blocked if any source-of-truth exception, backend capability, native prerequisite, or dependency direction remains ambiguous.
      - [ ] 1.4.3.4 Subtask {#jcf-p01-1-4-3-4} - Pin the merged candidate commit before authorizing Phase 2.
