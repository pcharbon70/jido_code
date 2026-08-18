---
id: plan.jido_code_total_agent_memory_phase_05
parent_plan: plan.jido_code_total_agent_memory
status: planned
intent: feature
---

# Memory Phase 5 - Artifact Claims And Procedural Memory

This phase ties claims to exact source and verification artifacts, invalidates
them on drift, and derives reusable procedures only through multiple cases and
independent validation.

Back to plan: [README](./README.md)

- [ ] 5 Phase - Build fresh artifact claims and validated procedures without compiling historical advice into policy automatically.

  This phase establishes MG5 by separating evidence strength, freshness,
  procedural usefulness, accepted knowledge, and executable control.

  - [ ] 5.1 Section - Implement artifact-grounded claims and freshness.

    This section binds behavior claims to exact content and lets later changes
    make them stale without erasing history.

    - [ ] 5.1.1 Task {#tam-p05-artifact-claims} [repo: jido_code] [after: {#tam-p04-phase-receipt}] - Implement `ArtifactClaim` and freshness transitions.

      This task makes historical verification precise about source,
      environment, evidence, and time.

      - [ ] 5.1.1.1 Subtask - Bind claim, repository/revision, artifact, path/symbol/selector, content digest, verification command/environment, evidence reference/strength, and valid/checked times.
      - [ ] 5.1.1.2 Subtask - Record claims only through evidence-writer commands and prohibit claim creation from runtime success alone.
      - [ ] 5.1.1.3 Subtask - Append fresh, stale, contradicted, invalidated, and superseded states when source hashes, symbols, tools, environments, or evidence change.
      - [ ] 5.1.1.4 Subtask - Add `artifact_claims` and `historical_test_risk` queries with exact current-revision comparison.
      - [ ] 5.1.1.5 Subtask - Exclude stale claims from current retrieval while preserving historical visibility and original evidence strength.

  - [ ] 5.2 Section - Define and induce candidate procedures.

    This section models reusable workflows with explicit applicability,
    branches, evidence, failure modes, and lifecycle.

    - [ ] 5.2.1 Task {#tam-p05-procedure-contract} [repo: jido_code] [after: {#tam-p05-artifact-claims}] - Implement `ProcedureRevision` proposal and quarantine.

      This task prevents one successful patch or plausible summary from
      becoming a reusable workflow.

      - [ ] 5.2.1.1 Subtask - Bind purpose, task class, triggers, applicability, repository/language/framework/version scope, ordered semantic steps, required tools/capabilities, and expected observations.
      - [ ] 5.2.1.2 Subtask - Bind decision branches, stop/escalation/rollback conditions, exceptions, supporting and contradicting cases, delayed outcomes, and last validation.
      - [ ] 5.2.1.3 Subtask - Define candidate, validated, stale, invalidated, and superseded states with immutable revisions.
      - [ ] 5.2.1.4 Subtask - Require multiple applicable cases or explicit expert review; success count alone never promotes a procedure.
      - [ ] 5.2.1.5 Subtask - Quarantine secrets, prompt injection, over-generalization, missing preconditions, duplicate procedures, and benchmark leakage.

  - [ ] 5.3 Section - Validate procedures and preserve authority boundaries.

    This section converts candidate guidance into measured procedural memory
    while keeping accepted propositions and executable policy separate.

    - [ ] 5.3.1 Task {#tam-p05-procedure-validation} [repo: jido_code] [after: {#tam-p05-procedure-contract}] - Implement independent procedure validation and lifecycle.

      This task requires current execution evidence before a procedure becomes
      validated.

      - [ ] 5.3.1.1 Subtask - Validate procedures through independent executions under exact applicability, environment, tool, policy, and source revisions.
      - [ ] 5.3.1.2 Subtask - Track success, failure, revert, incident, negative-transfer, and delayed-survival counts by applicability class.
      - [ ] 5.3.1.3 Subtask - Mark procedures stale when framework, dependency, tool, policy, environment, or artifact preconditions drift.
      - [ ] 5.3.1.4 Subtask - Permit `AdoptKnowledge` to accept precise propositions about a procedure only through existing evidence and decision contracts.
      - [ ] 5.3.1.5 Subtask - Require a separate sanitized policy representation and authorized policy command before any procedure becomes executable control.

  - [ ] 5.4 Section - Retrieve procedures by task phase and evidence.

    This section gives the harness a few compatible workflows while recording
    their use and current-world validation.

    - [ ] 5.4.1 Task {#tam-p05-procedure-retrieval} [repo: jido_code] [after: {#tam-p05-procedure-validation}] - Implement phase-aware procedure products.

      This task prevents stale or inapplicable procedures from dominating
      investigation, editing, migration, verification, or recovery.

      - [ ] 5.4.1.1 Subtask - Add `procedures_for_task`, `procedure_evidence`, procedure contradiction, lifecycle, and use-outcome queries.
      - [ ] 5.4.1.2 Subtask - Match investigation, localization, editing, migration, testing, verification, recovery, and incident phases separately.
      - [ ] 5.4.1.3 Subtask - Require exact framework/version/tool/policy/environment compatibility and current evidence before selection.
      - [ ] 5.4.1.4 Subtask - Return stop conditions, exceptions, failure history, freshness, and evidence alongside ordered steps.
      - [ ] 5.4.1.5 Subtask - Record every use as a new observation and wait for independent assessment before updating lifecycle or ranking.

  - [ ] 5.5 Section - Phase 5 Integration Tests.

    This final section proves artifact drift and procedural lifecycle preserve
    evidence and control separation.

    - [ ] 5.5.1 Task {#tam-p05-integration} [repo: jido_code] [after: {#tam-p05-procedure-retrieval}] - Execute the artifact-and-procedure integration matrix.

      This task validates claims and workflows across source change,
      independent execution, negative transfer, and policy boundaries.

      - [ ] 5.5.1.1 Subtask - Create strong and weak artifact claims, change their supporting content, and prove exact freshness invalidation.
      - [ ] 5.5.1.2 Subtask - Induce procedures from mixed success/failure/revert cases and reject one-off or unsupported generalization.
      - [ ] 5.5.1.3 Subtask - Validate, retrieve, use, fail, stale, invalidate, and supersede procedures under exact applicability.
      - [ ] 5.5.1.4 Subtask - Attempt to turn a candidate procedure directly into accepted knowledge, capability, approval, or policy and prove denial.
      - [ ] 5.5.1.5 Subtask - Measure history-aware test selection, applicability abstention, and negative transfer against fixed baselines.
      - [ ] 5.5.1.6 Subtask - Rerun prior suites, architecture scans, and `mix precommit`.

    - [ ] 5.5.2 Task {#tam-p05-phase-receipt} [repo: jido_code] [after: {#tam-p05-integration}] - Publish the Phase 5 artifact-and-procedure receipt.

      This task records claim and procedure evidence in
      `docs/architecture/memory-phase-05-receipt.md` and binds MG5 to the
      merged candidate.

      - [ ] 5.5.2.1 Subtask - Record claim, procedure, command, query, applicability, validation, and policy revisions.
      - [ ] 5.5.2.2 Subtask - Attach drift, lifecycle, retrieval, negative-transfer, and policy-boundary evidence.
      - [ ] 5.5.2.3 Subtask - Keep MG5 blocked if stale claims remain current, procedures lack independent evidence, or guidance can become control automatically.
      - [ ] 5.5.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 6.
