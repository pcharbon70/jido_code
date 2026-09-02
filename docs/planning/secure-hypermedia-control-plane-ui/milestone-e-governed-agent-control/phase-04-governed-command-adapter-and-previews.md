---
id: plan.jido_code_hypermedia_ui_milestone_e_phase_04
parent_plan: plan.jido_code_hypermedia_ui_milestone_e
status: proposed
intent: feature
---

# Milestone E Phase 4 - Governed Command Adapter And Previews

This phase exposes only accepted attempt commands through explicit native and
Datastar handlers backed by the governed semantic command pipeline.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Deliver exact command previews, admission, receipts, and recovery.

  This phase closes HUI-E4 by ensuring every visible control has current
  gateway semantics and every outcome comes from durable receipts/re-observation.

  - [ ] 4.1 Section - Freeze and implement the product command adapter.

    This section maps closed UI intent to accepted commands and refuses to
    invent lifecycle verbs or direct runtime effects.

    - [ ] 4.1.1 Task {#huie-p04-adapter} [repo: jido_code] [after: {#huie-p03-phase-receipt}] - Extend the interaction-command kernel and implement typed command mappings.

      This task reconciles the Phase 3 answer/steer adapter and extends the same
      closed machinery to cancel, handoff, retry/recovery, and draft-publication
      authorization only where accepted contracts admit them.

      - [ ] 4.1.1.1 Subtask - Prove Phase 3 answer/steer parity and map every remaining control to exact semantic command/version, resource, lifecycle preconditions, authority, assurance, required fields, idempotency, receipt, and recovery semantics.
      - [ ] 4.1.1.2 Subtask - Resolve current exposure gaps and mark commands disabled/unavailable when the gateway/profile/composition is absent; do not simulate them in UI code.
      - [ ] 4.1.1.3 Subtask - Implement typed adapter functions over public gateways; reject generic command names, raw graph mutation, direct process messages, tool calls, and caller-selected modules/profiles.
      - [ ] 4.1.1.4 Subtask - Prohibit pause/resume/emergency-stop/bulk/approve-publication or any other control lacking accepted ontology/gateway/receipt semantics.

  - [ ] 4.2 Section - Implement canonical previews and explicit command routes.

    This section binds human confirmation to the exact current action, target,
    state, fence, profile, consequence, and assurance need.

    - [ ] 4.2.1 Task {#huie-p04-preview} [repo: jido_code] [after: {#huie-p04-adapter}] - Implement server-generated command preview resources.

      This task prevents stale, spoofed, wrong-scope, or client-authored
      confirmation content from authorizing an effect.

      - [ ] 4.2.1.1 Subtask - Re-query current attempt/resource/state/revision/fence/lease/policy and authorize preview generation with exact current principal/scope/assurance.
      - [ ] 4.2.1.2 Subtask - Generate canonical action digest containing command/version, target/scope, parameters, consequence, current preconditions, reason/ticket/evidence needs, expiry, and idempotency binding.
      - [ ] 4.2.1.3 Subtask - Render native confirmation forms and enhanced dialogs with safe summaries, irreversible boundaries, step-up transition, focus return, double-submit protection, and no secrets.
      - [ ] 4.2.1.4 Subtask - Invalidate previews on time, state/revision/fence/policy/scope/role/delegation/assurance change and require regeneration rather than client patching.

    - [ ] 4.2.2 Task {#huie-p04-routes} [repo: jido_code] [after: {#huie-p04-preview}] - Implement explicit command admission and receipt routes.

      This task repeats all security and concurrency checks at effect admission
      and never infers success from an HTTP response or optimistic DOM state.

      - [ ] 4.2.2.1 Subtask - Add explicit non-GET routes per command family with closed params, CSRF/Origin/Fetch Metadata, rate limits, current authority/step-up, and canonical digest verification.
      - [ ] 4.2.2.2 Subtask - Bind current revision/fence/lease/profile, reason, target, idempotency key, actor, correlation, and preview expiry at gateway admission.
      - [ ] 4.2.2.3 Subtask - Render admitted/rejected/conflicted/dispatched/uncertain/effected/verified/terminal status separately and link canonical durable receipt/evidence.
      - [ ] 4.2.2.4 Subtask - Patch/reload only from re-observed authorized projections and clear pending UI on denial, expiry, revocation, conflict, or terminal failure.

  - [ ] 4.3 Section - Implement idempotent transport-loss and conflict recovery.

    This section handles uncertain network outcomes, stale tabs, duplicate
    submissions, and concurrent transitions through receipt lookup and CAS.

    - [ ] 4.3.1 Task {#huie-p04-recovery} [repo: jido_code] [after: {#huie-p04-routes}] - Implement command status lookup and safe retry workflows.

      This task ensures retry never duplicates an accepted effect and conflict
      responses return current safe state rather than last-writer-wins behavior.

      - [ ] 4.3.1.1 Subtask - Implement separately authorized receipt/status lookup by bounded opaque correlation/idempotency ref with no existence inference across scopes.
      - [ ] 4.3.1.2 Subtask - On timeout/disconnect/5xx uncertainty, look up the original receipt before allowing the same idempotency-bound retry.
      - [ ] 4.3.1.3 Subtask - Handle stale revision/fence/lease, duplicate idempotency with mismatched digest, lifecycle conflict, expired step-up/preview, policy denial, and terminal rejection.
      - [ ] 4.3.1.4 Subtask - Converge all open tabs/workspaces through command receipts plus fresh projections and announce outcomes accessibly without exposing protected details.

  - [ ] 4.4 Section - Phase 4 Integration Tests.

    This final section proves every exposed control maps exactly to accepted
    authority and remains idempotent, receipt-backed, and recoverable.

    - [ ] 4.4.1 Task {#huie-p04-integration} [repo: jido_code] [after: {#huie-p04-recovery}] - Execute the HUI-E4 command, preview, conflict, and recovery matrix.

      This task uses real governed gateways and injects stale state, concurrent
      commands, transport loss, revocation, and retries.

      - [ ] 4.4.1.1 Subtask - Exercise every accepted/unsupported command and valid/invalid lifecycle, resource, scope, role, assurance, revision, fence, lease, profile, reason, digest, expiry, and idempotency combination.
      - [ ] 4.4.1.2 Subtask - Exercise native/enhanced preview/confirmation, double submit, stale tab, concurrent conflicting commands, timeout/disconnect before/after admission, receipt lookup, retry, and re-observation.
      - [ ] 4.4.1.3 Subtask - Exercise CSRF/Origin/injection/IDOR, role/session revocation, concealed receipts, focus/error/status announcements, no-JS, and several tabs/users.
      - [ ] 4.4.1.4 Subtask - Run real-gateway/browser/security/accessibility/recovery suites, `mix precommit`, and clean-checkout CI with no direct runtime effect path.

    - [ ] 4.4.2 Task {#huie-p04-phase-receipt} [repo: jido_code] [after: {#huie-p04-integration}] - Publish and pin the Phase 4 receipt.

      This task records HUI-E4 evidence in
      `docs/architecture/hypermedia-ui-milestone-e-phase-04-receipt.md`.

      - [ ] 4.4.2.1 Subtask - Keep HUI-E4 merge-pending on unsupported control, gateway bypass, stale/spoofed preview, optimistic success, non-idempotent retry, unreceipted effect, conflict race, or recovery ambiguity.
      - [ ] 4.4.2.2 Subtask - Record command/version/route/preview/gateway/receipt/fault evidence, failures, limitations, and all reopening conditions.
      - [ ] 4.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 4 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 5.
