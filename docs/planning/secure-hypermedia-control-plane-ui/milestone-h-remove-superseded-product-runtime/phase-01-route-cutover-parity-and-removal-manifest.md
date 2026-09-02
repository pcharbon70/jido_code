---
id: plan.jido_code_hypermedia_ui_milestone_h_phase_01
parent_plan: plan.jido_code_hypermedia_ui_milestone_h
status: proposed
intent: feature
---

# Milestone H Phase 1 - Route Cutover, Parity, And Removal Manifest

This phase moves final traffic to the qualified controller/HEEx/Datastar
runtime by controlled cohorts and proves every legacy consumer's disposition
before deletion begins.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Cut over qualified product traffic and freeze the exact removal manifest.

  This phase closes HUI-H1 while the HUI7 rollback path remains available and
  no unresolved legacy code or dependency is deleted.

  - [ ] 1.1 Section - Reconcile routes, capabilities, and consumers against HUI7.

    This section updates the authority inventory with exact current source,
    build, runtime, test, documentation, monitoring, and deployment consumers.

    - [ ] 1.1.1 Task {#huih-p01-parity} [repo: jido_code] [after: {#huig-p05-phase-receipt}] - Build the final parity and consumer ledger.

      This task requires every item to resolve as qualified replacement,
      intentional retirement, or retained exception with owner/evidence.

      - [ ] 1.1.1.1 Subtask - Enumerate browser/admin/health/dashboard routes, pipelines/sessions/sockets, controllers/templates/LiveViews/components, supervised processes, helpers/hooks, dependencies/assets/config, tests/docs/runbooks/monitoring/deploy consumers.
      - [ ] 1.1.1.2 Subtask - Map each read/control/review/cost/wiki/lens/incident/accessibility/security/operations capability and deep link to exact HUI7 replacement evidence or approved retirement.
      - [ ] 1.1.1.3 Subtask - Identify `phoenix_live_view` Phoenix.Component consumers, Vite asset consumers, LiveDashboard dependencies, transitive runtime applications, and any development/test-only path.
      - [ ] 1.1.1.4 Subtask - Assign disposition, file/symbol/route/config owner, removal phase, rollback dependency, validation, exception expiry, and reopening condition to every item.

  - [ ] 1.2 Section - Execute controlled route and traffic cutover.

    This section changes routing/configuration by observable cohorts with exact
    abort conditions and preserved session/asset/command/graph compatibility.

    - [ ] 1.2.1 Task {#huih-p01-cutover} [repo: jido_code] [after: {#huih-p01-parity}] - Cut over product routes and production traffic.

      This task never mixes old and new authority for one effect and retains a
      rehearsed route/config rollback until the declared close condition.

      - [ ] 1.2.1.1 Subtask - Define cohort order for internal/admin/read/live/control/lens/incident routes, traffic percentage/audience, duration, metrics, owner, stop conditions, and rollback point.
      - [ ] 1.2.1.2 Subtask - Verify identity/session/cookie/CSRF, canonical/deep links/redirects, assets/CSP/cache, streams/reconnect, commands/idempotency/receipts, and graph/wiki compatibility per cohort.
      - [ ] 1.2.1.3 Subtask - Monitor authorization denials, errors/latency/resources, command outcomes, stream convergence, task success, accessibility/support issues, incidents, and data reconciliation.
      - [ ] 1.2.1.4 Subtask - Stop and roll back on any authority/data/command/accessibility/availability/resource/evidence invariant failure; preserve durable receipts and incident evidence.

  - [ ] 1.3 Section - Freeze the authorized removal and rollback manifest.

    This section proves no unresolved consumer or rollback dependency can be
    accidentally deleted by later parallel cleanup work.

    - [ ] 1.3.1 Task {#huih-p01-manifest} [repo: jido_code] [after: {#huih-p01-cutover}] - Publish signed removal, retention, and fallback ownership.

      This task becomes the sole deletion authority for Phases 2–3.

      - [ ] 1.3.1.1 Subtask - Record exact remove/retain/retire entries with paths/symbols/packages/assets/config/routes/tests/docs/operations, consumers, qualification evidence, and dependency order.
      - [ ] 1.3.1.2 Subtask - Record retained `phoenix_live_view`/Vite/development exceptions with precise purpose, no-product-runtime proof, owner, upgrade/security evidence, expiry, and future removal condition.
      - [ ] 1.3.1.3 Subtask - Record rollback artifacts/config/procedures that must survive each phase, compatibility window, observation requirement, and authority to close them.
      - [ ] 1.3.1.4 Subtask - Obtain product/architecture/security/accessibility/operations approval and create `hypermedia-ui-milestone-h-phase-01-receipt.md` in merge-pending state.

  - [ ] 1.4 Section - Phase 1 Integration Tests.

    This final section proves cutover parity and manifest completeness before
    any destructive cleanup is authorized.

    - [ ] 1.4.1 Task {#huih-p01-integration} [repo: jido_code] [after: {#huih-p01-manifest}] - Execute the HUI-H1 cutover, parity, and rollback matrix.

      This task compares source/static inventory with actual router,
      supervision, dependency, asset, browser, monitoring, and deployment behavior.

      - [ ] 1.4.1.1 Subtask - Exercise every cutover cohort and accepted product capability in native/enhanced modes, roles/scopes, supported browsers/AT, load/faults, and rollback checkpoints.
      - [ ] 1.4.1.2 Subtask - Compare router/supervision/compiled-app/JS/CSS/build/deploy/test/doc/monitoring scans with the manifest and fail on an orphaned or multiply owned consumer.
      - [ ] 1.4.1.3 Subtask - Exercise canary abort/rollback, session/assets/stream/command/graph/wiki reconciliation, stale clients, and post-rollback support procedures.
      - [ ] 1.4.1.4 Subtask - Run full parity/architecture/security/accessibility/operations suites, `mix precommit`, and clean-checkout CI.

    - [ ] 1.4.2 Task {#huih-p01-phase-receipt} [repo: jido_code] [after: {#huih-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records HUI-H1 evidence in
      `docs/architecture/hypermedia-ui-milestone-h-phase-01-receipt.md`.

      - [ ] 1.4.2.1 Subtask - Keep HUI-H1 merge-pending on parity loss, cutover invariant failure, unresolved/ambiguous consumer, unqualified retention, failed rollback, or unsigned removal entry.
      - [ ] 1.4.2.2 Subtask - Record exact route/traffic/consumer/removal/retention/rollback evidence, discrepancies, exceptions, and all reopening conditions.
      - [ ] 1.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 1 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 2.
