---
id: plan.jido_code_m01_phase_01_contract_dependency_pins_and_guardrails
parent_plan: plan.jido_code_m01_knowledge_kernel
status: planned
intent: feature
---

# M01 JidoCode Phase 1 - Contract, Dependency Pins, And Guardrails

This phase ratifies the kernel boundary, pins every dependency and toolchain
version that can affect store durability, proves backend compatibility with
executable fixtures, and installs architecture guardrails before any store
lifecycle code exists.

Back to plan: [M01 README](./README.md)

- [ ] 1 Phase - Establish the ratified kernel contract and its enforcement floor.

  This phase turns accepted document truth into pinned versions, compatibility
  fixtures, and guardrail tests without exposing any store operation to
  application code.

  - [ ] 1.1 Section - Ratify kernel boundary and dependency pins.

    This section makes the durable substrate reproducible by pinning every
    version that can change on-disk format, durability, or build behavior.

    - [ ] 1.1.1 Task {#m01-jc-p01-pins} [repo: jido_code] - Pin the knowledge-kernel dependency and toolchain floor.

      This task removes build-time and on-disk-format ambiguity before the
      store is ever opened in CI.

      - [ ] 1.1.1.1 Subtask {#m01-jc-1-1-1-1} - Pin TripleStore to an exact Git commit, RDF, Decimal, erlang-rocksdb, the bundled RocksDB version, and Rustler in `mix.exs` and `mix.lock`.
      - [ ] 1.1.1.2 Subtask {#m01-jc-1-1-1-2} - Pin OTP, Elixir, Rust/Cargo, Node.js/npm, and the canonical CI platform in `.tool-versions`, `rust-toolchain.toml`, and `.github/workflows/ci.yml`.
      - [ ] 1.1.1.3 Subtask {#m01-jc-1-1-1-3} - Document the native build prerequisites (Git, CMake, `pkg-config`, C/C++ toolchain, Rust) and the in-worktree dependency-path constraint.
      - [ ] 1.1.1.4 Subtask {#m01-jc-1-1-1-4} - Verify a clean isolated build with `MIX_DEPS_PATH` and `MIX_BUILD_PATH` outside the default locations compiles with warnings treated as errors.

    - [ ] 1.1.2 Task {#m01-jc-p01-compat-proof} [repo: jido_code] [after: {#m01-jc-p01-pins}] - Prove TripleStore backend compatibility with executable fixtures.

      This task demonstrates every kernel-required backend behavior against a
      digest-recorded named-graph TriG fixture before lifecycle code depends
      on it.

      - [ ] 1.1.2.1 Subtask {#m01-jc-1-1-2-1} - Prove quad-schema open, close, and reopen with multiple named graphs and an empty default graph.
      - [ ] 1.1.2.2 Subtask {#m01-jc-1-1-2-2} - Prove bounded `ASK`, `SELECT`, and `CONSTRUCT` queries plus one atomic multi-graph update.
      - [ ] 1.1.2.3 Subtask {#m01-jc-1-1-2-3} - Prove invalid-update rollback and all-or-none visibility after caller and database-owner termination at pre-commit, committed, and graceful post-commit points.
      - [ ] 1.1.2.4 Subtask {#m01-jc-1-1-2-4} - Prove one-writer ownership with expected second-open locking, bounded concurrent reads, N-Quads/TriG export, checkpoint restore, and dictionary identity.
      - [ ] 1.1.2.5 Subtask {#m01-jc-1-1-2-5} - Record the fixture set SHA-256 digests and assert the graph fixture digest at runtime.

  - [ ] 1.2 Section - Enforce sole-store architecture guardrails.

    This section makes the graph-only invariant mechanically visible so a
    second persistence path cannot appear unnoticed in later milestones.

    - [ ] 1.2.1 Task {#m01-jc-p01-guardrails} [repo: jido_code] [after: {#m01-jc-p01-compat-proof}] - Implement architecture guardrail tests for the kernel boundary.

      This task fails the build when forbidden persistence, access, or model
      patterns enter application code.

      - [ ] 1.2.1.1 Subtask {#m01-jc-1-2-1-1} - Reject Ecto schemas, Ash resources, DETS, Mnesia, JSON snapshot stores, record codecs, generic entity CRUD stores, and foreign-key-shaped models.
      - [ ] 1.2.1.2 Subtask {#m01-jc-1-2-1-2} - Reject raw store-handle access outside the knowledge boundary, reverse imports from web/runtime/integration layers, and direct `TripleStore` calls outside the owning module.
      - [ ] 1.2.1.3 Subtask {#m01-jc-1-2-1-3} - Reject raw UI-issued SPARQL and write-capable query paths while allowing classified disposable filesystem effects.
      - [ ] 1.2.1.4 Subtask {#m01-jc-1-2-1-4} - Keep the guardrail suite fast, deterministic, and wired into `mix precommit`.

  - [ ] 1.3 Section - Phase 1 Integration Tests.

    This final section proves the contract, pins, and guardrails hold from a
    clean checkout before store ownership is authorized.

    - [ ] 1.3.1 Task {#m01-jc-p01-integration} [repo: jido_code] [after: {#m01-jc-p01-guardrails}] - Execute the Phase 1 clean-checkout gates.

      This task supplies the pinned baseline every later phase must reproduce.

      - [ ] 1.3.1.1 Subtask {#m01-jc-1-3-1-1} - Run the compatibility, crash-recovery, and failure-mode fixture suites against the pinned backend.
      - [ ] 1.3.1.2 Subtask {#m01-jc-1-3-1-2} - Run the architecture guardrail suite and `mix precommit` with warnings as errors.
      - [ ] 1.3.1.3 Subtask {#m01-jc-1-3-1-3} - Run `mix hex.audit` and `npm audit --omit=dev` and record results.
      - [ ] 1.3.1.4 Subtask {#m01-jc-1-3-1-4} - Record the merged candidate commit, dependency pins, and fixture digests to authorize Phase 2.
