---
id: plan.jido_code_total_agent_memory_phase_01
parent_plan: plan.jido_code_total_agent_memory
status: planned
intent: feature
---

# Memory Phase 1 - Memory Contract, Topology, And Policy

This phase resolves contradictions between current storage and accepted privacy
language, ratifies the observable-memory boundary, and makes every future graph
family, content class, retention state, compatibility rule, and capacity gate
explicit before new capture begins.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Ratify complete evidence and selective memory as executable architecture.

  This phase establishes MG1 by ensuring the ontology, data policy, topology,
  retention, security, and legacy-migration contracts agree about every byte
  JidoCode stores or omits.

  - [x] 1.1 Section - Reconcile current durable content and total-memory scope.

    This section inventories existing execution content and defines the exact
    boundary of observable, authorized memory.

    - [x] 1.1.1 Task {#tam-p01-contract-reconciliation} [repo: jido_code] - Accept the total-memory boundary and reconcile existing content classifications.

      This task replaces ambiguous prose with one authoritative classification
      and capture contract.

      - [x] 1.1.1.1 Subtask - Inventory persisted `Instruction.content`, interaction messages, model outcomes, tool stdout/stderr, embedded artifacts, command-receipt commitments, exports, and backup derivatives.
      - [x] 1.1.1.2 Subtask - Decide and document when an instruction is a prompt representation, when tool output is raw or normalized, and where each authorized representation may reside.
      - [x] 1.1.1.3 Subtask - Define total memory as complete accounting of eligible observable events, explicitly excluding secret values, provider-private state, hidden reasoning, and unavailable events.
      - [x] 1.1.1.4 Subtask - Require every expected body to record a capture result even when content is omitted, unavailable, redacted, failed, expired, or erased.
      - [x] 1.1.1.5 Subtask - Tag legacy runs with their actual protocol and reconstruction limits without rewriting closed history or claiming nonexistent completeness.

  - [x] 1.2 Section - Ratify memory graph families, resources, and writers.

    This section extends the closed topology with narrowly scoped families
    whose lifecycle cannot grant control, evidence, decision, or knowledge
    authority.

    - [x] 1.2.1 Task {#tam-p01-memory-topology} [repo: jido_code] [after: {#tam-p01-contract-reconciliation}] - Publish the memory ontology and graph-topology contract.

      This task assigns every new resource an exact graph family, writer,
      scope, lifecycle, retention class, and permitted link direction.

      - [x] 1.2.1.1 Subtask - Add `run_event_segment` scoped by attempt and segment, writable only by `execution_writer`, closeable once, and immutable after closure.
      - [x] 1.2.1.2 Subtask - Add repository-scoped `experience` and `content_lifecycle` families with dedicated writers and append/supersede lifecycles.
      - [x] 1.2.1.3 Subtask - Register `episode_content` as a disabled, content-writer-only family for bounded encrypted chunks, unavailable until MG6.
      - [x] 1.2.1.4 Subtask - Define shapes for capture manifests, segment manifests, content captures, cases, procedures, artifact claims, retrieval activities, lifecycle activities, and access permits.
      - [x] 1.2.1.5 Subtask - Version graph identities, predicates, writer capabilities, allowed links, completeness, topology, and migration compatibility; unknown families and terms remain denied.

  - [ ] 1.3 Section - Define capture, retention, archive, and erasure policy.

    This section makes content representation, availability, retention, hold,
    and deletion independent dimensions governed by purpose and classification.

    - [ ] 1.3.1 Task {#tam-p01-content-policy} [repo: jido_code] [after: {#tam-p01-memory-topology}] - Implement the shared memory data-policy contract.

      This task ensures semantic accounting does not silently authorize broader
      retention or reuse.

      - [ ] 1.3.1.1 Subtask - Define `semantic_history`, `diagnostic_capture`, `project_total_history`, and `incident_hold`; register only `semantic_history` as enabled.
      - [ ] 1.3.1.2 Subtask - Extend `Security.DataPolicy` for every accepted graph family, representation, output sink, export, provider-egress rule, and Personal-data restriction.
      - [ ] 1.3.1.3 Subtask - Model capture outcome, representation, storage location, availability tier, retention/erasure state, and hold state as orthogonal closed vocabularies.
      - [ ] 1.3.1.4 Subtask - Define `archive` as queryable cold retention and distinguish it from removal, expiry, cryptographic erasure, physical deletion, and unverifiable external deletion.
      - [ ] 1.3.1.5 Subtask - Keep immutable semantic shells longer than payloads and prohibit selective mutation of closed run graphs.
      - [ ] 1.3.1.6 Subtask - Forbid new plaintext-sensitive receipt commitments; require ciphertext commitments or protected keyed commitments where equality is an accepted purpose.

  - [ ] 1.4 Section - Define compatibility, threat, and capacity gates.

    This section provides the migration and adversarial rules that every later
    phase inherits.

    - [ ] 1.4.1 Task {#tam-p01-memory-guardrails} [repo: jido_code] [after: {#tam-p01-content-policy}] - Publish migration, security, and benchmark guardrails.

      This task prevents the new protocol from weakening accepted run closure,
      authorization, privacy, or store bounds.

      - [ ] 1.4.1.1 Subtask - Require open legacy attempts to close or become governed abandoned attempts before segmented execution is activated; preserve dual-read projections for closed legacy runs.
      - [ ] 1.4.1.2 Subtask - Add threats for persistent poisoning, delayed prompt injection, cross-scope retrieval, stale procedures, false causality, context overload, secret capture, and incomplete erasure.
      - [ ] 1.4.1.3 Subtask - Require authorization before candidate generation and bind index partitions to repository/tenant, actor scope, purpose, data ceiling, effective-time generation, and erasure generation.
      - [ ] 1.4.1.4 Subtask - Pin segment and payload capacity profiles below the existing 10,000-quad snapshot, 1,000-addition, 100-guard, 16-target-graph, and command-payload ceilings with reserved closure headroom.
      - [ ] 1.4.1.5 Subtask - Define the Phase 6 benchmark corpus and relative capture, query, backup, restore, and rebuild acceptance thresholds that determine graph-native versus vault storage.
      - [ ] 1.4.1.6 Subtask - Keep every new writer, query, profile, index, and content gateway disabled until its owning phase gate is accepted.

  - [ ] 1.5 Section - Phase 1 Integration Tests.

    This final section proves the reconciled contract is internally consistent
    and closes MG1 from a merged candidate.

    - [ ] 1.5.1 Task {#tam-p01-integration} [repo: jido_code] [after: {#tam-p01-memory-guardrails}] - Execute the memory-contract conformance suite.

      This task validates topology, policy, compatibility, retention, and
      threat fixtures against the real dataset.

      - [ ] 1.5.1.1 Subtask - Prove every current durable literal is classified consistently across ontology, `DataPolicy`, command validation, projections, exports, retention, and backup.
      - [ ] 1.5.1.2 Subtask - Prove each new family accepts only its writer, scope, predicates, lifecycle transitions, and allowed link directions.
      - [ ] 1.5.1.3 Subtask - Prove secret values, hidden reasoning, unauthorized prompts, unknown profiles, and cross-scope content cannot enter durable graphs.
      - [ ] 1.5.1.4 Subtask - Prove archive, removal, erasure, hold, legacy-run, and receipt-commitment states are reported honestly.
      - [ ] 1.5.1.5 Subtask - Run prior graph/harness suites, architecture scans, and `mix precommit`.

    - [ ] 1.5.2 Task {#tam-p01-phase-receipt} [repo: jido_code] [after: {#tam-p01-integration}] - Publish the Phase 1 memory-contract receipt.

      This task records the ratified boundary in
      `docs/architecture/memory-phase-01-receipt.md` and authorizes segmented
      accounting only from the pinned merged baseline.

      - [ ] 1.5.2.1 Subtask - Record ontology, registry, policy, profile, capacity, migration, and threat revisions plus the candidate commit.
      - [ ] 1.5.2.2 Subtask - Attach classification, topology, retention, compatibility, and adversarial evidence with known limitations.
      - [ ] 1.5.2.3 Subtask - Keep MG1 blocked if any stored content is ambiguously classified, any family lacks a closed contract, or any retained content can become authority.
      - [ ] 1.5.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 2.
