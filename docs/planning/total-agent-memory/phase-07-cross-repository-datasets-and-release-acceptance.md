---
id: plan.jido_code_total_agent_memory_phase_07
parent_plan: plan.jido_code_total_agent_memory
status: planned
intent: feature
---

# Memory Phase 7 - Cross-Repository Datasets And Release Acceptance

This phase permits explicitly authorized cross-repository cohort analysis and
leakage-controlled dataset production. Model training, checkpoint production,
deployment, and automatic broad cross-repository access remain outside this
plan.

Back to plan: [README](./README.md)

- [x] 7 Phase - Produce governed cross-repository evidence and datasets without broadening memory authority or leaking future data.

  This phase satisfies MG7 by proving that cohort analysis, dataset
  construction, export, evaluation, revocation, and erasure remain
  purpose-bound and temporally valid, then closes the total-agent-memory plan
  from a pinned merged candidate.

  - [x] 7.1 Section - Define cross-repository purpose and authorization.

    This section makes every cohort operation an explicit, expiring
    authorization decision rather than an emergent consequence of repository
    access.

    - [x] 7.1.1 Task {#tam-p07-cross-repository-policy} [repo: jido_code] [after: {#tam-p06-phase-receipt}] - Implement the cross-repository authorization policy.

      This task defines the policy boundary and durable evidence required
      before any query, analysis, candidate generation, or export may span
      repositories.

      - [x] 7.1.1.1 Subtask - Require an explicit cohort, repository set, actor set, purpose, allowed uses, data classes, effective cutoff, expiry, policy revision, and authorization decision.
      - [x] 7.1.1.2 Subtask - Partition candidate generation and indexes by authorization scope and erasure generation so an unauthorized repository cannot influence retrieval or aggregate counts.
      - [x] 7.1.1.3 Subtask - Treat cross-repository cases and procedures as candidates only; require independent acceptance in the target repository before they gain local authority.
      - [x] 7.1.1.4 Subtask - Deny exact content, prompt-derived content, personal data, and confidential content unless each class is expressly covered by the authorization.
      - [x] 7.1.1.5 Subtask - Audit every cross-repository query, export, omission, denial, revocation, and expiry without copying protected payloads into the audit record.

  - [x] 7.2 Section - Build chronological governed datasets.

    This section produces reproducible evaluation datasets whose examples
    contain only information available at their declared historical cutoff.

    - [x] 7.2.1 Task {#tam-p07-dataset-construction} [repo: jido_code] [after: {#tam-p07-cross-repository-policy}] - Implement governed dataset construction.

      This task materializes dataset manifests and rows with source-complete
      lineage, temporal correctness, leakage controls, and removable
      derivatives.

      - [x] 7.2.1.1 Subtask - Define `MemoryDatasetManifest` with purpose, authorization, source graphs, source resources, cutoff, classifications, extractor revision, query revision, split policy, erasure generation, and exact-content states.
      - [x] 7.2.1.2 Subtask - Construct examples chronologically, excluding eventual patches, later reviews, delayed incident findings, post-cutoff outcomes, and any other future evidence.
      - [x] 7.2.1.3 Subtask - Split at repository level and deduplicate by repository, task, patch, incident, and semantic overlap so related examples cannot cross evaluation boundaries.
      - [x] 7.2.1.4 Subtask - Balance successful changes, failures, reverts, flakes, infrastructure incidents, and ambiguous outcomes without relabeling uncertainty as success or failure.
      - [x] 7.2.1.5 Subtask - Exclude secrets, personal data, provider-private fields, hidden reasoning, unresolved deletion requests, and payloads outside the manifest's allowed classifications.
      - [x] 7.2.1.6 Subtask - Give every dataset row exact source lineage and an identity that allows all derived copies to be found, invalidated, and removed.

  - [x] 7.3 Section - Export datasets while keeping model training separate.

    This section governs dataset movement as a distinct lifecycle and makes
    clear that an approved dataset is not authorization to train or deploy a
    model.

    - [x] 7.3.1 Task {#tam-p07-dataset-export} [repo: jido_code] [after: {#tam-p07-dataset-construction}] - Implement dataset export permits and lineage.

      This task exports only verified manifests to approved sinks while
      preserving revocation, invalidation, hold, and erasure obligations.

      - [x] 7.3.1.1 Subtask - Require an export permit naming the approved sink, exact manifest, row and byte limits, classifications, purpose, and expiry.
      - [x] 7.3.1.2 Subtask - Store dataset identity, digest, schema, row counts, source lineage, authorization, and availability state in the graph without making the graph a second payload store.
      - [x] 7.3.1.3 Subtask - Verify chronology, split isolation, deduplication, source completeness, class balance, and absence of forbidden content before release.
      - [x] 7.3.1.4 Subtask - Propagate erasure, hold, revocation, and source invalidation into dataset status and require deletion or quarantine of affected external copies.
      - [x] 7.3.1.5 Subtask - Limit this phase to evaluation and governed dataset exports; do not create fine-tuning jobs, checkpoints, model-registry records, or deployments.
      - [x] 7.3.1.6 Subtask - Require any future training effort to reference a pinned manifest and obtain its own implementation plan, evidence gates, and lifecycle controls.

  - [x] 7.4 Section - Run the memory evaluation and release program.

    This section demonstrates useful memory behavior against controlled
    baselines while measuring negative transfer, leakage, stale authority, and
    operational cost.

    - [x] 7.4.1 Task {#tam-p07-evaluation-release} [repo: jido_code] [after: {#tam-p07-dataset-export}] - Implement release evaluation and acceptance criteria.

      This task evaluates memory products through reproducible ablations and
      requires both positive utility and zero-tolerance governance outcomes
      before release.

      - [x] 7.4.1.1 Subtask - Run ablations for no memory, recent history, all eligible history, summaries, lexical retrieval, dense retrieval, graph retrieval, cases, procedures, hybrid retrieval, oracle retrieval, and stale or poisoned memory.
      - [x] 7.4.1.2 Subtask - Measure retrieval precision, recall, ranking quality, source completeness, authorization-denial correctness, invalidation latency, and retrieval cost.
      - [x] 7.4.1.3 Subtask - Measure task success, time to accepted patch, review burden, regression rate, recovery quality, token cost, and operator intervention.
      - [x] 7.4.1.4 Subtask - Measure negative transfer, procedure misuse, invalidation misses, hallucinated memory, poisoned-memory uptake, scope leakage, erasure misses, and temporal leakage.
      - [x] 7.4.1.5 Subtask - Require zero cross-scope leaks, secret leaks, accounting drift, missing sources, temporal violations, permit bypasses, stale-claim acceptance, erasure failures, and future-patch leakage.
      - [x] 7.4.1.6 Subtask - Require statistically supported benefit for at least one launch memory product, no critical false acceptance, and an immediate disable path for each launched product.

  - [x] 7.5 Section - Phase 7 Integration Tests.

    This final section exercises the full governed-memory and dataset path
    across authorization, time, lifecycle, export, restoration, and release
    acceptance boundaries.

    - [x] 7.5.1 Task {#tam-p07-integration} [repo: jido_code] [after: {#tam-p07-evaluation-release}] - Run Phase 7 integration, leakage, lifecycle, and release tests.

      This task proves MG7 and all earlier gates against realistic
      multi-repository workflows, adversarial dataset inputs, and lifecycle
      transitions.

      - [x] 7.5.1.1 Subtask - Test multi-repository, multi-tenant, and multi-actor preauthorization so denied repositories remain concealed from candidates, rankings, aggregates, logs, and exports.
      - [x] 7.5.1.2 Subtask - Inject overlap, future evidence, secrets, personal data, provider-private fields, poisoned memory, stale claims, deleted sources, and ambiguous outcomes into dataset candidates and prove exclusion or quarantine.
      - [x] 7.5.1.3 Subtask - Trace a complete authorized attempt from graph capture through history, case, claim, procedure, exact-content access, dataset construction, export permit, evaluation, and revocation.
      - [x] 7.5.1.4 Subtask - Exercise rebuild, restart, backup restore, key rotation, hold, expiry, deletion, and dataset invalidation without creating a second authority or orphaned derivative.
      - [x] 7.5.1.5 Subtask - Prove diagnostic and project profiles, adapter-specific memory, broad cohort access, automatic export, model training, and deployment remain disabled by default.
      - [x] 7.5.1.6 Subtask - Run the full memory evaluation suite, all prior phase integration suites, architecture checks, and `mix precommit` from a clean checkout.

    - [x] 7.5.2 Task {#tam-p07-phase-receipt} [repo: jido_code] [after: {#tam-p07-integration}] - Publish and pin the Phase 7 receipt.

      This task records the final governed-memory evidence and closes the plan
      only after the implementation pull request passes clean-checkout CI and
      merges.

      - [x] 7.5.2.1 Subtask - Create `docs/architecture/memory-phase-07-receipt.md` with all contract, policy, query, extractor, dataset, export, and evaluation revisions.
      - [x] 7.5.2.2 Subtask - Attach authorization-isolation, temporal-leakage, lifecycle, erasure, export, evaluation, and clean-checkout evidence.
      - [x] 7.5.2.3 Subtask - Keep MG7 open if any unauthorized influence, future evidence, forbidden content, lineage gap, lifecycle failure, critical false acceptance, or required metric failure remains.
      - [x] 7.5.2.4 Subtask - Pin the merged candidate commit, close the total-agent-memory plan, and preserve every MG1-MG7 reopening condition.
