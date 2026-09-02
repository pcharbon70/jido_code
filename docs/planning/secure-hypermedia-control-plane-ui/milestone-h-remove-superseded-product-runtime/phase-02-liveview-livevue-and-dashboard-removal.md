---
id: plan.jido_code_hypermedia_ui_milestone_h_phase_02
parent_plan: plan.jido_code_hypermedia_ui_milestone_h
status: proposed
intent: feature
---

# Milestone H Phase 2 - LiveView, LiveVue, And Dashboard Removal

This phase removes manifest-authorized LiveView/LiveVue product runtime and
resolves LiveDashboard while preserving any exact component-only dependency exception.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Remove superseded interactive runtime routes, processes, bridges, and consumers.

  This phase closes HUI-H2 only from the pinned HUI-H1 manifest and preserves
  qualified replacement and rollback behavior throughout the change.

  - [ ] 2.1 Section - Remove LiveView product routes and server runtime.

    This section deletes product-specific routing, socket, module, process,
    event, stream, helper, and state ownership entries authorized by the manifest.

    - [ ] 2.1.1 Task {#huih-p02-liveview} [repo: jido_code] [after: {#huih-p01-phase-receipt}] - Remove LiveView product consumers and endpoint wiring.

      This task distinguishes product runtime from a possible retained
      Phoenix.Component package dependency and proves the latter starts no product process.

      - [ ] 2.1.1.1 Subtask - Remove product `live`/`live_session` routes, endpoint LiveView socket, `fetch_live_flash`, navigation helpers, layouts, mounts/hooks, and associated configuration.
      - [ ] 2.1.1.2 Subtask - Remove LiveView/LiveComponent product modules/templates, assigns/events/streams/uploads, supervised children/registries, PubSub bindings, and product-only helpers.
      - [ ] 2.1.1.3 Subtask - Remove LiveView-specific controller/browser tests, fixtures, support modules, test aliases, telemetry, monitoring, and deployment assumptions replaced by qualified controller/Datastar evidence.
      - [ ] 2.1.1.4 Subtask - Audit compiled applications/supervision/releases and retain `phoenix_live_view` only for exact documented Phoenix.Component/HEEx consumers if required.

  - [ ] 2.2 Section - Remove LiveVue and Vue bridge/runtime assets.

    This section deletes server/client integration and build dependencies that
    no longer have a qualified product consumer.

    - [ ] 2.2.1 Task {#huih-p02-livevue} [repo: jido_code] [after: {#huih-p02-liveview}] - Remove LiveVue/Vue modules, components, packages, and build paths.

      This task preserves no hidden island, generated glue, compatibility hook,
      or transitive client runtime outside the removal manifest.

      - [ ] 2.2.1.1 Subtask - Remove LiveVue server modules/components/helpers/plugs/config, Vue components/stores/router/bridges/generated entry points, and server-prop serialization.
      - [ ] 2.2.1.2 Subtask - Remove Vue/LiveVue npm packages/plugins/build config/types/tests/stories/examples, aliases, source-map/CSP allowances, preload/caching, and deployment steps.
      - [ ] 2.2.1.3 Subtask - Remove obsolete JS hooks/socket clients and verify app.js contains only approved Datastar/application behavior with no LiveView/Vue transitive bundle.
      - [ ] 2.2.1.4 Subtask - Regenerate lockfiles/manifests/SBOM/licenses/assets and scan production bundles for bridge/runtime symbols and unexpected network/eval behavior.

  - [ ] 2.3 Section - Remove or qualify LiveDashboard and development exceptions.

    This section resolves the last common LiveView route explicitly rather than
    silently weakening the zero-product-runtime claim.

    - [ ] 2.3.1 Task {#huih-p02-dashboard} [repo: jido_code] [after: {#huih-p02-livevue}] - Replace, remove, or narrowly retain operational dashboard behavior.

      This task gives development/operations diagnostics a separately
      authorized supported path without inheriting product session assumptions.

      - [ ] 2.3.1.1 Subtask - Inventory actual LiveDashboard users/capabilities/environments and map each to approved metrics/logs/traces/health tools or an accepted exception.
      - [ ] 2.3.1.2 Subtask - Remove LiveDashboard route/dependency/config/assets/tests/docs when replacement evidence exists, or narrow exact environment/network/identity/authorization/runtime scope.
      - [ ] 2.3.1.3 Subtask - If retained, update architecture claims to exclude the qualified development-only runtime and record security/accessibility/operations/upgrade evidence, owner, expiry, and removal trigger.
      - [ ] 2.3.1.4 Subtask - Update the HUI-H1 manifest with actual removals/retentions and preserve rollback entries still needed through Phase 4.

  - [ ] 2.4 Section - Phase 2 Integration Tests.

    This final section proves no unintended LiveView/LiveVue/Vue/dashboard
    product consumer remains and all qualified behavior still passes.

    - [ ] 2.4.1 Task {#huih-p02-integration} [repo: jido_code] [after: {#huih-p02-dashboard}] - Execute the HUI-H2 clean-runtime matrix.

      This task combines static search, compiled/runtime inspection, production
      bundle analysis, clean install/release, and product regressions.

      - [ ] 2.4.1.1 Subtask - Scan router/endpoint/supervision/modules/config/dependencies/tests/docs/assets/bundles/manifests/deploy outputs for LiveView/LiveVue/Vue/socket/hook/dashboard consumers and compare to retained exceptions.
      - [ ] 2.4.1.2 Subtask - Run all native/enhanced identity/read/live/control/review/cost/wiki/lens/incident/accessibility/security flows after removal with production assets/config.
      - [ ] 2.4.1.3 Subtask - Run clean dependency install/build/release/start, stale-client/assets, upgrade, canary/abort, rollback, and graph/command/receipt/session reconciliation.
      - [ ] 2.4.1.4 Subtask - Run dependency/license/architecture/security/a11y/operations regressions, `mix precommit`, and clean-checkout CI.

    - [ ] 2.4.2 Task {#huih-p02-phase-receipt} [repo: jido_code] [after: {#huih-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records HUI-H2 evidence in
      `docs/architecture/hypermedia-ui-milestone-h-phase-02-receipt.md`.

      - [ ] 2.4.2.1 Subtask - Keep HUI-H2 merge-pending on unintended runtime consumer, lost capability, undocumented retained dependency/dashboard, bundle/runtime residue, failed clean release, or rollback/reconciliation failure.
      - [ ] 2.4.2.2 Subtask - Record exact removal/retention/scan/build/runtime/browser/rollback evidence, exceptions, owners, expiry, and all reopening conditions.
      - [ ] 2.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 2 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 3.
