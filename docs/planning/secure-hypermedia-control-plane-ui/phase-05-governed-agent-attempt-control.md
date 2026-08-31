---
id: plan.jido_code_secure_hypermedia_control_plane_ui_phase_05
parent_plan: plan.jido_code_secure_hypermedia_control_plane_ui
status: proposed
intent: feature
---

# Secure Hypermedia Control Plane UI Phase 5 — Governed Agent Attempt Control

This phase implements Milestone E and closes HUI5 by turning the qualified
read-only attempt projection into a durable human oversight workspace. It adds
only commands already admitted by accepted domain contracts and keeps command
authority, revisions, approvals, effects, costs, and receipts on the server.

Back to plan: [README](./README.md)

- [ ] 5 Phase — Deliver governed attempt oversight and admitted controls.

  This phase lets authorized humans understand and influence parallel attempts
  without inventing browser-side workflow state or unsupported lifecycle verbs.

  - [ ] 5.1 Section — Compose the durable attempt workspace and causal timeline.

    This section correlates accepted attempt, interaction, artifact, evidence,
    policy, cost, and receipt projections while preserving their distinct identities.

    - [ ] 5.1.1 Task {#hui-p05-workspace} [repo: jido_code] [after: {#hui-p04-phase-receipt}] — Implement the attempt oversight workspace.

      This task renders one comprehensible workspace for an attempt without
      conflating it with an `InteractionSession`, browser session, provider thread,
      candidate, runtime process, or repository.

      - [ ] 5.1.1.1 Subtask — Render the trust header, repository/attempt identity, lifecycle and outcome rails, freshness, authorization scope, owner, runtime, branch/worktree, and budget posture.
      - [ ] 5.1.1.2 Subtask — Compose plan, interactions, artifacts, effects, verification, decisions, handoffs, receipts, wiki activity, and costs from public bounded projections.
      - [ ] 5.1.1.3 Subtask — Preserve causal IDs, timestamps, actor type, source revisions, provenance, redaction, unavailable/stale/truncated states, and links to separately authorized detail.
      - [ ] 5.1.1.4 Subtask — Provide keyboard, screen-reader, responsive, reduced-motion, and paused-visual-update behavior without suggesting the agent itself is paused.

    - [ ] 5.1.2 Task {#hui-p05-timeline} [repo: jido_code] [after: {#hui-p05-workspace}] — Implement normalized causal timeline projections.

      This task makes parallel and retried activity understandable while retaining
      the authoritative ordering and semantic distinctions recorded in the graphs.

      - [ ] 5.1.2.1 Subtask — Define deterministic ordering, grouping, correlation, pagination, truncation, retry/supersession, and concurrent-event presentation rules.
      - [ ] 5.1.2.2 Subtask — Distinguish requested, admitted, dispatched, observed, verified, decided, published, externally applied, re-observed, and satisfied events.
      - [ ] 5.1.2.3 Subtask — Add accessible event detail and evidence panels with safe previews, provenance, revision, integrity, retention, and download posture.
      - [ ] 5.1.2.4 Subtask — Test duplicate, late, missing, redacted, unavailable, conflicting, and high-volume event sequences across parallel attempts.

  - [ ] 5.2 Section — Bind admitted semantic controls to the governed command path.

    This section exposes only currently accepted commands through explicit
    handlers with reauthorization, step-up, concurrency, and canonical receipts.

    - [ ] 5.2.1 Task {#hui-p05-command-adapter} [repo: jido_code] [after: {#hui-p05-timeline}] — Implement the product command adapter and explicit routes.

      This task maps UI intent to existing gateway commands and refuses to create
      pause, resume, emergency-stop, bulk, or other semantics absent from contracts.

      - [ ] 5.2.1.1 Subtask — Inventory accepted steer, answer, cancel, handoff, retry/recovery, and draft-publication authorization contracts plus their precise lifecycle preconditions.
      - [ ] 5.2.1.2 Subtask — Implement explicit non-GET controller routes, closed schemas, trusted identity/scope construction, CSRF/Origin checks, step-up, and per-command reauthorization.
      - [ ] 5.2.1.3 Subtask — Bind current state/revision, lease/fence, profile, idempotency key, reason, target, expiry, and canonical request digest at admission.
      - [ ] 5.2.1.4 Subtask — Route commands through public governed gateways and derive all displayed outcomes from durable receipts and re-observed projections.

    - [ ] 5.2.2 Task {#hui-p05-command-ux} [repo: jido_code] [after: {#hui-p05-command-adapter}] — Implement safe command previews, confirmations, and recovery.

      This task makes consequences explicit and prevents optimistic browser state
      from being mistaken for command acceptance or effect.

      - [ ] 5.2.2.1 Subtask — Render server-generated canonical previews with target, scope, consequence, current revision, assurance need, reason requirement, and irreversible boundaries.
      - [ ] 5.2.2.2 Subtask — Implement native confirmation forms and progressively enhanced dialogs with focus return, double-submit protection, pending state, and idempotent retry.
      - [ ] 5.2.2.3 Subtask — Handle conflict, stale revision, expired step-up, policy denial, timeout, uncertain dispatch, retryable transport failure, and terminal rejection without fabricating success.
      - [ ] 5.2.2.4 Subtask — Present admitted/dispatched/effected/verified status separately and link every outcome to its canonical receipt and evidence.

  - [ ] 5.3 Section — Integrate reviews, budgets, and concurrent human operation.

    This section completes oversight for approval separation, token-cost control,
    and safe races among several authorized humans, tabs, and sessions.

    - [ ] 5.3.1 Task {#hui-p05-review-budget} [repo: jido_code] [after: {#hui-p05-command-ux}] — Implement review evidence and cost oversight panels.

      This task surfaces trusted decision inputs and budget posture without making
      presentation roles or browser totals authoritative.

      - [ ] 5.3.1.1 Subtask — Render decision/review state, required evidence, approver eligibility, separation-of-duty conflicts, expiry, stale-input invalidation, and canonical approval receipts.
      - [ ] 5.3.1.2 Subtask — Render token usage and monetary estimates by attempt, interaction, provider/model, wiki generation, and outcome with provenance, currency, estimate/final labels, and budget thresholds.
      - [ ] 5.3.1.3 Subtask — Show wiki opt-out/effective policy and documentation-generation cost without allowing display state to override repository policy.
      - [ ] 5.3.1.4 Subtask — Conceal or aggregate protected cost, evidence, and reviewer data according to exact field and graph grants.

    - [ ] 5.3.2 Task {#hui-p05-concurrency} [repo: jido_code] [after: {#hui-p05-review-budget}] — Qualify concurrent human and tab behavior.

      This task ensures stale previews and racing commands resolve through domain
      preconditions, idempotency, and receipts rather than last-writer browser state.

      - [ ] 5.3.2.1 Subtask — Exercise two humans and several tabs issuing identical, conflicting, sequential, expired, and post-revocation commands.
      - [ ] 5.3.2.2 Subtask — Verify idempotent replay, optimistic concurrency rejection, lease/fence conflict, canonical winner/loser receipts, and convergent workspace refresh.
      - [ ] 5.3.2.3 Subtask — Verify maker/checker and separation-of-duty rules across role changes, delegation expiry, step-up expiry, and scope revocation.
      - [ ] 5.3.2.4 Subtask — Create `hypermedia-ui-phase-05-receipt.md` in merge-pending state with Gate HUI5 controls, races, costs, and reopening conditions.

  - [ ] 5.4 Section — Phase 5 Integration Tests.

    This final section proves that attempt oversight and controls remain
    authorized, causal, idempotent, recoverable, accessible, and receipt-backed.

    - [ ] 5.4.1 Task {#hui-p05-integration} [repo: jido_code] [after: {#hui-p05-concurrency}] — Execute the HUI5 attempt, command, approval, and cost matrix.

      This task closes governed control only with real command gateways and graph
      projections under parallel, stale, denied, failed, and revoked conditions.

      - [ ] 5.4.1.1 Subtask — Exercise all accepted lifecycle/outcome/event states, evidence types, redactions, unavailable/truncated states, pagination, retries, and parallel attempt timelines.
      - [ ] 5.4.1.2 Subtask — Exercise every admitted command and invalid lifecycle/scope/revision/lease/fence/profile/reason/step-up/idempotency combination with no unsupported controls exposed.
      - [ ] 5.4.1.3 Subtask — Exercise approval invalidation, maker/checker, concurrent humans/tabs, uncertain transport, replay, revocation, receipts, cost aggregation, budgets, and wiki opt-out.
      - [ ] 5.4.1.4 Subtask — Run native/enhanced browser, accessibility, security, real-adapter, prior regression, `mix precommit`, and clean-checkout CI suites.

    - [ ] 5.4.2 Task {#hui-p05-phase-receipt} [repo: jido_code] [after: {#hui-p05-integration}] — Publish and pin the Phase 5 receipt.

      This task records Gate HUI5 evidence and authorizes knowledge lenses only
      from the merged governed-control baseline.

      - [ ] 5.4.2.1 Subtask — Keep HUI5 merge-pending on authority bypass, unsupported verbs, optimistic success, lost causal identity, stale approval, non-idempotent retry, unreceipted effect, cost misstatement, or concurrency failure.
      - [ ] 5.4.2.2 Subtask — Record the full merge SHA/date, command inventory, gateway/browser/concurrency/accessibility evidence, cost semantics, failures, and limitations.
      - [ ] 5.4.2.3 Subtask — Pin the merged candidate commit and check the phase, Phase 5 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 6.
