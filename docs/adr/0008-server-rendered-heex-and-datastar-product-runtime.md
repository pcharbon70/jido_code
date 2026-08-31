# ADR 0008: Server-Rendered HEEx And Datastar Product Runtime

- Status: Proposed
- Date: 2026-08-31
- Owners: JidoCode product, web, security, and operations maintainers
- Decision scope: Browser rendering, interaction transport, live delivery,
  client state, and removal of the current LiveView/LiveVue product runtime
- Depends on:
  [ADR 0001](./0001-graph-only-source-of-truth.md),
  [ADR 0003](./0003-first-class-delegated-coding-agents.md), and
  [ADR 0005](./0005-repository-wikis-as-compiled-knowledge-projections.md)
- Research:
  [Secure hypermedia control plane](../research/12-secure-hypermedia-coding-factory-ui.md)
- Specifications:
  [Hypermedia governance baseline](../architecture/hypermedia-product-governance-baseline.md),
  [Datastar/Dstar qualification](../architecture/datastar-dstar-dependency-and-consumer-qualification.md),
  [Datastar interaction contract](../architecture/datastar-request-signal-fragment-and-stream-contract.md), and
  [Runtime migration and rollback](../architecture/hypermedia-runtime-migration-and-rollback.md)

## Context

The current browser product is implemented with Phoenix LiveView, LiveVue,
SaladUI, Vite, a LiveView socket, and LiveView-owned navigation, state, streams,
and events. Accepted product and wiki documents assign authority to that
presentation model.

The target product instead uses ordinary Phoenix routes and controllers,
server-rendered HEEx, Datastar hypermedia requests, and Elixir Dstar SSE
delivery. It must preserve graph-only authority, reviewed projections,
semantic-command gateways, opaque references, authorization, projection
states, and lossy-hint recovery. A browser process, signal, DOM fragment, SSE
connection, or server page process cannot become durable authority.

The chosen ShadcnUI library and Dstar HEEx helpers depend on
`phoenix_live_view` for `Phoenix.Component`, HEEx attributes, and slots. That
compile-time component dependency is distinct from using LiveView routes,
sockets, processes, events, streams, or state ownership.

## Decision

JidoCode will use a server-rendered hypermedia product runtime with these
boundaries:

1. Full pages are rendered by explicit Phoenix controllers and HEEx templates.
2. Product interactions use ordinary authenticated HTTP routes with Phoenix
   CSRF protection and closed request schemas.
3. Datastar progressively enhances navigation, forms, bounded fragment
   updates, signals, and SSE delivery. Essential reads and actions retain a
   meaningful native HTML path where feasible.
4. Dstar is transport tooling, not an application, authorization, command, or
   durability framework.
5. Every page, fragment, stream, refresh, command, and export authorizes the
   exact current principal, resource, action, scope, and environment before
   protected data or an effect is emitted.
6. Product reads use reviewed bounded projections. Product writes use existing
   semantic-command gateways and immutable receipts.
7. PubSub and SSE messages remain lossy invalidation/delivery mechanisms.
   Correctness comes from a fresh authorized graph query and revision envelope.
8. Datastar signals contain only bounded untrusted request or presentation
   intent. They never contain or select identity, authority, graph/query names,
   command names, trusted revisions, fences, profile digests, secrets, or
   durable success.
9. Product code will not use LiveView routes, LiveView processes, LiveView
   events/streams, LiveVue islands, or client-authoritative application state.
10. The `phoenix_live_view` package may remain only for the qualified
    `Phoenix.Component`/HEEx dependency required by ShadcnUI or Dstar. An
    architecture check will distinguish that library use from prohibited
    runtime use.
11. LiveDashboard must be removed, replaced, or explicitly approved as a
    development-only exception before JidoCode claims a literal zero-LiveView
    runtime.
12. The existing Vite asset compiler may remain. Asset compilation is not a
    LiveView concern; any replacement requires its own qualification and
    rollback path.

### Explicit Route And Handler Boundary

Page, fragment, stream, and command routes form an auditable allowlist. High-
risk semantic commands use application-owned controllers. Browser input cannot
select a module, function, Dstar page, or arbitrary event name.

