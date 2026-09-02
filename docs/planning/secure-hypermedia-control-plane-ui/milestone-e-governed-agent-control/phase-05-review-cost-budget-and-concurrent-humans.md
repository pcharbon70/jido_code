---
id: plan.jido_code_hypermedia_ui_milestone_e_phase_05
parent_plan: plan.jido_code_hypermedia_ui_milestone_e
status: proposed
intent: feature
---

# Milestone E Phase 5 - Review, Cost, Budget, And Concurrent Humans

This phase adds evidence-based review, separation of duty, cost/budget
oversight, wiki-generation accounting, and deterministic concurrent-human behavior.

Back to plan: [README](./README.md)

- [ ] 5 Phase - Deliver governed review, accounting, and multi-human coordination.

  This phase closes HUI-E5 by making approvals action-bound and costs
  attributable while ensuring racing humans/tabs converge through domain CAS.

  - [ ] 5.1 Section - Implement review and evidence decision workspaces.

    This section gives eligible reviewers separately authorized evidence and
    prevents self-approval or stale decisions.

    - [ ] 5.1.1 Task {#huie-p05-review} [repo: jido_code] [after: {#huie-p04-phase-receipt}] - Implement review queue, candidate evidence, and decision previews.

      This task preserves candidate, verifier evidence, decision, publication,
      application, and satisfaction as distinct resources/states.

      - [ ] 5.1.1.1 Subtask - Query bounded review queue/detail with candidate/source revision, claimed changes, independent verification, artifacts/effects, policy, risk, reviewer eligibility, and decision state.
      - [ ] 5.1.1.2 Subtask - Enforce maker/checker, self-approval prohibition, exact project/resource/graph grants, assurance, quorum, evidence availability, and field-level redaction.
      - [ ] 5.1.1.3 Subtask - Generate canonical action-bound decision previews/digests with current candidate/evidence/policy revisions, reason, expiry, and invalidation.
      - [ ] 5.1.1.4 Subtask - Render native/enhanced decisions only for accepted gateways and show durable receipts plus subsequent publication/application/re-observation separately.

  - [ ] 5.2 Section - Implement cost, budget, and wiki-token oversight.

    This section makes estimates, reservations, measured usage, final charges,
    budgets, and outcomes visible without treating browser totals as authority.

    - [ ] 5.2.1 Task {#huie-p05-cost} [repo: jido_code] [after: {#huie-p05-review}] - Implement authorized cost and budget projections.

      This task supports attempt, interaction, provider/model, repository, wiki,
      and accepted-outcome analysis with explicit provenance and completeness.

      - [ ] 5.2.1.1 Subtask - Query token input/output/cache/tool/total, provider/model/profile, reservation, measured/final/estimated status, price revision, currency, cost, budget, threshold, and attribution.
      - [ ] 5.2.1.2 Subtask - Correlate costs with attempt/interactions, artifacts/effects, accepted outcomes, external application, satisfaction, and repository wiki editions without implying causation absent evidence.
      - [ ] 5.2.1.3 Subtask - Render wiki enrollment/opt-out/effective policy, deterministic zero-token evidence, synthesis reservation/usage/terminal accounting, maintainer trigger, budget, cancellation, and late-result disposition.
      - [ ] 5.2.1.4 Subtask - Enforce cost-observer and field/tenant/project scopes, completeness/late-data labels, bounded aggregation/export, privacy, and no cross-provider/user leakage.

  - [ ] 5.3 Section - Qualify concurrent humans, tabs, and separation of duty.

    This section proves all racing decisions resolve through current graph
    state, command preconditions, idempotency, and receipts.

    - [ ] 5.3.1 Task {#huie-p05-concurrency} [repo: jido_code] [after: {#huie-p05-cost}] - Implement and test concurrent action/decision coordination.

      This task gives winners and losers deterministic safe outcomes and never
      falls back to browser last-write-wins.

      - [ ] 5.3.1.1 Subtask - Define conflict matrices for identical duplicate, compatible sequential, mutually exclusive, stale preview, stale fence/lease, cancel-versus-answer/steer/handoff/retry, and competing decisions.
      - [ ] 5.3.1.2 Subtask - Return canonical existing receipt for exact idempotent duplicates and current state/conflict receipt for losing transitions without leaking the winner's protected fields.
      - [ ] 5.3.1.3 Subtask - Revalidate reviewer eligibility/quorum/SoD, role/delegation/assurance, candidate/evidence/policy revisions, and session generation at decision commit.
      - [ ] 5.3.1.4 Subtask - Converge several tabs/users after races, transport loss, revocation, late receipts, and stream gaps; announce current safe state accessibly.

  - [ ] 5.4 Section - Phase 5 Integration Tests.

    This final section proves review, accounting, opt-out, and concurrent-human
    behavior remain exact, auditable, isolated, and accessible.

    - [ ] 5.4.1 Task {#huie-p05-integration} [repo: jido_code] [after: {#huie-p05-concurrency}] - Execute the HUI-E5 review, cost, and concurrency matrix.

      This task uses real decision/gateway/accounting/wiki seams and multiple
      authorized and unauthorized human sessions.

      - [ ] 5.4.1.1 Subtask - Exercise review eligibility, self-approval, quorum, stale evidence/candidate/policy, step-up, decision conflicts, receipts, publication/application/re-observation, and satisfaction distinctions.
      - [ ] 5.4.1.2 Subtask - Exercise complete/partial/late/estimated/final token and cost data, price/currency revision, reservations/budgets/thresholds, wiki opt-out/zero-token/synthesis-disabled/cancellation/late-result accounting.
      - [ ] 5.4.1.3 Subtask - Race two or more humans and several tabs across every conflict class, duplicate/retry/transport-loss/revocation case, and verify one authoritative transition plus safe loser outcomes.
      - [ ] 5.4.1.4 Subtask - Run real-store/gateway/wiki/browser/security/accessibility/concurrency suites, `mix precommit`, and clean-checkout CI.

    - [ ] 5.4.2 Task {#huie-p05-phase-receipt} [repo: jido_code] [after: {#huie-p05-integration}] - Publish and pin the Phase 5 receipt.

      This task records HUI-E5 evidence in
      `docs/architecture/hypermedia-ui-milestone-e-phase-05-receipt.md`.

      - [ ] 5.4.2.1 Subtask - Keep HUI-E5 merge-pending on stale/self approval, SoD bypass, cost misstatement/leak, wiki opt-out/token-accounting failure, last-writer-wins race, ambiguous receipt, or non-convergent tabs.
      - [ ] 5.4.2.2 Subtask - Record review/cost/wiki/concurrency fixtures and evidence, failures, limitations, and all reopening conditions.
      - [ ] 5.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 5 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 6.
