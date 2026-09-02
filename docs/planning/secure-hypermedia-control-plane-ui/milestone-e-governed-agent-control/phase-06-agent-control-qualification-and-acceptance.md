---
id: plan.jido_code_hypermedia_ui_milestone_e_phase_06
parent_plan: plan.jido_code_hypermedia_ui_milestone_e
status: proposed
intent: feature
---

# Milestone E Phase 6 - Agent Control Qualification And Acceptance

This phase qualifies the full attempt workbench and governed control surface
with real gateways, concurrent people, production-like faults, accessibility,
usability, load, and recovery before knowledge lenses are added.

Back to plan: [README](./README.md)

- [ ] 6 Phase - Accept governed attempt supervision and controls at a merged candidate.

  This phase closes HUI-E6 and HUI5 only when all visible semantics match
  accepted domain behavior and every uncertain effect resolves safely.

  - [ ] 6.1 Section - Complete command security, recovery, and capacity qualification.

    This section tests the full path from human intent through preview,
    admission, gateway, receipt, stream convergence, and re-observation.

    - [ ] 6.1.1 Task {#huie-p06-security} [repo: jido_code] [after: {#huie-p05-phase-receipt}] - Execute hostile command and review qualification.

      This task treats stale, spoofed, racing, replayed, revoked, and uncertain
      actions as primary cases rather than exceptional cleanup.

      - [ ] 6.1.1.1 Subtask - Test IDOR, signal/param pollution, CSRF/Origin, injection, digest/preview spoofing, idempotency collision, replay, stale revision/fence/lease, and unauthorized command discovery.
      - [ ] 6.1.1.2 Subtask - Test account/session/role/delegation/project/graph/assurance revocation at preview, step-up, admission, dispatch, receipt lookup, patch, and retry boundaries.
      - [ ] 6.1.1.3 Subtask - Load/soak concurrent workspaces, conversation transcripts/composers, timelines, commands, receipt lookups, reviewers, costs, stream patches, slow clients, gateway delays, and queue/backpressure limits.
      - [ ] 6.1.1.4 Subtask - Verify safe audit/telemetry/alerts/runbooks for denials, conflicts, uncertain outcomes, retries, budget breaches, and command incidents without protected payload leakage.

  - [ ] 6.2 Section - Complete accessibility and role-centered usability qualification.

    This section proves developers and reviewers can correctly understand and
    influence parallel attempts under interruption and failure.

    - [ ] 6.2.1 Task {#huie-p06-human} [repo: jido_code] [after: {#huie-p06-security}] - Validate attempt supervision, intervention, review, and cost journeys.

      This task measures correct outcomes and trust calibration, not visual
      preference alone.

      - [ ] 6.2.1.1 Subtask - Test finding a stalled/risky attempt, resuming three workspaces, selecting the correct agent/session, tracing causal evidence, answering/steering/cancelling/handing off/recovering, and distinguishing recorded interaction from observed continuation and uncertain outcomes.
      - [ ] 6.2.1.2 Subtask - Test candidate review, stale/spoofed approval avoidance, two-human conflict, budget/wiki-cost interpretation, and unavailable command recognition by each authorized role.
      - [ ] 6.2.1.3 Subtask - Run keyboard, supported screen reader, zoom/reflow, touch, RTL, reduced motion, forced colors, no-JS native commands, live updates, dialogs, errors, and status announcements.
      - [ ] 6.2.1.4 Subtask - Measure task success, critical errors, time to understand/intervene, resume accuracy, conflict handling, trust calibration, and workload against declared thresholds.

  - [ ] 6.3 Section - Assemble the accepted governed-control baseline.

    This section reconciles command inventory, workspace/timeline, reviews,
    costs, concurrency, operations, and residual risks into one dossier.

    - [ ] 6.3.1 Task {#huie-p06-release} [repo: jido_code] [after: {#huie-p06-human}] - Publish the HUI5 control and evidence manifest.

      This task freezes exactly which controls are production-ready and which
      remain disabled, unavailable, or deferred.

      - [ ] 6.3.1.1 Subtask - Reconcile every workspace/conversation/timeline field, session/message projection, composer mode, control/gateway/version, preview, route, step-up, receipt, recovery, review, cost, wiki-token, stream root, and operational limit.
      - [ ] 6.3.1.2 Subtask - Inventory unsupported commands/capabilities and verify the UI exposes no decorative or direct-runtime substitute.
      - [ ] 6.3.1.3 Subtask - Rehearse disable-controls rollback to the accepted Milestone D read/live baseline while preserving receipt lookup and truthful in-flight outcome recovery.
      - [ ] 6.3.1.4 Subtask - Create `hypermedia-ui-milestone-e-phase-06-receipt.md` in merge-pending state with HUI-E6/HUI5 evidence and reopening conditions.

  - [ ] 6.4 Section - Phase 6 Integration Tests.

    This final section proves the exact candidate safely supports parallel
    attempt supervision and admitted control in production-like conditions.

    - [ ] 6.4.1 Task {#huie-p06-integration} [repo: jido_code] [after: {#huie-p06-release}] - Execute the HUI-E6/HUI5 end-to-end acceptance matrix.

      This task combines all prior E gates with real adapters, several roles,
      concurrent sessions, browsers, load, failures, and rollback.

      - [ ] 6.4.1.1 Subtask - Run workspace/conversation/timeline/evidence/resume, exact session/audience routing, every admitted/unsupported control, preview/step-up/admission/receipt/recovery, review/SoD, cost/wiki accounting, and concurrent-human journeys.
      - [ ] 6.4.1.2 Subtask - Run cross-scope/security/revocation, stale/race/replay, transport/gateway/stream/store failure, load/soak, deploy restart, native fallback, and rollback scenarios.
      - [ ] 6.4.1.3 Subtask - Run complete supported-browser/manual-accessibility and role-usability scenarios with exact production assets/configuration and declared metrics.
      - [ ] 6.4.1.4 Subtask - Run all Milestone E and prior regression suites, architecture/security/a11y checks, `mix precommit`, and clean-checkout CI.

    - [ ] 6.4.2 Task {#huie-p06-phase-receipt} [repo: jido_code] [after: {#huie-p06-integration}] - Publish and pin the Phase 6 receipt and HUI5 closure.

      This task records HUI-E6/HUI5 evidence in
      `docs/architecture/hypermedia-ui-milestone-e-phase-06-receipt.md`.

      - [ ] 6.4.2.1 Subtask - Keep HUI5 merge-pending on semantic/gateway drift, attempt/session/audience misrouting, conversation disclosure or false delivery state, unsupported control, stale approval, unreceipted/duplicate effect, cost/wiki accounting error, concurrency failure, inaccessible critical action, failed usability threshold, or unsafe rollback.
      - [ ] 6.4.2.2 Subtask - Record exact candidate/command/gateway/browser/AT/load/fault/usability/rollback evidence, exceptions, limitations, and every reopening condition.
      - [ ] 6.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 6 Integration Tests section, receipt task, pinning subtask, and Milestone E completion before authorizing Milestone F Phase 1.