Authorization, concealment, CSRF, and rate limits that require a normal HTTP
response must complete before `Dstar.start/1`. Dstar `0.2.0` page callbacks run
after the SSE response begins and therefore cannot be the first enforcement
point for a protected operation.

### Delivery And Recovery

The application owns one bounded, authorized delivery coordinator per admitted
page/tab. Dstar's optional stream registry may assist with deduplication but is
not authority, quota, revocation, backpressure, or a guarantee of one stream.

Each stream has:

- trusted principal/session identity and generation;
- exact route, project/repository, resource, and projection scope;
- hard expiry and independent revocation notification;
- periodic reauthorization and reauthorization before every patch;
- bounded queues, retry/backoff, connection limits, and cleanup;
- initial current snapshot and reconnect convergence; and
- a terminal authentication outcome that stops automatic reconnect.

## Consequences

### Positive

- browser state aligns with graph-only durability and explicit request
  authority;
- ordinary routes and HEEx make scopes, authorization, caching, and fallback
  behavior inspectable;
- Datastar enables responsive fragments and live delivery without introducing
  a second application-state runtime;
- separate attempt workspaces work naturally in browser tabs and durable URLs;
- the application can reuse current Product projections and command gateways;
  and
- the target removes LiveVue/client-island authority ambiguity.

### Costs And Constraints

- current LiveViews, LiveView tests, LiveVue components, SaladUI integrations,
  socket wiring, and normative documents require migration;
- Dstar/Datastar request, signal, patch, stream, CSRF, CSP, reconnect, and
  revocation behavior requires new qualification;
- application code must own stable fragment identities, focus, native overlay
  state, and response recovery;
- the selected component libraries may retain a `phoenix_live_view` package
  dependency even when runtime use is prohibited; and
- product and operations teams must replace or explicitly retain development
  tooling that currently depends on LiveView.

## Alternatives Rejected

- **Continue LiveView and only replace CSS:** this does not satisfy the selected
  hypermedia runtime or remove LiveView state/process ownership.
- **Build a client SPA:** this creates another state and authorization surface,
  weakens native navigation/fallback, and duplicates server projections.
- **Let Dstar page callbacks perform all authorization:** protected callbacks
  can execute after the SSE response starts and are not an adequate first
  enforcement point.
- **Treat signals or tab IDs as trusted state:** both are visible and forgeable.
- **Open one SSE connection per agent:** this creates avoidable connection,
  quota, cleanup, and cross-scope complexity.
- **Remove Vite solely because LiveView is removed:** Vite compiles assets and
  may remain useful for the permitted `app.js` and `app.css` bundles.
- **Claim zero dependency while consuming current ShadcnUI:** ShadcnUI `0.1.0`
  requires `phoenix_live_view ~> 1.2` for Phoenix.Component.

## Compatibility And Rollback

Migration proceeds route by route behind explicit rollout policy. A route is
not switched until its full-page reads, fragment states, controls,
authorization, accessibility, reconnect, and recovery behavior match or
supersede the accepted contract. LiveView and hypermedia handlers may coexist
temporarily only on distinct routes with no shared mutable browser authority.

Rollback restores the last qualified route owner and asset manifest. It does
not reinterpret graph state, command receipts, or attempt outcomes. Removing
LiveView runtime dependencies is the final milestone and occurs only after the
rollback window closes and clean-checkout evidence proves no product or
development route requires them.

## Acceptance Conditions

This ADR may move to `Accepted` only when:

1. the governing specifications are approved with no weaker graph,
   authorization, projection, command, or recovery boundary;
2. exact Dstar, Datastar, ShadcnUI, Phoenix, and asset versions/digests and
   compatibility constraints are recorded;
3. a clean consumer proves full-page HEEx, fragments, CSRF, CSP nonce mode,
   SSE, reconnect, native fallback, and overlay/focus behavior;
4. controller and stream handlers authorize before protected response start;
5. signals, routes, event names, fragment targets, retries, queues, and stream
   counts are bounded and hostile-input tested;
6. architecture checks reject LiveView product routes/processes/events/streams
   and LiveVue islands while allowing qualified Phoenix.Component use;
7. the migration and rollback specification identifies every current route,
   asset, dependency, test, document, and development-tool owner; and
8. the implementation plan closes through clean-checkout CI and a pinned merged
   candidate without reopening any listed invariant.
