---
id: plan.jido_code_hypermedia_ui_milestone_h
status: proposed
intent: feature
milestone: H
program: program.jido_code_secure_hypermedia_control_plane_ui
source:
  - docs/architecture/hypermedia-runtime-migration-and-rollback.md
  - docs/adr/0008-server-rendered-heex-and-datastar-product-runtime.md
  - docs/adr/0010-shadcnui-as-product-component-primitive-layer.md
---

# Milestone H Plan - Remove Superseded Product Runtime

This four-phase plan cuts product traffic to the HUI7-qualified runtime,
reconciles every old consumer, removes LiveView/LiveVue/SaladUI product code and
obsolete assets or records a narrowly qualified exception, updates maintained
documentation/operations, completes the observation window, and closes rollback
and the overall program at the final merged candidate.

Back to program: [Secure Hypermedia Control Plane UI](../README.md)

## Goal

Close program Gate HUI8 without losing capability, authority, accessibility,
or recovery. `phoenix_live_view` may remain only as a proven dependency for
Phoenix.Component/HEEx if still required; Vite may remain as the qualified
asset compiler. Neither retention claim permits LiveView product runtime use.

## Gate And Phase Mapping

| Phase gate | Required result | Phase |
|---|---|---|
| HUI-H1 | Every route/capability/consumer maps to a qualified replacement, intentional retirement, or accepted retained exception; canary cutover and rollback checkpoints pass | [Phase 1](./phase-01-route-cutover-parity-and-removal-manifest.md) |
| HUI-H2 | LiveView routes/socket/product modules/processes/events/streams, LiveVue/Vue bridges, and LiveDashboard are removed or explicitly narrowed/qualified | [Phase 2](./phase-02-liveview-livevue-and-dashboard-removal.md) |
| HUI-H3 | SaladUI, obsolete assets/config/tests, stale docs, and operations are removed/migrated; retained Phoenix.Component/Vite consumers are exact and documented | [Phase 3](./phase-03-saladui-assets-documentation-and-operations-migration.md) |
| HUI-H4 / HUI8 | Observation, reconciliation, clean install/upgrade/recovery, final regressions, rollback closure, and removal scans accept the clean final release | [Phase 4](./phase-04-observation-rollback-closure-and-final-release.md) |

## Phase Order

1. [Phase 1 - Route Cutover, Parity, And Removal Manifest](./phase-01-route-cutover-parity-and-removal-manifest.md)
2. [Phase 2 - LiveView, LiveVue, And Dashboard Removal](./phase-02-liveview-livevue-and-dashboard-removal.md)
3. [Phase 3 - SaladUI, Assets, Documentation, And Operations Migration](./phase-03-saladui-assets-documentation-and-operations-migration.md)
4. [Phase 4 - Observation, Rollback Closure, And Final Release](./phase-04-observation-rollback-closure-and-final-release.md)

Receipts use
`docs/architecture/hypermedia-ui-milestone-h-phase-01-receipt.md` through
`hypermedia-ui-milestone-h-phase-04-receipt.md`. The final receipt closes HUI8
and the entire secure hypermedia control-plane UI program.

## Parallelism And Destructive-Change Boundaries

Cutover cohorts are sequential and rollback-aware. Removal work may be split by
runtime, dependency, assets, tests, docs, and operations only after the Phase 1
manifest assigns disjoint exact files/consumers and the same HUI7 baseline.
No session may delete an unresolved consumer, compatibility path, or rollback
artifact before its authorized phase and observation condition. Git retains
history, but operational recovery must not depend on reconstructing undocumented
state from history under incident pressure.

## Completion Definition

Milestone H completes when static and runtime scans find no unintended
LiveView/LiveVue/Vue/SaladUI/dashboard/socket/hook consumer; all accepted product
workflows still pass; retained dependency/compiler exceptions are exact;
documentation and runbooks describe current reality; the observation window
has no unexplained divergence; rollback is closed by the named authority; and
the final HUI8 receipt pins the merged release with every reopening condition.
