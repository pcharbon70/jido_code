---
id: plan.jido_code_m01_phase_02_store_ownership_topology_and_lifecycle
parent_plan: plan.jido_code_m01_knowledge_kernel
status: planned
intent: feature
---

# M01 JidoCode Phase 2 - Store Ownership, Topology, And Lifecycle

This phase creates the single supervised quad-store owner, its kernel-level
named-graph topology, and the readiness lifecycle that fails closed until the
authoritative dataset is open and verified.

Back to plan: [M01 README](./README.md)

- [ ] 2 Phase - Own the dataset behind one supervised, verifiable boundary.

  This phase makes the store physically durable and exclusively owned before
  any transaction, backup, or domain concept can reach it.

  - [ ] 2.1 Section - Implement store configuration and path safety.

    This section defines trusted, environment-specific storage inputs so
    neither configuration mistakes nor hostile paths can choose where durable
    state lives.

    - [ ] 2.1.1 Task {#m01-jc-p02-store-configuration} [repo: jido_code] [after: {#m01-jc-p01-integration}] - Implement explicit knowledge-store configuration.

      This task makes every storage location and durability setting an
      intentional, validated choice with typed failure modes.

      - [ ] 2.1.1.1 Subtask {#m01-jc-2-1-1-1} - Add compile/runtime configuration for store root, quad schema, durability/sync mode, open timeout, backup root, and supported schema version.
      - [ ] 2.1.1.2 Subtask {#m01-jc-2-1-1-2} - Reject store roots under workspace root, home, system paths, relative-traversal targets, symlink escapes, and world-writable locations.
      - [ ] 2.1.1.3 Subtask {#m01-jc-2-1-1-3} - Require unique temporary store paths per test run and prohibit production path reuse under Mix test.
      - [ ] 2.1.1.4 Subtask {#m01-jc-2-1-1-4} - Surface missing native libraries, invalid durability settings, and unsupported schema versions as typed startup errors, never crashes with raw backend reasons.
      - [ ] 2.1.1.5 Subtask {#m01-jc-2-1-1-5} - Document filesystem ownership, permissions, volume durability, free-space expectations, and unsupported shared-filesystem deployments.

  - [ ] 2.2 Section - Implement the supervised store owner.

    This section guarantees exactly one process opens the dataset and that all
    other code reaches it only through narrow typed operations.

    - [ ] 2.2.1 Task {#m01-jc-p02-store-server} [repo: jido_code] [after: {#m01-jc-p02-store-configuration}] - Implement `JidoCode.Knowledge.StoreServer`.

      This task holds the raw `TripleStore` handle in exactly one supervised
      process state and nowhere else.

      - [ ] 2.2.1.1 Subtask {#m01-jc-2-2-1-1} - Open `TripleStore` in quad mode during initialization and retain the raw handle only in `StoreServer` state.
      - [ ] 2.2.1.2 Subtask {#m01-jc-2-2-1-2} - Verify schema and store metadata before declaring the process ready.
      - [ ] 2.2.1.3 Subtask {#m01-jc-2-2-1-3} - Expose private, typed callbacks for bounded read, atomic update, statistics, checkpoint, backup, export, and integrity operations.
      - [ ] 2.2.1.4 Subtask {#m01-jc-2-2-1-4} - Close the store deterministically on normal shutdown and preserve recoverable diagnostics on abnormal termination.
      - [ ] 2.2.1.5 Subtask {#m01-jc-2-2-1-5} - Restrict direct callers to approved knowledge modules and instrument operation class without logging query text or graph content.

  - [ ] 2.3 Section - Implement kernel graph topology and readiness supervision.

    This section establishes named-graph creation with bounded metadata and
    wires store readiness into application supervision so nothing mutates
    before the dataset is authoritative.

    - [ ] 2.3.1 Task {#m01-jc-p02-graph-topology} [repo: jido_code] [after: {#m01-jc-p02-store-server}] - Implement kernel-level named-graph topology.

      This task gives every named graph bounded metadata and keeps the default
      graph structurally empty without yet imposing factory graph families.

      - [ ] 2.3.1.1 Subtask {#m01-jc-2-3-1-1} - Implement named-graph creation carrying kind, owner scope, lifecycle state, and creation-activity metadata within bounded literal sizes.
      - [ ] 2.3.1.2 Subtask {#m01-jc-2-3-1-2} - Enforce the empty-default-graph invariant at every creation and read boundary.
      - [ ] 2.3.1.3 Subtask {#m01-jc-2-3-1-3} - Provide kernel queries for graph existence, metadata, and bounded graph listing with no product semantics.
      - [ ] 2.3.1.4 Subtask {#m01-jc-2-3-1-4} - Reserve write policy for later milestones; this phase creates substrate metadata graphs only.

    - [ ] 2.3.2 Task {#m01-jc-p02-supervision-readiness} [repo: jido_code] [after: {#m01-jc-p02-graph-topology}] - Integrate lifecycle and readiness into application supervision.

      This task makes readiness truthful: durable surfaces cannot operate or
      report healthy while the store is unavailable or inconsistent.

      - [ ] 2.3.2.1 Subtask {#m01-jc-2-3-2-1} - Add `JidoCode.Knowledge.Supervisor` ahead of any worker or endpoint dependency that requires durable state.
      - [ ] 2.3.2.2 Subtask {#m01-jc-2-3-2-2} - Keep health degraded and reject durable operations while the store is opening, verifying, recovering, or in maintenance.
      - [ ] 2.3.2.3 Subtask {#m01-jc-2-3-2-3} - Define restart intensity and fail-stop behavior so repeated open failures never produce restart loops or fallback state.
      - [ ] 2.3.2.4 Subtask {#m01-jc-2-3-2-4} - Add controlled maintenance mode gating restore, integrity repair, and schema migration entry points.

  - [ ] 2.4 Section - Phase 2 Integration Tests.

    This final section proves ownership, topology, and readiness hold across
    restarts, lock contention, and process death.

    - [ ] 2.4.1 Task {#m01-jc-p02-integration} [repo: jido_code] [after: {#m01-jc-p02-supervision-readiness}] - Exercise production store lifecycle and supervision.

      This task verifies real startup, reopen identity, exclusive ownership,
      and fail-closed behavior on isolated stores.

      - [ ] 2.4.1.1 Subtask {#m01-jc-2-4-1-1} - Start on an empty store, initialize only substrate metadata, stop cleanly, reopen, and verify identical revisions and contents.
      - [ ] 2.4.1.2 Subtask {#m01-jc-2-4-1-2} - Attempt concurrent ownership, invalid paths, permission failures, stale locks, incompatible schema, and missing native libraries; verify typed errors and no partial readiness.
      - [ ] 2.4.1.3 Subtask {#m01-jc-2-4-1-3} - Kill `StoreServer` and the BEAM around open and write stages; verify supervision never reports an ambiguous commit as absent or healthy prematurely.
      - [ ] 2.4.1.4 Subtask {#m01-jc-2-4-1-4} - Verify the empty-default-graph and bounded-metadata invariants after restart and rerun the Phase 1 guardrail suite plus `mix precommit`.
