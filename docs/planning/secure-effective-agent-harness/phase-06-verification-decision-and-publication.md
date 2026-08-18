---
id: plan.jido_code_secure_effective_agent_harness_phase_06
parent_plan: plan.jido_code_secure_effective_agent_harness
status: planned
intent: feature
---

# Harness Phase 6 - Verification, Decision, And Publication

This phase separates candidate production from acceptance: independent
fresh-checkout verification, digest-bound single-use human approval,
governed decisions, and publication as separate leased work, ending in the
later final-goal decision.

Back to plan: [README](./README.md)

- [ ] 6 Phase - Convert candidates into governed outcomes without executor self-acceptance.

  This phase proves runtime success alone can never satisfy a goal and
  every external effect carries independent authority.

  - [x] 6.1 Section - Bind verification admission to closed runs.

    This section makes run completeness a precondition of evidence rather
    than an assumption.

    - [x] 6.1.1 Task {#sah-p06-verification-admission} [repo: jido_code] [after: {#sah-p05-phase-receipt}] - Admit verification only from exact closed runs.

      This task freezes the immutable input every verifier works from.

      - [x] 6.1.1.1 Subtask {#sah-p06-6-1-1-1} - Require a committed `FinalizeExecutionRun` receipt for the exact attempt before any verification activity.
      - [x] 6.1.1.2 Subtask {#sah-p06-6-1-1-2} - Bind the verifier's immutable inputs: closed run graph IRI and revision, completeness state and accepted reference sets through the terminal sequence, attempt, lease, and fence identity, exact source and control graph revisions, base commit and snapshot digest, candidate artifact and patch digests with media type and byte count, verification environment digest, policy and rubric revisions, and independently authorized evaluator identity and capability.
      - [x] 6.1.1.3 Subtask {#sah-p06-6-1-1-3} - Let an incomplete closed run yield only unavailable or inconclusive assessments unless policy explicitly names the missing classes; it can never support accepting evidence as though provenance were complete.

  - [x] 6.2 Section - Implement the independent fresh-checkout verifier.

    This section reconstructs candidates from first principles and emits
    evidence, never acceptance.

    - [x] 6.2.1 Task {#sah-p06-verifier} [repo: jido_code] [after: {#sah-p06-verification-admission}] - Implement fresh-checkout verification.

      This task detects hidden executor state, overfit patches, and
      candidate-authored test bypass.

      - [x] 6.2.1.1 Subtask {#sah-p06-6-2-1-1} - Create a fresh checkout at the exact base commit, apply the complete candidate patch including new and binary artifacts, and confirm no executor-only state is required.
      - [x] 6.2.1.2 Subtask {#sah-p06-6-2-1-2} - Enforce changed-path, patch-size, and capability policy and reject unauthorized changes to verification, policy, or protected workflow configuration.
      - [x] 6.2.1.3 Subtask {#sah-p06-6-2-1-3} - Run formatting, compilation, static analysis, type checks, and repository regression tests, plus verifier-owned issue tests, hidden tests, and security checks where applicable, repeating unstable tests only under a fixed flake policy.
      - [x] 6.2.1.4 Subtask {#sah-p06-6-2-1-4} - Accept candidate-authored tests as evidence only when proven to fail on base, pass with the candidate, express a stated requirement, and not replace independent checks.
      - [x] 6.2.1.5 Subtask {#sah-p06-6-2-1-5} - Record exact environment, command, result, output, and workspace digests, and emit structured evidence and findings through the accepted evidence commands, never an acceptance mutation.

  - [x] 6.3 Section - Implement digest-bound single-use approval.

    This section makes human review resistant to substitution, replay, and
    time-of-check races.

    - [x] 6.3.1 Task {#sah-p06-approval} [repo: jido_code] [after: {#sah-p06-verifier}] - Implement high-risk approval requests.

      This task binds each approval to an immutable action digest and one
      authenticated consumable act.

      - [x] 6.3.1.1 Subtask {#sah-p06-6-3-1-1} - Create `ApprovalRequest` resources binding an immutable digest of exact action and normalized arguments, patch and base revision, tool, model, sandbox, policy, and context versions, capability and fencing token, external destination and egressed data, evidence set, reversibility, and approval expiry.
      - [x] 6.3.1.2 Subtask {#sah-p06-6-3-1-2} - Bind the authenticated approver, delegated scope, and single-use approval identity, and require an approver distinct from the execution actor whenever accepted policy demands separation.
      - [x] 6.3.1.3 Subtask {#sah-p06-6-3-1-3} - Immediately before the approved effect, recheck approver authorization, revocation, policy, current revisions, capability, lease, fence, destination, and artifact availability; the invocation-before-effect command atomically records the invocation and consumes the approval.
      - [x] 6.3.1.4 Subtask {#sah-p06-6-3-1-4} - Leave an ambiguous delivery unresolved with bounded reconciliation observations; permit redelivery only under a proven idempotent contract with no terminal outcome, commit exactly one terminal outcome, and require a new invocation, linked attempt, and approval for any semantic retry.

  - [ ] 6.4 Section - Implement publication as separate work.

    This section ensures acceptance justifies proposing publication but never
    performs it.

    - [ ] 6.4.1 Task {#sah-p06-publication} [repo: jido_code] [after: {#sah-p06-approval}] - Implement the publication task and trusted adapter.

      This task keeps branch protection, review, and rapid revocation in
      the loop at launch.

      - [ ] 6.4.1.1 Subtask {#sah-p06-6-4-1-1} - Model opening or updating a bot branch or pull request as a new task with independent eligibility, authorization, lease, fence, and execution attempt recorded in `run/{publication_attempt}`.
      - [ ] 6.4.1.2 Subtask {#sah-p06-6-4-1-2} - Implement the trusted provider adapter with expected-old-object compare-and-swap, non-fast-forward rejection, and reliance on provider branch and ruleset protection, claiming narrower Git credential scope only where the provider demonstrably supports it.
      - [ ] 6.4.1.3 Subtask {#sah-p06-6-4-1-3} - Keep all publication limited to bot branches and pull requests with no protected-branch merge authority.

  - [ ] 6.5 Section - Implement external observation and the final-goal decision.

    This section closes the loop from published change to governed goal
    outcome.

    - [ ] 6.5.1 Task {#sah-p06-final-goal} [repo: jido_code] [after: {#sah-p06-publication}] - Observe external state and decide goal outcomes.

      This task makes goal satisfaction an observed, evidenced, decided
      fact rather than an execution claim.

      - [ ] 6.5.1.1 Subtask {#sah-p06-6-5-1-1} - Observe the resulting external state after publication through the accepted observation commands, linking provider events back to the publication attempt.
      - [ ] 6.5.1.2 Subtask {#sah-p06-6-5-1-2} - Run post-change verification against the observed external revision and feed the resulting evidence to the decision service.
      - [ ] 6.5.1.3 Subtask {#sah-p06-6-5-1-3} - Record the later `FinalGoal` decision under the accepted decision contract with actor separation, evidence references, and dispositions (accept, reject, defer, waive, supersede, or request more evidence).

  - [ ] 6.6 Section - Phase 6 Integration Tests.

    This final section proves authority separation across the whole
    candidate-to-outcome chain.

    - [ ] 6.6.1 Task {#sah-p06-integration} [repo: jido_code] [after: {#sah-p06-final-goal}] - Execute the verification, approval, and publication matrices.

      This task certifies governed outcomes before any rollout stage beyond
      shadow is considered.

      - [ ] 6.6.1.1 Subtask {#sah-p06-6-6-1-1} - Prove verification refuses open or incomplete runs, reproduces accepted candidates from fresh checkouts, and emits evidence that cannot mutate acceptance state.
      - [ ] 6.6.1.2 Subtask {#sah-p06-6-6-1-2} - Prove approvals fail on digest mismatch, replay, expiry, approver revocation, and missing actor separation, and that consumption is atomic with the recorded invocation.
      - [ ] 6.6.1.3 Subtask {#sah-p06-6-6-1-3} - Prove publication runs as a separate attempt with its own lease and fence, CAS rejects stale branches, and no path merges into protected branches.
      - [ ] 6.6.1.4 Subtask {#sah-p06-6-6-1-4} - Prove goal satisfaction requires external observation, post-change verification, and a governed decision; executor success alone never satisfies a goal. Rerun prior suites, architecture scans, and `mix precommit`.

    - [ ] 6.6.2 Task {#sah-p06-phase-receipt} [repo: jido_code] [after: {#sah-p06-integration}] - Publish the Phase 6 verification-decision receipt.

      This task records the outcome evidence in
      `docs/architecture/harness-phase-06-receipt.md` and authorizes Phase 7
      only from the pinned merged baseline.

      - [ ] 6.6.2.1 Subtask {#sah-p06-6-6-2-1} - Record verifier, approval, publication, and decision contract revisions plus the candidate commit.
      - [ ] 6.6.2.2 Subtask {#sah-p06-6-6-2-2} - Attach fresh-checkout reproduction, approval attack, publication CAS, and final-goal results with known limitations.
      - [ ] 6.6.2.3 Subtask {#sah-p06-6-6-2-3} - Keep HG6 blocked while any executor can verify itself, any approval can be replayed, or any outcome can bypass the decision service.
      - [ ] 6.6.2.4 Subtask {#sah-p06-6-6-2-4} - Pin the merged candidate commit before authorizing Phase 7.
