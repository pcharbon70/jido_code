---
id: plan.jido_code_secure_hypermedia_control_plane_ui_phase_08
parent_plan: plan.jido_code_secure_hypermedia_control_plane_ui
status: proposed
intent: feature
---

# Secure Hypermedia Control Plane UI Phase 8 — Superseded Runtime Removal And Rollback Closure

This phase implements Milestone H and closes HUI8 by cutting over every product
route, proving no accepted consumer remains, removing or explicitly retaining
the old LiveView/LiveVue/SaladUI runtime and assets, updating operations and
documentation, and closing rollback only after the observation window succeeds.

Back to plan: [README](./README.md)

- [ ] 8 Phase — Remove superseded product runtime and pin the final release.

  This phase performs destructive cleanup only from the accepted HUI7 baseline
  and preserves Phoenix.Component or Vite solely where an explicit consumer remains.

  - [ ] 8.1 Section — Cut over product routes and prove qualified parity.

    This section moves final traffic to controller/HEEx/Datastar paths while
    retaining a controlled rollback route until the release observation gate closes.

    - [ ] 8.1.1 Task {#hui-p08-cutover} [repo: jido_code] [after: {#hui-p07-phase-receipt}] — Execute route, traffic, and asset cutover.

      This task changes routing only after each product surface has matching HUI7
      evidence and keeps health, degraded mode, and rollback controls observable.

      - [ ] 8.1.1.1 Subtask — Inventory every product/admin/health/dashboard route, endpoint/socket, layout, asset entry point, cache key, bookmark/deep link, and external consumer against its replacement or exception.
      - [ ] 8.1.1.2 Subtask — Cut over by explicit route/feature cohort with canary metrics, session compatibility, redirect policy, CSP/assets, command safety, and rollback checkpoints.
      - [ ] 8.1.1.3 Subtask — Verify native and Datastar behavior, named identity/scope, streams, controls, lenses, incidents, accessibility, support links, and honest unconfigured posture after each cohort.
      - [ ] 8.1.1.4 Subtask — Stop cutover and execute the rehearsed rollback on any authorization, command, data, accessibility, availability, resource, or evidence invariant failure.

    - [ ] 8.1.2 Task {#hui-p08-parity} [repo: jido_code] [after: {#hui-p08-cutover}] — Prove there are no unqualified legacy-only consumers.

      This task requires evidence for every legacy capability, import, hook, route,
      process, test, and operational dependency before its implementation is removed.

      - [ ] 8.1.2.1 Subtask — Compare the accepted route/capability matrix with router output, runtime supervision, compiled dependencies, JS/CSS graph, tests, docs, monitoring, and deployment manifests.
      - [ ] 8.1.2.2 Subtask — Resolve each item as qualified replacement, intentionally retired capability, or narrowly documented retained dependency with owner and reopening condition.
      - [ ] 8.1.2.3 Subtask — Prove rollback remains executable and graph/command/session data remain compatible throughout the observation window.
      - [ ] 8.1.2.4 Subtask — Obtain product, security, accessibility, operations, and architecture sign-off on the removal manifest.

  - [ ] 8.2 Section — Remove superseded code, dependencies, assets, and runtime paths.

    This section deletes only manifest-approved legacy material and verifies the
    resulting release contains one coherent product delivery architecture.

    - [ ] 8.2.1 Task {#hui-p08-runtime-removal} [repo: jido_code] [after: {#hui-p08-parity}] — Remove LiveView and LiveVue product runtime consumers.

      This task removes product sockets, sessions, routes, modules, processes,
      hooks, tests, and configuration while retaining `phoenix_live_view` only if
      its documented Phoenix.Component consumer still requires the package.

      - [ ] 8.2.1.1 Subtask — Remove legacy LiveView/LiveComponent product modules, `live_session`/route/socket wiring, navigation helpers, assigns/streams, hooks, and runtime configuration.
      - [ ] 8.2.1.2 Subtask — Remove LiveVue/Vue bridge modules, components, entry points, generated glue, npm packages, aliases, tests, and deployment configuration.
      - [ ] 8.2.1.3 Subtask — Audit compiled applications and supervision to retain `phoenix_live_view` only for a proven component/rendering need, with no product route/process/state usage.
      - [ ] 8.2.1.4 Subtask — Replace or document any operational dashboard dependency; remove LiveDashboard unless a separately authorized, production-qualified exception is accepted.

    - [ ] 8.2.2 Task {#hui-p08-ui-removal} [repo: jido_code] [after: {#hui-p08-runtime-removal}] — Remove SaladUI and obsolete UI assets.

      This task eliminates the old component/theme layer and stale client code
      after ShadcnUI facade parity and asset integrity are proven.

      - [ ] 8.2.2.1 Subtask — Remove SaladUI dependencies, imports, copied components, theme variables, styles, stories/examples, tests, and documentation.
      - [ ] 8.2.2.2 Subtask — Remove obsolete JS hooks, socket clients, Vue/LiveView code, CSS, icons, fonts, manifests, preload hints, CSP allowances, cache entries, and build aliases.
      - [ ] 8.2.2.3 Subtask — Retain Vite only as the explicitly documented asset compiler when still justified, or migrate it under a separately qualified asset decision.
      - [ ] 8.2.2.4 Subtask — Regenerate locks/manifests, verify licenses/integrity, scan for dead selectors/imports/routes/config, and prove deterministic production assets.

  - [ ] 8.3 Section — Close migration, operations, documentation, and rollback.

    This section aligns the maintained architecture with production reality and
    closes the temporary fallback only after the release is stable and recoverable.

    - [ ] 8.3.1 Task {#hui-p08-docs-ops} [repo: jido_code] [after: {#hui-p08-ui-removal}] — Update authoritative documentation and operational ownership.

      This task removes obsolete instructions and records the final controllers,
      HEEx, Datastar, ShadcnUI, identity, stream, command, lens, and incident model.

      - [ ] 8.3.1.1 Subtask — Update architecture, ADR status, specs, route/component/dependency inventories, developer/user/admin/security guides, runbooks, onboarding, and local/CI/deploy instructions.
      - [ ] 8.3.1.2 Subtask — Update monitoring, alerts, SLOs, capacity, support ownership, incident procedures, backups, recovery, dependency update policy, and evidence retention.
      - [ ] 8.3.1.3 Subtask — Remove references that imply LiveView/LiveVue/SaladUI product use or unavailable factory capability and preserve historical context through supersession links.
      - [ ] 8.3.1.4 Subtask — Verify a clean-room developer and operator can build, run, diagnose, deploy, roll back, and support the final system from maintained documentation.

    - [ ] 8.3.2 Task {#hui-p08-rollback-close} [repo: jido_code] [after: {#hui-p08-docs-ops}] — Complete the observation window and close temporary rollback.

      This task confirms the new runtime remains healthy under real use before
      legacy artifacts or procedures needed solely for immediate reversal are retired.

      - [ ] 8.3.2.1 Subtask — Observe authorization denials, command outcomes, stream/resource behavior, errors, accessibility/support issues, task success, incidents, and SLOs for the declared window.
      - [ ] 8.3.2.2 Subtask — Reconcile graphs, commands, receipts, costs, exports, sessions, audit records, and asset delivery with no unexplained divergence.
      - [ ] 8.3.2.3 Subtask — Close, extend, or execute rollback through the documented decision authority; retain durable evidence and any long-term recovery path.
      - [ ] 8.3.2.4 Subtask — Create `hypermedia-ui-phase-08-receipt.md` in merge-pending state with Gate HUI8 manifest, observation, rollback-closure, final-release, and reopening conditions.

  - [ ] 8.4 Section — Phase 8 Integration Tests.

    This final section proves the clean final system has no accidental legacy
    consumer, retains all accepted behavior, and can be reproduced and operated.

    - [ ] 8.4.1 Task {#hui-p08-integration} [repo: jido_code] [after: {#hui-p08-rollback-close}] — Execute the HUI8 clean-runtime and final-release matrix.

      This task closes the migration only from clean checkout through production-
      like operation, with static and runtime proof of the removal manifest.

      - [ ] 8.4.1.1 Subtask — Prove router/supervision/dependency/JS/CSS/assets/config/tests/docs contain no unintended LiveView, LiveVue, Vue, SaladUI, socket, hook, or dashboard product consumer.
      - [ ] 8.4.1.2 Subtask — Prove all native/enhanced pages, identity/scope/revocation, streams, controls, approvals, costs, lenses, incidents, accessibility, and failure states pass after removal.
      - [ ] 8.4.1.3 Subtask — Run clean install/build/start/upgrade/deploy/rollback-or-recovery, real-adapter load/soak/fault/proxy, stale asset/client, and observation-reconciliation checks.
      - [ ] 8.4.1.4 Subtask — Run all prior phase/security/a11y/architecture suites, `mix precommit`, clean-checkout CI, dependency/license scans, and documentation link validation against the pinned candidate.

    - [ ] 8.4.2 Task {#hui-p08-phase-receipt} [repo: jido_code] [after: {#hui-p08-integration}] — Publish and pin the Phase 8 receipt and final release.

      This task records Gate HUI8 evidence and closes the plan only when the exact
      merged clean-runtime release is accepted with every reopening condition intact.

      - [ ] 8.4.2.1 Subtask — Keep HUI8 merge-pending on unintended legacy consumption, lost capability, weakened authorization/accessibility, asset nondeterminism, failed clean deployment, unexplained reconciliation, open rollback decision, or stale documentation.
      - [ ] 8.4.2.2 Subtask — Record the full merge SHA/date, removal/retention manifest, final dependency/asset/config digests, complete evidence set, observation outcome, recovery posture, exceptions, owners, and expiry.
      - [ ] 8.4.2.3 Subtask — Pin the merged candidate commit and check the phase, Phase 8 Integration Tests section, receipt task, merged-candidate pinning subtask, and parent plan completion only after final acceptance.
