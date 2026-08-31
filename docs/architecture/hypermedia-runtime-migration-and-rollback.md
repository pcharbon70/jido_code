# Hypermedia Runtime Migration And Rollback

- Status: Proposed under ADRs 0008 and 0010
- Specification version: `0.1.0`
- Owners: JidoCode web, operations, release, security, and documentation
  maintainers
- Milestone: H — Remove Superseded Product Runtime
- Decisions:
  [ADR 0008](../adr/0008-server-rendered-heex-and-datastar-product-runtime.md)
  and [ADR 0010](../adr/0010-shadcnui-as-product-component-primitive-layer.md)

## Purpose

This specification defines route ownership migration, coexistence limits,
dependency/asset/test/document removal, rollback, and final proof that no
product or unapproved development route uses LiveView/LiveVue.

## Migration Inventory

The inventory MUST cover:

- `HomeLive`, `CodingAgentLive`, `ManagedCodingAttemptLive`, router
  `live_session`, LiveView endpoint socket, `ProductAuth` on-mount/event hook;
- LiveVue components/islands, Vue sources, LiveSocket and hooks;
- SaladUI delegates, hooks, imports, Tailwind source, CSS/tokens;
- Phoenix Vite and its asset role;
- `phoenix_live_view`, `live_vue`, `salad_ui`, `phoenix_live_dashboard`, and
  related dependencies/compilers;
- `fetch_live_flash`, LiveView helpers, LiveDashboard dev route;
- LiveView/LiveVue/browser tests, fixtures, docs, operations guides, and
  architecture checks; and
- rollback owner and last qualified artifact for every route/bundle.

## Route Cutover State

Each route moves through:

```text
inventoried -> read parity -> command parity -> qualified
  -> default hypermedia -> old route disabled -> old route removed
```

Old and new owners may coexist only on distinct explicit routes or rollout
cohorts. They cannot both consume one browser action or maintain shared mutable
browser state. Graph commands and receipts remain the common durable boundary.

## Cutover Gates

A route cuts over only after:

- page/fragment/query/command and all projection-state parity;
- identity, authorization, concealment, CSRF/CSP, stream revocation;
- native fallback, accessibility, responsiveness, usability;
- real-adapter, load, reconnect, deploy, operations, and rollback evidence;
- safe bookmarks/back/forward/multi-tab behavior; and
- an immutable route/asset/config release record.

## Dependency And Asset Removal

LiveVue, Vue product assets, SaladUI, LiveSocket, and LiveView product code are
removed after the last consumer is proven absent. Vite may remain as the
qualified compiler for `app.js`/`app.css`; replacement is a separate named
change with build/digest/rollback evidence.

`phoenix_live_view` may remain only for qualified Phoenix.Component/HEEx use by
ShadcnUI/Dstar. Architecture checks prohibit runtime use. If the package is
removed entirely, component libraries must first have an independently
qualified replacement.

LiveDashboard is removed/replaced for a literal zero-LiveView runtime. Any
development-only exception narrows the claim and receives explicit dependency,
socket, CSP, authorization, and operations qualification.

## Rollback

Rollback restores the last qualified route table, handler modules, asset
manifest, CSP/config, dependency lock, and operations instructions. It never
rolls back graph facts, receipts, identity generations, or externally observed
source outcomes. If old code cannot read a new semantic protocol, rollback is
blocked until a forward-compatible adapter or new release is selected.

Rollback drills cover partial deploy, stale browser assets, open SSE streams,
session generation, command in flight, provider/runtime outage, and database/
graph schema compatibility.

## Documentation And Operations Closure

Update architecture, AGENTS instructions, developer/user/operator guides,
install/upgrade/rollback, incident, disaster recovery, CSP/proxy, and support
matrix. No current document may assign product route/state/action ownership to
LiveView/LiveVue after final closure.

## Acceptance And Reopening

Milestone H closes only when the inventory has no unexplained consumer,
architecture scans prove no prohibited runtime construct, clean installation
builds local assets, every route passes qualification, rollback succeeds, old
dependencies/assets/docs are removed or explicitly retained, and the merged
candidate is pinned. It reopens on a hidden consumer, stale asset, runtime
socket/event use, broken fallback, unreadable protocol, rollback failure, or
documentation drift.
