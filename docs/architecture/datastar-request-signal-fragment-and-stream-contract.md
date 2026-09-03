# Datastar Request, Signal, Fragment, And Stream Contract

- Status: Accepted architecture contract under ADR 0008; implementation gated
- Specification version: `1.0.0`
- Accepted: 2026-09-03 through HUI-A3 merged-candidate governance
- Owners: JidoCode web, security, projection, and operations maintainers
- Milestone: D — Datastar Delivery
- Decision: [ADR 0008](../adr/0008-server-rendered-heex-and-datastar-product-runtime.md)
- Qualification prerequisite:
  [Datastar/Dstar dependency qualification](./datastar-dstar-dependency-and-consumer-qualification.md)

## Purpose

This specification defines the production request vocabulary, signal boundary,
fragment identity, morph/update rules, stream coordinator, subscription/nudge
behavior, revision convergence, expiry/revocation, errors, and operational
limits for Datastar-enhanced pages.

## Request Classes

| Class | Method | Response | Preconditions |
|---|---|---|---|
| Full page | GET | Complete HEEx document | Authenticated and route/resource authorized |
| Bounded read/filter/search | GET or POST by sensitivity | HEEx patch/SSE events | Closed schema and reviewed query |
| Stream connect | POST | `text/event-stream` | CSRF, Origin, identity/scope, admission limits before start |
| Semantic command | POST/PUT/PATCH | Receipt and refreshed patches | Current authorization, state/revisions/fence, idempotency |
| Approval preview | GET/POST | Canonical HEEx transaction | Separate read authorization; no effect |
| Export | POST | Bounded artifact/receipt | Separate export grant, classification, rate/cost limit |

GET and stream delivery never mutate semantic state.

## Signal Schema

Every page declares:

- a unique namespace;
- allowed local `_` presentation signals;
- allowed non-local request signals;
- maximum keys, nesting depth, scalar/list lengths, and aggregate serialized
  bytes;
- per-action accepted key subset and normalization;
- reset behavior on route/scope/resource change; and
- rejection of unknown, duplicated, malformed, or oversized input.

Filters, sort, cursor, bounded search, selected opaque ref, and disclosure
intent may be signals. Actor, account, role, tenant, project authority, graph/
query/command identity, profile, policy, fence, revision authority, CSRF,
secret, permission, and durable result may not.

## CSRF, Origin, CSP, And Content

Phoenix CSRF protects every browser mutation and stream connect. The selected
header/body adapter keeps the token outside transmitted non-local signals and
URLs. Origin and Fetch Metadata checks are defense in depth. Sensitive routes
set no-store and strict referrer/log policies.

All expressions are static server-authored templates. User, source, wiki,
memory, graph, model, provider, and tool text is escaped or explicitly
sanitized as content and never interpolated into an expression. Dstar Scripts
and production debug errors are prohibited.

The CSP HTTP response header uses a fresh full-page nonce and qualified
`default-src`, `script-src`, same-origin `connect-src`, `style-src`,
`frame-ancestors`, `base-uri`, `object-src`, and `form-action`.

## Fragment Identity And Morphing

Fragments correspond to one coherent independently authorized projection.
Stable roots include factory attention/health/fleet, project summary/attempts,
attempt header/timeline/checks/budget, command receipt, and knowledge-lens
results.

Patch the smallest region that can preserve semantic consistency. Do not patch
only a value while leaving its state/freshness/accessibility label stale. Do
not routinely replace page shell, navigation, focused form, overlay root,
scroll root, or selected graph root.

## Stream Coordinator

JidoCode owns stream admission and supervision. The deduplication key uses a
trusted stable browser-session/principal identity plus untrusted tab ID, so a
new full-page route in one tab can take over the old stream. Route, scope,
generation, authorization, expiry, and subscriptions are trusted claimed-stream
state, not key material.

The coordinator enforces per-principal/tab/tenant/factory connection counts,
queue events/bytes, patch bytes/rate, heartbeat, lifetime, idle, retry/backoff,
and cleanup. Missing/invalid tab IDs receive a separately bounded posture.

## Projection Subscription And Nudge

The existing server `ProjectionSubscription` remains responsible for last
server-evaluated revision, hint coalescing, reauthorization, and refresh
callback. If the complete request is server-known, the coordinator emits the
fresh fragment. If a tab owns harmless filter/cursor intent, the coordinator
nudges that named projection and the tab performs a fresh authorized request.

The browser never decides that a revision is current. Dropped, duplicated,
reordered, or delayed hints converge through graph queries.

## Reconnect, Expiry, And Revocation

Connect/reconnect obtains a current snapshot. Replay cursor/event IDs are
opaque, bounded, and scoped to principal, browser session, tab, route,
repository, attempt, and projection. They cannot cross scope.

Every stream has hard expiry, independent session-generation/revocation
subscription, periodic reauthorization, and authorization before every patch.
A terminal auth result stops reconnect. Connected clients receive best-effort
concealed/reauth replacement; offline delivered DOM cannot be remotely erased.

## Error And Command Recovery

Before response start, ordinary concealed HTTP errors remain available. After
SSE start, errors use a closed safe event/fragment vocabulary and then close or
continue according to policy. Raw exceptions never reach the browser.

Commands are never optimistic-success. Transport loss leads to unknown outcome
and receipt lookup/requery. Duplicate idempotency returns the existing safe
receipt; stale state/fence returns conflict and current admissible posture.

## Acceptance And Reopening

Milestone D closes with real browser/proxy tests for schema bounds, CSRF/CSP,
fragments/focus, several tabs, hints, reorder/drop/duplicate, reconnect,
takeover, deploy restart, hard expiry, revocation, terminal retry, backpressure,
cleanup, and graph convergence. It reopens on an unbounded signal/stream/patch,
authorization after response start, revision authority in the client, CSRF
leakage, protected reconnect after revocation, or stale/unauthorized fragment.
