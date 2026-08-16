---
id: plan.jido_code_m01_phase_04_backup_restore_export_health_and_receipt
parent_plan: plan.jido_code_m01_knowledge_kernel
status: planned
intent: feature
---

# M01 JidoCode Phase 4 - Backup, Restore, Export, Health, And Receipt

This phase makes the sole durable dataset operable and recoverable through
consistent backup, verified restore, canonical export, bounded integrity and
health surfaces, and closes the milestone with its receipt.

Back to plan: [M01 README](./README.md)

- [ ] 4 Phase - Make the authoritative dataset recoverable and diagnosable.

  This phase proves the graph-only source of truth survives operational
  failure without any secondary store or hidden snapshot format.

  - [ ] 4.1 Section - Implement consistent backup and dataset export.

    This section creates verifiable recovery artifacts that preserve named
    graph identity and dataset lineage.

    - [ ] 4.1.1 Task {#m01-jc-p04-backup-export} [repo: jido_code] [after: {#m01-jc-p03-integration}] - Implement backup and export operations.

      This task guarantees every recovery artifact is checksummed,
      self-describing, and written only to trusted destinations.

      - [ ] 4.1.1.1 Subtask {#m01-jc-4-1-1-1} - Create backups from a documented consistency boundary recording dataset revision, schema version, backend version, checksum, size, and creation time.
      - [ ] 4.1.1.2 Subtask {#m01-jc-4-1-1-2} - Export complete datasets as canonical N-Quads or TriG preserving graph IRIs, datatypes, language tags, and ontology metadata.
      - [ ] 4.1.1.3 Subtask {#m01-jc-4-1-1-3} - Write artifacts only to configured trusted destinations with restrictive permissions and collision-safe names.
      - [ ] 4.1.1.4 Subtask {#m01-jc-4-1-1-4} - Reject concurrent destructive maintenance during backup and document whether reads and writes are paused or snapshot-isolated.
      - [ ] 4.1.1.5 Subtask {#m01-jc-4-1-1-5} - Add retention hooks without deleting any artifact until a later explicit policy owns retention.

  - [ ] 4.2 Section - Implement fail-safe restore and reopen.

    This section restores authority only after a candidate dataset proves
    compatible and complete, keeping the prior dataset recoverable.

    - [ ] 4.2.1 Task {#m01-jc-p04-restore-recovery} [repo: jido_code] [after: {#m01-jc-p04-backup-export}] - Implement staged restore and atomic dataset selection.

      This task never lets a corrupt or incompatible candidate become the
      active authority.

      - [ ] 4.2.1.1 Subtask {#m01-jc-4-2-1-1} - Require maintenance mode, closed active handles, verified source checksums, and compatible backend/schema metadata before restore begins.
      - [ ] 4.2.1.2 Subtask {#m01-jc-4-2-1-2} - Restore into a separate validated location, then atomically select it as the active dataset.
      - [ ] 4.2.1.3 Subtask {#m01-jc-4-2-1-3} - Preserve the previous active dataset until post-restore verification succeeds and document recoverable rollback.
      - [ ] 4.2.1.4 Subtask {#m01-jc-4-2-1-4} - Reopen, run integrity checks, verify revisions and graph counts, and only then clear maintenance mode.
      - [ ] 4.2.1.5 Subtask {#m01-jc-4-2-1-5} - Record restore activity inside the restored dataset without rewriting its asserted history.

  - [ ] 4.3 Section - Implement integrity, health, and the admin boundary.

    This section distinguishes backend health from semantic validity and
    exposes intentional operations without raw handles.

    - [ ] 4.3.1 Task {#m01-jc-p04-integrity-service} [repo: jido_code] [after: {#m01-jc-p04-restore-recovery}] - Implement bounded store and graph integrity checks.

      This task produces actionable, non-sensitive diagnostics and keeps
      repair separate from detection.

      - [ ] 4.3.1.1 Subtask {#m01-jc-4-3-1-1} - Verify backend consistency, dictionary/index readability, store metadata, dataset lineage, revision monotonicity, empty default graph, and bounded named-graph metadata.
      - [ ] 4.3.1.2 Subtask {#m01-jc-4-3-1-2} - Return stable issue codes, affected graph or commit references, severity, and safe remediation guidance without dumping triples.
      - [ ] 4.3.1.3 Subtask {#m01-jc-4-3-1-3} - Require explicit maintenance commands for any destructive repair action.

    - [ ] 4.3.2 Task {#m01-jc-p04-health-telemetry} [repo: jido_code] [after: {#m01-jc-p04-integrity-service}] - Implement health, telemetry, and admin entry points.

      This task exposes operational state with bounded cardinality and keeps
      diagnostics from becoming an authority path.

      - [ ] 4.3.2.1 Subtask {#m01-jc-4-3-2-1} - Report open state, schema compatibility, last integrity result, dataset revision, backup age, and bounded failure class.
      - [ ] 4.3.2.2 Subtask {#m01-jc-4-3-2-2} - Emit spans for open, verify, read class, write class, commit, backup, restore, export, and integrity with bounded queue time, duration, counts, and error labels.
      - [ ] 4.3.2.3 Subtask {#m01-jc-4-3-2-3} - Ensure health and metric reads cannot acquire a write path or bypass maintenance restrictions.
      - [ ] 4.3.2.4 Subtask {#m01-jc-4-3-2-4} - Add bounded Mix tasks for health, integrity, backup, export, and verified restore requiring explicit artifact identity and confirmation.

  - [ ] 4.4 Section - Phase 4 Integration Tests.

    This final section proves recoverability end to end and closes the
    Knowledge Kernel milestone.

    - [ ] 4.4.1 Task {#m01-jc-p04-integration} [repo: jido_code] [after: {#m01-jc-p04-health-telemetry}] - Exercise backup, restore, corruption, and readiness end to end.

      This task certifies the dataset can be reconstructed from its own
      artifacts under failure.

      - [ ] 4.4.1.1 Subtask {#m01-jc-4-4-1-1} - Backup under documented read/write conditions, restore to a fresh location, and compare canonical N-Quads plus metadata for equivalence.
      - [ ] 4.4.1.2 Subtask {#m01-jc-4-4-1-2} - Corrupt or remove controlled fixture components and verify integrity detection, maintenance mode, and rollback safety.
      - [ ] 4.4.1.3 Subtask {#m01-jc-4-4-1-3} - Verify fail-closed readiness through store death, maintenance, and restore windows, including static and error rendering policy.
      - [ ] 4.4.1.4 Subtask {#m01-jc-4-4-1-4} - Rerun Phase 1 through Phase 3 suites plus `mix precommit`, dependency audits, and production asset build.

    - [ ] 4.4.2 Task {#m01-jc-p04-milestone-receipt} [repo: jido_code] [after: {#m01-jc-p04-integration}] - Publish the M01 Knowledge Kernel receipt.

      This task binds the milestone to exact evidence and authorizes the
      Milestone 2 ontology and semantic-command plan.

      - [ ] 4.4.2.1 Subtask {#m01-jc-4-4-2-1} - Record dependency locks, store schema, commit strategy, revision semantics, fixture digests, and the merged candidate commit.
      - [ ] 4.4.2.2 Subtask {#m01-jc-4-4-2-2} - Attach lifecycle, race, crash, backup/restore, integrity, readiness, and architecture-scan results.
      - [ ] 4.4.2.3 Subtask {#m01-jc-4-4-2-3} - Keep the milestone blocked if any mutation can bypass `Writer`, any partial change can become visible, or restore cannot reproduce the dataset.
