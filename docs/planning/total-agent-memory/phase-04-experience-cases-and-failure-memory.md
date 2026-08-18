---
id: plan.jido_code_total_agent_memory_phase_04
parent_plan: plan.jido_code_total_agent_memory
status: planned
intent: feature
---

# Memory Phase 4 - Experience Cases And Failure Memory

This phase packages exact attempt and delayed-outcome lineage into challengeable
success, failure, revert, flake, infrastructure, abandoned, and ambiguous
cases.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Turn governed history into source-linked cases without promoting one trajectory into truth.

  This phase establishes MG4 by adding applicability-filtered case retrieval
  and independent measurement of benefit or harm.

  - [ ] 4.1 Section - Define experience-case contracts and lifecycle.

    This section gives reusable episodes a closed non-authoritative schema and
    append-only state machine.

    - [ ] 4.1.1 Task {#tam-p04-case-contract} [repo: jido_code] [after: {#tam-p03-phase-receipt}] - Implement `ExperienceCase` and its governed lifecycle.

      This task preserves reusable episode structure without hiding raw
      lineage.

      - [ ] 4.1.1.1 Subtask - Bind problem signature, repository/version, environment, dependencies, symptoms, reproduction, inspected files/symbols, interventions, and disproved assumptions.
      - [ ] 4.1.1.2 Subtask - Bind terminal intervention, verification, delayed outcome, exceptions, limitations, and exact source event/artifact/evidence references.
      - [ ] 4.1.1.3 Subtask - Distinguish success, failure, revert, flake, infrastructure, abandonment, and ambiguous cases.
      - [ ] 4.1.1.4 Subtask - Define candidate, validated, stale, invalidated, and superseded transitions in the `experience` family.
      - [ ] 4.1.1.5 Subtask - Ensure case status never satisfies work, accepts evidence, adopts knowledge, or compiles policy.

  - [ ] 4.2 Section - Construct and quarantine cases.

    This section combines deterministic extraction with bounded model proposals
    while treating both source content and generated summaries as untrusted.

    - [ ] 4.2.1 Task {#tam-p04-case-construction} [repo: jido_code] [after: {#tam-p04-case-contract}] - Implement case proposal, validation, and quarantine commands.

      This task prevents poisoning, leakage, and unsupported generalization
      during consolidation.

      - [ ] 4.2.1.1 Subtask - Build deterministic failure signatures and case skeletons from closed runs plus exact time-bounded later evidence.
      - [ ] 4.2.1.2 Subtask - Store model-generated summaries as `CandidateFactOrSummary` in `experience`, never as reasoner output or accepted knowledge.
      - [ ] 4.2.1.3 Subtask - Quarantine embedded instructions, secrets, personal data, cross-scope references, unsupported claims, future leakage, suspicious triggers, and missing evidence.
      - [ ] 4.2.1.4 Subtask - Require an independent actor and exact source/effective-time manifest before validation.
      - [ ] 4.2.1.5 Subtask - Preserve contradictory and failed cases instead of consolidating only successful trajectories.

  - [ ] 4.3 Section - Retrieve similar cases and failed interventions.

    This section adds narrow case-based products with strict applicability and
    chronological eligibility.

    - [ ] 4.3.1 Task {#tam-p04-case-retrieval} [repo: jido_code] [after: {#tam-p04-case-construction}] - Implement case retrieval and failure-memory products.

      This task supplies a few strong precedents instead of flooding context
      with trajectories.

      - [ ] 4.3.1.1 Subtask - Add `similar_resolved_cases`, `failed_interventions`, case source-trace, contradiction, and lifecycle queries.
      - [ ] 4.3.1.2 Subtask - Filter by repository, framework, version, environment, dependency, task class, plan phase, effective time, and current applicability.
      - [ ] 4.3.1.3 Subtask - Keep lexical, graph, failure-signature, and optional dense scores separate until deterministic reranking.
      - [ ] 4.3.1.4 Subtask - Enforce a small configurable case count and diversity across success, failure, and ambiguity.
      - [ ] 4.3.1.5 Subtask - Evaluate localization, repeated-action avoidance, retry recovery, and abstention when no applicable case exists.

  - [ ] 4.4 Section - Measure case utility and negative transfer.

    This section evaluates memory influence independently after attempts close
    and feeds harmful outcomes into lifecycle and ranking.

    - [ ] 4.4.1 Task {#tam-p04-memory-use-assessment} [repo: jido_code] [after: {#tam-p04-case-retrieval}] - Implement independent `MemoryUseAssessment`.

      This task prevents frequency or model self-report from becoming evidence
      of usefulness.

      - [ ] 4.4.1.1 Subtask - Record useful, neutral, misleading, stale, unauthorized, and causally-indeterminate outcomes from independent evidence.
      - [ ] 4.4.1.2 Subtask - Bind the exact retrieval packet, attempt, outcome, evaluator, policy, graph revisions, and matched withheld-memory control.
      - [ ] 4.4.1.3 Subtask - Add `memory_use_outcomes` and negative-transfer queries without modifying the original case.
      - [ ] 4.4.1.4 Subtask - Demote or transition repeatedly harmful cases through governed lifecycle commands.
      - [ ] 4.4.1.5 Subtask - Detect suspicious trigger concentration and memory-poisoning success as immediate disablement signals.

  - [ ] 4.5 Section - Phase 4 Integration Tests.

    This final section proves case construction, quarantine, retrieval,
    assessment, and invalidation against complete attempt lineage.

    - [ ] 4.5.1 Task {#tam-p04-integration} [repo: jido_code] [after: {#tam-p04-memory-use-assessment}] - Execute the experience-case integration matrix.

      This task validates cases as useful but non-authoritative memory.

      - [ ] 4.5.1.1 Subtask - Construct and retrieve success, failure, revert, flake, infrastructure, abandonment, and ambiguous cases.
      - [ ] 4.5.1.2 Subtask - Reject unsupported summaries, injected instructions, cross-scope cases, future outcomes, missing lineage, and forged validation.
      - [ ] 4.5.1.3 Subtask - Compare case retrieval with no-memory and ordinary lexical baselines under fixed models and budgets.
      - [ ] 4.5.1.4 Subtask - Record useful and harmful assessments, then prove ranking/lifecycle changes preserve original history.
      - [ ] 4.5.1.5 Subtask - Exercise replay, concurrent lifecycle transitions, invalidation, supersession, restart, and index rebuild.
      - [ ] 4.5.1.6 Subtask - Rerun prior suites, architecture scans, and `mix precommit`.

    - [ ] 4.5.2 Task {#tam-p04-phase-receipt} [repo: jido_code] [after: {#tam-p04-integration}] - Publish the Phase 4 experience-memory receipt.

      This task records case and assessment evidence in
      `docs/architecture/memory-phase-04-receipt.md` and binds MG4 to the
      merged candidate.

      - [ ] 4.5.2.1 Subtask - Record case schema, command, query, ranker, quarantine, evaluator, and corpus revisions.
      - [ ] 4.5.2.2 Subtask - Attach case-class, leakage, poisoning, retrieval, negative-transfer, and lifecycle evidence.
      - [ ] 4.5.2.3 Subtask - Keep MG4 blocked if a case can hide lineage, cross scope, use future evidence, or gain authority from frequency.
      - [ ] 4.5.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 5.
