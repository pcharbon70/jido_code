---
id: plan.jido_code_graph_factory_phase_02
intent: control_plane_change
source:
  - docs/research/graph-native-managed-repository-factory.md
---

# Phase 2 - Embedded Quad Store And Recovery Foundation

This phase implements the supervised production knowledge substrate: one
quad-schema `TripleStore` owner, deterministic startup and shutdown, serialized
atomic writes, graph revisions, backup/restore/export, health, integrity, and
failure recovery without introducing ontology-specific product behavior.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Build the authoritative embedded quad-store lifecycle and recovery boundary.

  This phase makes the graph physically durable and operationally trustworthy
  before repository, work, execution, or UI concepts can persist in it.

  - [x] 2.1 Section - Implement store ownership, configuration, and lifecycle.

    This section creates the only process allowed to open and own the
    `TripleStore` handle and integrates readiness with the Phoenix supervision
    tree.

    - [x] 2.1.1 Task {#jcf-p02-store-configuration} [repo: jido_code] [after: {#jcf-p01-phase-receipt}] - Implement explicit knowledge-store configuration.

      This task defines safe, environment-specific storage inputs without
      letting arbitrary request or user data choose database paths or
      durability behavior.

      - [x] 2.1.1.1 Subtask {#jcf-p02-2-1-1-1} - Add compile/runtime configuration for store root, quad schema, durability/sync mode, open timeout, backup root, and supported schema version.
      - [x] 2.1.1.2 Subtask {#jcf-p02-2-1-1-2} - Resolve development, test, and production paths from trusted configuration and reject root, home, workspace-root, relative traversal, symlink escape, or world-writable targets.
      - [x] 2.1.1.3 Subtask {#jcf-p02-2-1-1-3} - Require unique temporary paths in tests and prohibit production path reuse under Mix test.
      - [x] 2.1.1.4 Subtask {#jcf-p02-2-1-1-4} - Surface missing native libraries, invalid durability settings, and unsupported schema versions as typed startup errors.
      - [x] 2.1.1.5 Subtask {#jcf-p02-2-1-1-5} - Document filesystem ownership, permissions, volume durability, free-space expectations, and unsupported shared-filesystem deployments.

    - [x] 2.1.2 Task {#jcf-p02-store-server} [repo: jido_code] [after: {#jcf-p02-store-configuration}] - Implement the supervised `JidoCode.Knowledge.StoreServer`.

      This task provides exclusive store-handle ownership and a narrow
      internal execution boundary for validated read and write operations.

      - [x] 2.1.2.1 Subtask {#jcf-p02-2-1-2-1} - Open `TripleStore` in quad mode during initialization and retain the raw handle only in `StoreServer` state.
      - [x] 2.1.2.2 Subtask {#jcf-p02-2-1-2-2} - Verify schema and store metadata before declaring the process ready.
      - [x] 2.1.2.3 Subtask {#jcf-p02-2-1-2-3} - Expose private, typed callbacks for bounded read, atomic update, statistics, checkpoint, backup, export, and integrity operations.
      - [x] 2.1.2.4 Subtask {#jcf-p02-2-1-2-4} - Close the store deterministically on normal shutdown and preserve recoverable diagnostics on abnormal termination.
      - [x] 2.1.2.5 Subtask {#jcf-p02-2-1-2-5} - Reject direct callers outside approved knowledge modules and instrument operation type without logging query or data content.

    - [x] 2.1.3 Task {#jcf-p02-supervision-readiness} [repo: jido_code] [after: {#jcf-p02-store-server}] - Integrate store lifecycle and readiness into application supervision.

      This task ensures mutating surfaces cannot start or report healthy before
      the authoritative dataset is open, verified, and compatible.

      - [x] 2.1.3.1 Subtask {#jcf-p02-2-1-3-1} - Add a `JidoCode.Knowledge.Supervisor` before factory workers and the Phoenix endpoint dependencies that require durable state.
      - [x] 2.1.3.2 Subtask {#jcf-p02-2-1-3-2} - Keep endpoint health degraded and reject durable commands while the store is opening, verifying, recovering, backing up exclusively, or unavailable.
      - [x] 2.1.3.3 Subtask {#jcf-p02-2-1-3-3} - Define restart intensity and fail-stop behavior so repeated store-open failures do not create restart loops or fallback state.
      - [x] 2.1.3.4 Subtask {#jcf-p02-2-1-3-4} - Preserve independent static/error rendering where safe while preventing false application readiness.
      - [x] 2.1.3.5 Subtask {#jcf-p02-2-1-3-5} - Add controlled maintenance mode for restore, integrity repair, and schema migration.

  - [x] 2.2 Section - Implement atomic writes, revisions, and concurrency control.

    This section establishes one durable commit boundary and graph revision
    vocabulary without yet attaching factory-domain semantics.

    - [x] 2.2.1 Task {#jcf-p02-write-coordinator} [repo: jido_code] [after: {#jcf-p02-supervision-readiness}] - Implement the serialized knowledge write coordinator.

      This task gives all future semantic commands one ordering, timeout,
      transaction, and outcome boundary over the embedded store.

      - [x] 2.2.1.1 Subtask {#jcf-p02-2-2-1-1} - Add `JidoCode.Knowledge.Writer` as the only public-internal route to persistent mutation.
      - [x] 2.2.1.2 Subtask {#jcf-p02-2-2-1-2} - Define a backend-neutral write batch containing target graphs, additions, removals allowed by maintenance policy, expected revisions, and opaque operation metadata.
      - [x] 2.2.1.3 Subtask {#jcf-p02-2-2-1-3} - Serialize commits, enforce operation deadlines, and separate caller timeout from authoritative commit outcome.
      - [x] 2.2.1.4 Subtask {#jcf-p02-2-2-1-4} - Return typed receipts with commit identity, affected graphs, prior/new revisions, counts, durability result, and no raw data.
      - [x] 2.2.1.5 Subtask {#jcf-p02-2-2-1-5} - Reject mutation through `StoreServer` read callbacks, SPARQL query APIs, or arbitrary adapter functions.

    - [x] 2.2.2 Task {#jcf-p02-atomic-commit} [repo: jido_code] [after: {#jcf-p02-write-coordinator}] - Implement the selected atomic commit strategy.

      This task guarantees that readers never observe a partially visible
      multi-graph change or a domain mutation detached from its commit status.

      - [x] 2.2.2.1 Subtask {#jcf-p02-2-2-2-1} - Use one backend transaction or atomic SPARQL Update when the Phase 1 proof establishes complete required semantics.
      - [x] 2.2.2.2 Subtask {#jcf-p02-2-2-2-2} - If required, stage changes in a unique change-set graph and expose them only through an atomic committed marker. (Not required: the accepted ground update is one synchronous batch.)
      - [x] 2.2.2.3 Subtask {#jcf-p02-2-2-2-3} - Ensure failed validation, precondition, backend, or sync outcomes leave no reader-visible partial state.
      - [x] 2.2.2.4 Subtask {#jcf-p02-2-2-2-4} - Recover or discard staged, uncommitted change sets deterministically on boot. (No staged state exists under the accepted strategy.)
      - [x] 2.2.2.5 Subtask {#jcf-p02-2-2-2-5} - Define the point after which a lost caller response must be recovered by commit identity rather than retried as a new write.

    - [x] 2.2.3 Task {#jcf-p02-graph-revisions} [repo: jido_code] [after: {#jcf-p02-atomic-commit}] - Implement dataset and named-graph revision control.

      This task supplies monotonic concurrency tokens used by every later
      semantic command, query, cache, lease, and projection.

      - [x] 2.2.3.1 Subtask {#jcf-p02-2-2-3-1} - Define a monotonic dataset commit revision and per-graph revision updated in the same atomic boundary as graph contents.
      - [x] 2.2.3.2 Subtask {#jcf-p02-2-2-3-2} - Accept exact expected revisions and reject stale writes with the current bounded revision receipt.
      - [x] 2.2.3.3 Subtask {#jcf-p02-2-2-3-3} - Prevent wall-clock timestamps, process counters, or PubSub sequence from serving as authoritative revisions.
      - [x] 2.2.3.4 Subtask {#jcf-p02-2-2-3-4} - Define overflow, restore, migration, and clone semantics without allowing revision regression inside one dataset lineage.
      - [x] 2.2.3.5 Subtask {#jcf-p02-2-2-3-5} - Add race tests proving one winner for conflicting expected-revision writes.

  - [x] 2.3 Section - Implement backup, restore, export, and integrity operations.

    This section makes the graph-only source of truth operable and recoverable
    without relying on hidden process snapshots or secondary stores.

    - [x] 2.3.1 Task {#jcf-p02-backup-export} [repo: jido_code] [after: {#jcf-p02-graph-revisions}] - Implement consistent backup and dataset export.

      This task creates verifiable recovery artifacts while preserving named
      graph identity, dataset lineage, and schema metadata.

      - [x] 2.3.1.1 Subtask {#jcf-p02-2-3-1-1} - Create backups from a documented consistency boundary and record dataset revision, schema version, backend version, checksum, size, and creation time.
      - [x] 2.3.1.2 Subtask {#jcf-p02-2-3-1-2} - Export complete datasets as N-Quads or TriG and preserve graph IRIs, datatypes, language tags, and ontology metadata.
      - [x] 2.3.1.3 Subtask {#jcf-p02-2-3-1-3} - Write backup/export files only to trusted configured destinations with restrictive permissions and collision-safe names.
      - [x] 2.3.1.4 Subtask {#jcf-p02-2-3-1-4} - Reject concurrent destructive maintenance and report whether ordinary reads/writes are paused or snapshot-isolated during backup.
      - [x] 2.3.1.5 Subtask {#jcf-p02-2-3-1-5} - Add retention hooks without deleting any backup until a later explicit policy owns retention.

    - [x] 2.3.2 Task {#jcf-p02-restore-recovery} [repo: jido_code] [after: {#jcf-p02-backup-export}] - Implement fail-safe restore and reopen workflows.

      This task restores authority only after a candidate dataset proves
      compatible and complete, while keeping the prior dataset recoverable.

      - [x] 2.3.2.1 Subtask {#jcf-p02-2-3-2-1} - Require maintenance mode, closed active handles, verified source checksums, compatible backend/schema metadata, and explicit target selection.
      - [x] 2.3.2.2 Subtask {#jcf-p02-2-3-2-2} - Restore into a separate validated location before atomically selecting it as the active dataset.
      - [x] 2.3.2.3 Subtask {#jcf-p02-2-3-2-3} - Preserve the previous active dataset until post-restore verification succeeds and document recoverable rollback.
      - [x] 2.3.2.4 Subtask {#jcf-p02-2-3-2-4} - Reopen, run integrity checks, verify revisions and graph counts, and only then clear maintenance mode.
      - [x] 2.3.2.5 Subtask {#jcf-p02-2-3-2-5} - Record restore activity inside the restored dataset without rewriting its asserted domain history.

    - [x] 2.3.3 Task {#jcf-p02-integrity-service} [repo: jido_code] [after: {#jcf-p02-restore-recovery}] - Implement bounded store and graph integrity checks.

      This task distinguishes backend health from semantic validity and
      produces actionable, non-sensitive diagnostics for both.

      - [x] 2.3.3.1 Subtask {#jcf-p02-2-3-3-1} - Verify RocksDB/backend consistency, dictionary/index readability, required store metadata, dataset lineage, revision monotonicity, and committed-change-set closure.
      - [x] 2.3.3.2 Subtask {#jcf-p02-2-3-3-2} - Verify the default graph is empty and every named graph has bounded metadata once graph topology is introduced.
      - [x] 2.3.3.3 Subtask {#jcf-p02-2-3-3-3} - Return stable issue codes, affected graph/commit references, severity, and safe remediation guidance without dumping triples.
      - [x] 2.3.3.4 Subtask {#jcf-p02-2-3-3-4} - Keep repair separate from detection and require explicit maintenance commands for any destructive action.

  - [x] 2.4 Section - Harden operational lifecycle and observability.

    This section makes the store boundary diagnosable under load and failure
    without turning telemetry, health, or admin utilities into alternate
    authorities.

    - [x] 2.4.1 Task {#jcf-p02-health-telemetry} [repo: jido_code] [after: {#jcf-p02-integrity-service}] - Implement store health and low-cardinality telemetry.

      This task exposes enough operational context to distinguish healthy,
      degraded, recovering, maintenance, and unavailable states safely.

      - [x] 2.4.1.1 Subtask {#jcf-p02-2-4-1-1} - Report open state, schema compatibility, last integrity result, dataset revision, backup age, and bounded failure class.
      - [x] 2.4.1.2 Subtask {#jcf-p02-2-4-1-2} - Emit spans for open, verify, read class, write class, commit, backup, restore, export, and integrity operations.
      - [x] 2.4.1.3 Subtask {#jcf-p02-2-4-1-3} - Bound queue time, execution time, result counts, and error labels without graph contents or arbitrary cardinality.
      - [x] 2.4.1.4 Subtask {#jcf-p02-2-4-1-4} - Ensure health and metrics reads cannot acquire a write path or bypass maintenance restrictions.

    - [x] 2.4.2 Task {#jcf-p02-admin-boundary} [repo: jido_code] [after: {#jcf-p02-health-telemetry}] - Implement internal maintenance and diagnostic entry points.

      This task provides intentional operational commands without exposing raw
      backend handles or unsafe defaults to ordinary application code.

      - [x] 2.4.2.1 Subtask {#jcf-p02-2-4-2-1} - Add bounded Mix tasks or internal service calls for health, integrity, backup, export, and verified restore.
      - [x] 2.4.2.2 Subtask {#jcf-p02-2-4-2-2} - Require explicit paths and confirmations for restore or repair and reject broad, unresolved, or active-store destructive targets. (Restore accepts only an exact configured-root artifact identity plus matching confirmation; raw paths and repair are unsupported.)
      - [x] 2.4.2.3 Subtask {#jcf-p02-2-4-2-3} - Keep ad hoc SPARQL and raw quad operations out of ordinary admin commands.
      - [x] 2.4.2.4 Subtask {#jcf-p02-2-4-2-4} - Document startup, shutdown, maintenance, backup, restore, and first-response troubleshooting.

  - [ ] 2.5 Section - Phase 2 Integration Tests.

    This final section proves one authoritative embedded dataset remains
    atomic, recoverable, and diagnosable across concurrency, process death,
    backup, restore, and operational failure.

    - [x] 2.5.1 Task {#jcf-p02-lifecycle-integration} [repo: jido_code] [after: {#jcf-p02-admin-boundary}] - Exercise production store lifecycle and supervision.

      This task verifies real application startup, readiness, shutdown, reopen,
      lock handling, and fail-closed behavior against isolated stores.

      - [x] 2.5.1.1 Subtask {#jcf-p02-2-5-1-1} - Start the application on an empty store, initialize only required substrate metadata, stop cleanly, reopen, and verify identical revisions and contents.
      - [x] 2.5.1.2 Subtask {#jcf-p02-2-5-1-2} - Attempt concurrent store ownership, invalid paths, permission failure, stale locks, incompatible schema, and missing native libraries.
      - [x] 2.5.1.3 Subtask {#jcf-p02-2-5-1-3} - Kill `StoreServer` and the BEAM during write stages and verify supervision never reports an ambiguous commit as absent or healthy prematurely.
      - [x] 2.5.1.4 Subtask {#jcf-p02-2-5-1-4} - Verify durable endpoints fail closed while static/error rendering and safe diagnostics follow the accepted readiness policy.

    - [x] 2.5.2 Task {#jcf-p02-atomicity-recovery-integration} [repo: jido_code] [after: {#jcf-p02-lifecycle-integration}] - Prove commit, revision, backup, and restore semantics under failure.

      This task certifies that graph visibility and recovery remain coherent
      when clients race, responses are lost, and processes die.

      - [x] 2.5.2.1 Subtask {#jcf-p02-2-5-2-1} - Race conflicting expected-revision writes and prove one winner, deterministic stale receipts, and monotonic dataset/graph revisions.
      - [x] 2.5.2.2 Subtask {#jcf-p02-2-5-2-2} - Drop responses before and after commit, recover by commit identity, and prove retries do not create duplicate effects.
      - [x] 2.5.2.3 Subtask {#jcf-p02-2-5-2-3} - Backup under documented read/write conditions, restore to a fresh location, and compare canonical N-Quads plus metadata.
      - [x] 2.5.2.4 Subtask {#jcf-p02-2-5-2-4} - Corrupt or remove controlled fixture components and verify integrity checks, maintenance mode, and rollback remain safe.
      - [x] 2.5.2.5 Subtask {#jcf-p02-2-5-2-5} - Rerun Phase 1 architecture and compatibility gates plus `mix precommit`.

    - [ ] 2.5.3 Task {#jcf-p02-phase-receipt} [repo: jido_code] [after: {#jcf-p02-atomicity-recovery-integration}] - Publish the Phase 2 durable-substrate receipt.

      This task binds G1 to exact backend, schema, durability, commit,
      revision, recovery, and operational evidence before ontology data is
      admitted.

      - [x] 2.5.3.1 Subtask {#jcf-p02-2-5-3-1} - Record dependency locks, store schema, configuration posture, commit strategy, test-store fixture digest, and candidate commit. (The immutable merged candidate remains pending.)
      - [x] 2.5.3.2 Subtask {#jcf-p02-2-5-3-2} - Attach lifecycle, race, crash, backup/restore, integrity, readiness, and architecture-scan results.
      - [x] 2.5.3.3 Subtask {#jcf-p02-2-5-3-3} - Keep G1 blocked if any operation can bypass `Writer`, any partial change can become visible, or restore cannot reproduce the dataset.
      - [ ] 2.5.3.4 Subtask {#jcf-p02-2-5-3-4} - Pin the merged candidate commit before authorizing Phase 3.
