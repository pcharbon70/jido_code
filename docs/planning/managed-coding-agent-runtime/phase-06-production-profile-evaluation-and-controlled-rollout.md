---
id: plan.jido_code_managed_coding_agent_runtime_phase_06
parent_plan: plan.jido_code_managed_coding_agent_runtime
status: planned
intent: feature
---

# Managed Coding Phase 6 - Production Profile, Evaluation, And Controlled Rollout

This phase selects one exact production profile, measures it against a private
representative corpus, and advances it through shadow and human-reviewed pilot
stages. Rollout authority remains independent of the runtime, and every stage
has explicit stop, rollback, and evidence requirements.

Back to plan: [README](./README.md)

- [x] 6 Phase - Qualify and safely roll out one production managed coding profile.

  This phase proves MCG6 by replacing generic capability claims with measured
  behavior for a pinned model, prompt, tools, sandbox, policies, and budgets.

  - [x] 6.1 Section - Pin the production profile and operating envelope.

    This section turns all materially variable runtime choices into one
    reviewable, content-addressed release candidate.

    - [x] 6.1.1 Task {#mcar-p06-profile} [repo: jido_code] [after: {#mcar-p05-phase-receipt}] - Define and validate the initial production runtime profile.

      This task declares exactly what is being evaluated and prevents silent
      provider, policy, tool, or environment drift during rollout.

      - [x] 6.1.1.1 Subtask - Pin provider/model parameters, prompt templates, context policy, tool registry, model/tool adapters, sandbox image, check registry, credential policy, memory mode, and verifier environment by revision and digest.
      - [x] 6.1.1.2 Subtask - Set hard and next-effect limits for time, turns, model calls, tokens, cost, tool calls, output bytes, workspace bytes, changed files, diff size, checks, retries, and clarification rounds.
      - [x] 6.1.1.3 Subtask - Define supported repository/task classes, languages, dependency policies, network modes, actor requirements, exclusion rules, and declared unavailable capabilities.
      - [x] 6.1.1.4 Subtask - Add startup/admission compatibility checks that reject missing, mismatched, expired, unknown, or unapproved profile components without fallback.
      - [x] 6.1.1.5 Subtask - Define a signed/profile-digested change-control process that forces reevaluation when any material component or limit changes.

  - [x] 6.2 Section - Build the private evaluation program.

    This section measures useful coding performance alongside authority,
    reliability, isolation, and cost rather than optimizing for patch success
    alone.

    - [x] 6.2.1 Task {#mcar-p06-evaluation} [repo: jido_code] [after: {#mcar-p06-profile}] - Implement the managed coding evaluation harness and corpus.

      This task creates reproducible offline evidence for the exact production
      profile against tasks that resemble intended use.

      - [x] 6.2.1.1 Subtask - Assemble a versioned private corpus spanning inspect, defect repair, focused feature, test repair, refactor, documentation, abstention, clarification, policy refusal, and unsupported-task cases.
      - [x] 6.2.1.2 Subtask - Include representative repository sizes, languages, dependency shapes, ambiguous requests, malicious instructions, flaky checks, failures, cancellations, and recovery points without leaking evaluation answers into prompts.
      - [x] 6.2.1.3 Subtask - Implement isolated repeatable runs with exact seeds/parameters, base revisions, clean workspaces, artifact capture, independent verification, and blinded human review where judgment is required.
      - [x] 6.2.1.4 Subtask - Score task correctness, regression rate, unsafe action rate, authority violations, unsupported success claims, abstention quality, recovery, latency, resource use, token use, and cost with confidence intervals.
      - [x] 6.2.1.5 Subtask - Define blocking thresholds, comparison baselines, sample sizes, variance rules, regression tolerances, and mandatory failure analysis before viewing release results.

  - [x] 6.3 Section - Run a non-authoritative shadow rollout.

    This section observes the production profile on real eligible tasks while
    preventing its candidates and decisions from affecting repositories or
    existing delivery outcomes.

    - [x] 6.3.1 Task {#mcar-p06-shadow} [repo: jido_code] [after: {#mcar-p06-evaluation}] - Implement and operate shadow-mode qualification.

      This task tests production traffic, infrastructure, and operational
      assumptions with zero publication authority.

      - [x] 6.3.1.1 Subtask - Sample explicitly eligible tasks under tenant/repository policy and create shadow attempts that cannot push branches, open pull requests, alter primary task state, or influence the active implementation.
      - [x] 6.3.1.2 Subtask - Apply production data classification, credentials, rate limits, isolation, retention, redaction, and cost accounting even though outputs are non-authoritative.
      - [x] 6.3.1.3 Subtask - Compare shadow candidates and dispositions to observed human/production outcomes using delayed blinded scoring and no feedback into the same attempt.
      - [x] 6.3.1.4 Subtask - Monitor failure distribution, abstention, clarification demand, capacity, cost, latency, recovery, security events, and cohort-specific regressions over a declared observation window.
      - [x] 6.3.1.5 Subtask - Automatically stop shadow admission on threshold breach, evidence gaps, profile drift, isolation failure, unexplained cost growth, or inability to reconstruct results.

  - [x] 6.4 Section - Run a human-reviewed draft-PR pilot.

    This section introduces useful repository output only after shadow evidence
    passes, with narrow eligibility and mandatory human review and merge.

    - [x] 6.4.1 Task {#mcar-p06-pilot} [repo: jido_code] [after: {#mcar-p06-shadow}] - Implement and operate the controlled production pilot.

      This task exercises the real publication boundary without transferring
      approval or merge authority to the coding runtime.

      - [x] 6.4.1.1 Subtask - Restrict enrollment by explicit tenant/repository allowlist, supported task class, profile digest, volume ceiling, business hours/on-call coverage, and documented opt-out.
      - [x] 6.4.1.2 Subtask - Permit only authorized draft branch/pull-request creation from an accepted candidate and attach exact provenance, verification, limitations, and human-review requirements.
      - [x] 6.4.1.3 Subtask - Require a human to review, modify if needed, approve, and merge through existing repository protections; record outcomes without attributing human changes to the candidate.
      - [x] 6.4.1.4 Subtask - Measure acceptance, edit distance, review time, escaped regression, reopen/revert, unsafe behavior, abstention, latency, cost, and operator burden by eligible cohort.
      - [x] 6.4.1.5 Subtask - Stop new pilot work and quarantine pending publication when any safety, quality, provenance, isolation, cost, or operational threshold is crossed.

  - [x] 6.5 Section - Establish production operations and release decisions.

    This section gives accountable operators the evidence and controls needed to
    continue, pause, roll back, or reject the profile.

    - [x] 6.5.1 Task {#mcar-p06-operations} [repo: jido_code] [after: {#mcar-p06-pilot}] - Implement rollout governance, incident response, and profile disablement.

      This task makes production status an explicit authorized decision backed
      by evaluation and pilot evidence.

      - [x] 6.5.1.1 Subtask - Define accountable owners, approvers, on-call roles, dashboards, alert routes, review cadence, escalation paths, and evidence retention for the managed coding service.
      - [x] 6.5.1.2 Subtask - Implement global, tenant, repository, provider, adapter, tool, and profile disable controls that block new effects promptly and preserve recoverable state.
      - [x] 6.5.1.3 Subtask - Document incident triage, cancellation/drain, credential revocation, evidence preservation, tenant notification, candidate quarantine, rollback, and safe reenable procedures.
      - [x] 6.5.1.4 Subtask - Require an independent release decision to accept, extend, restrict, or reject the profile based on predeclared thresholds and unresolved findings.
      - [x] 6.5.1.5 Subtask - Publish the supported operating envelope and keep automatic approval, automatic merge, and general multi-agent topology outside this phase's authorization.

  - [x] 6.6 Section - Phase 6 Integration Tests.

    This final section validates the pinned profile, evaluation harness, shadow
    path, pilot publication controls, and emergency operations as one release
    system.

    - [x] 6.6.1 Task {#mcar-p06-integration} [repo: jido_code] [after: {#mcar-p06-operations}] - Execute the production qualification and rollout matrix.

      This task closes MCG6 only when the exact profile meets its thresholds and
      can be stopped safely without losing evidence or granting excess authority.

      - [x] 6.6.1.1 Subtask - Reproduce the evaluation corpus from clean environments, rerun statistical/regression analysis, and prove material profile drift invalidates prior qualification.
      - [x] 6.6.1.2 Subtask - Exercise shadow non-interference, pilot eligibility, draft publication, human merge enforcement, threshold stops, disable controls, drain, incident, rollback, and reenable drills.
      - [x] 6.6.1.3 Subtask - Audit representative attempts from task admission to human outcome and reconcile every profile, effect, candidate, verification, publication, and operator decision.
      - [x] 6.6.1.4 Subtask - Rerun MCG1-MCG5, complete evaluation/shadow/pilot/operations suites, architecture checks, Dialyzer, and `mix precommit`.

    - [x] 6.6.2 Task {#mcar-p06-phase-receipt} [repo: jido_code] [after: {#mcar-p06-integration}] - Publish and pin the Phase 6 receipt.

      This task records MCG6 evidence in
      `docs/architecture/managed-coding-phase-06-receipt.md` and authorizes
      Phase 7 only from the pinned merged baseline.

      - [x] 6.6.2.1 Subtask - Record exact profile, corpus, harness, thresholds, shadow window, pilot cohort, publication, operational control, and release-decision revisions and digests.
      - [x] 6.6.2.2 Subtask - Attach aggregate and cohort metrics, confidence/variance analysis, failure reviews, drift checks, disable/incident drills, and unresolved limitations.
      - [x] 6.6.2.3 Subtask - Keep MCG6 open if thresholds fail, profile identity is incomplete, shadow affects live work, human merge can be bypassed, or emergency controls are unproven.
      - [x] 6.6.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 7 and preserve every MCG1-MCG6 reopening condition.
