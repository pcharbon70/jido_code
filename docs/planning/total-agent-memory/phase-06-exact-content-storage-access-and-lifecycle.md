---
id: plan.jido_code_total_agent_memory_phase_06
parent_plan: plan.jido_code_total_agent_memory
status: planned
intent: feature
---

# Memory Phase 6 - Exact Content Storage, Access, And Lifecycle

This phase benchmarks bounded encrypted graph content, implements single-use
content access and complete lifecycle accounting, and permits a vault only
through the predeclared benchmark and ADR decision.

Back to plan: [README](./README.md)

- [ ] 6 Phase - Make exact retained content recoverable, encrypted, purpose-bound, and erasable without creating another authority.

  This phase establishes MG6 while leaving high-retention capture profiles
  disabled by default.

  - [x] 6.1 Section - Implement and benchmark graph-native encrypted content.

    This section stores bounded authorized payloads in immutable content
    segments under the sole-store contract.

    - [x] 6.1.1 Task {#tam-p06-graph-content} [repo: jido_code] [after: {#tam-p05-phase-receipt}] - Implement `episode_content` chunking and capacity benchmarks.

      This task tests the preferred graph-first design before any vault
      decision.

      - [x] 6.1.1.1 Subtask - Use opaque semantic content IRIs and encrypt authorized sensitive bytes before semantic command construction.
      - [x] 6.1.1.2 Subtask - Store ordered bounded ciphertext chunks with homogeneous initial policy, media type, byte count, ciphertext digest, key reference, source event, and completeness root.
      - [x] 6.1.1.3 Subtask - Prohibit plaintext secrets, public plaintext hashes of sensitive content, authority-bearing predicates, and ordinary product projection.
      - [x] 6.1.1.4 Subtask - Close each content segment atomically and reject missing, duplicate, reordered, oversized, mixed-policy, or orphaned chunks.
      - [x] 6.1.1.5 Subtask - Benchmark the Phase 1 corpus across capture, retrieval, backup, restore, retention, erasure, index rebuild, and storage growth.
      - [x] 6.1.1.6 Subtask - Produce a signed benchmark decision against every pinned acceptance threshold.

  - [x] 6.2 Section - Implement encryption and single-use content access.

    This section makes decryption and release a separately authorized,
    consumed, and reported effect.

    - [x] 6.2.1 Task {#tam-p06-content-access} [repo: jido_code] [after: {#tam-p06-graph-content}] - Implement the content cipher, gateway, and permit protocol.

      This task ensures exact content is never released merely because
      retrieval found it.

      - [x] 6.2.1.1 Subtask - Define a key-provider-backed envelope-encryption port with per-tenant/per-object keys, rotation, revocation, and cryptographic erasure.
      - [x] 6.2.1.2 Subtask - Add `AuthorizeContentAccess` binding actor, purpose, task/scope, reviewed query, parameters, content version, representation, byte range, sink, destination, method, expiry, and data ceiling.
      - [x] 6.2.1.3 Subtask - For agent context, additionally bind attempt, lease, fence, context/model invocation, and model-access profile.
      - [x] 6.2.1.4 Subtask - Add `ConsumeContentAccess` with immediate rechecks of current authorization, revocation, lifecycle, hold policy, version, sink, destination, and single-use state.
      - [x] 6.2.1.5 Subtask - Release only the committed representation and range, then record released, denied, unavailable, failed, or ambiguous outcome and bounded byte count.
      - [x] 6.2.1.6 Subtask - Treat a crash after permit consumption as attributable ambiguous access; audit stores commitments and selected IRIs, never released bytes.

  - [x] 6.3 Section - Implement content lifecycle, hold, and erasure.

    This section tracks later availability and deletion without mutating
    immutable event or payload graphs.

    - [x] 6.3.1 Task {#tam-p06-content-lifecycle} [repo: jido_code] [after: {#tam-p06-content-access}] - Implement lifecycle activities and derivative cleanup.

      This task prevents erased or unavailable content from being retrieved,
      restored, or misreported.

      - [x] 6.3.1.1 Subtask - Append active, cold, unavailable, provider-lost, expired-pending, erase-requested, crypto-erased, physically-deleted, externally-attested, and externally-unverifiable transitions.
      - [x] 6.3.1.2 Subtask - Implement case-specific place, review, and release hold commands with owner, approver, scope, purpose, affected objects, access policy, and review date.
      - [x] 6.3.1.3 Subtask - Block retrieval first, then inventory and remove bodies, lexical/dense indexes, summaries, cases, procedures, datasets, caches, exports, queued jobs, replicas, provider objects, and backup-restorable keys.
      - [x] 6.3.1.4 Subtask - Preserve only lawful non-sensitive shells and non-reversible tombstones; never claim unverifiable external deletion as erasure.
      - [x] 6.3.1.5 Subtask - Extend restore floors and backup manifests so erased content and keys cannot be reintroduced.
      - [x] 6.3.1.6 Subtask - Rebuild or invalidate every derived projection whose lineage includes removed content.

  - [ ] 6.4 Section - Resolve the storage decision and keep capture profiles gated.

    This section deterministically selects graph-native content or a governed
    vault and records why broader capture remains disabled.

    - [ ] 6.4.1 Task {#tam-p06-storage-decision} [repo: jido_code] [after: {#tam-p06-content-lifecycle}] - Apply the benchmark decision and finalize profile posture.

      This task prevents convenience or storage pressure from creating an
      undeclared second source of truth.

      - [ ] 6.4.1.1 Subtask - If every graph-native threshold passes, accept graph content and record that no vault is authorized.
      - [ ] 6.4.1.2 Subtask - If any mandatory threshold fails, keep exact-content enablement blocked until a superseding ADR for an application-owned encrypted vault is accepted.
      - [ ] 6.4.1.3 Subtask - Under the vault branch, implement inaccessible pending writes, graph activation, immutable ciphertext versions, orphan cleanup, backup consistency, content-gateway-only access, and graph-authoritative lifecycle.
      - [ ] 6.4.1.4 Subtask - Prove either accepted branch satisfies identical authorization, encryption, integrity, retention, erasure, and recovery contracts before MG6 can close.
      - [ ] 6.4.1.5 Subtask - Keep `diagnostic_capture` and `project_total_history` unregistered and runtime-disabled; future enablement requires a separate accepted policy/profile and evidence decision.
      - [ ] 6.4.1.6 Subtask - Keep provider-owned governed artifacts available for eligible external content without treating a JidoCode-controlled bucket as external authority.

  - [ ] 6.5 Section - Phase 6 Integration Tests.

    This final section proves exact-content storage and release under realistic
    volume, adversarial input, failure, backup, and erasure.

    - [ ] 6.5.1 Task {#tam-p06-integration} [repo: jido_code] [after: {#tam-p06-storage-decision}] - Execute the exact-content and lifecycle matrix.

      This task validates the accepted real storage branch; mocks cannot close
      MG6.

      - [ ] 6.5.1.1 Subtask - Capture, encrypt, chunk, close, retrieve, rotate, cold-tier, hold, expire, erase, and restore realistic prompts, logs, outputs, and artifacts.
      - [ ] 6.5.1.2 Subtask - Exercise concurrent permit use, expiry, revocation, stale fence, wrong profile, wrong range, wrong sink, wrong destination, crash ambiguity, and replay.
      - [ ] 6.5.1.3 Subtask - Prove zero secret-value capture under canary/entropy/provider classifiers and zero cross-scope plaintext or embedding leakage.
      - [ ] 6.5.1.4 Subtask - Verify deletion propagation across primary storage, indexes, cases, procedures, exports, backups, and restoration attempts.
      - [ ] 6.5.1.5 Subtask - Rerun the accepted benchmark and publish reproducible capacity, latency, backup, restore, and rebuild evidence.
      - [ ] 6.5.1.6 Subtask - Rerun prior suites, architecture scans, and `mix precommit`.

    - [ ] 6.5.2 Task {#tam-p06-phase-receipt} [repo: jido_code] [after: {#tam-p06-integration}] - Publish the Phase 6 exact-content receipt.

      This task records the accepted storage branch in
      `docs/architecture/memory-phase-06-receipt.md` and binds MG6 to the
      merged candidate.

      - [ ] 6.5.2.1 Subtask - Record storage decision, ADR if applicable, graph/vault/cipher/key/gateway/profile revisions, benchmark digest, and candidate commit.
      - [ ] 6.5.2.2 Subtask - Attach encryption, permit, lifecycle, erasure, restore, adversarial, and capacity evidence.
      - [ ] 6.5.2.3 Subtask - Keep MG6 blocked if exact content can bypass a consumed permit, erasure can resurrect data, or a second store gains semantic authority.
      - [ ] 6.5.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 7.
