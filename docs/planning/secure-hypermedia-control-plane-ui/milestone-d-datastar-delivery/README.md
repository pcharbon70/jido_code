---
id: plan.jido_code_hypermedia_ui_milestone_d
status: proposed
intent: feature
milestone: D
program: program.jido_code_secure_hypermedia_control_plane_ui
source:
  - docs/architecture/datastar-request-signal-fragment-and-stream-contract.md
  - docs/architecture/bounded-projections-cache-and-subscriptions.md
  - docs/architecture/change-delivery-and-command-recovery.md
---

# Milestone D Plan - Datastar Delivery

This four-phase plan progressively enhances the accepted native shell with
closed signals, coherent fragments, one authorized bounded stream per page/tab,
server-owned projection subscriptions, reconnect, live revocation,
backpressure, and durable graph-revision convergence.

Back to program: [Secure Hypermedia Control Plane UI](../README.md)

## Goal

Close program Gate HUI4 without changing application authority: Datastar and
Dstar remain disposable transport, signals remain bounded presentation intent,
SSE remains a lossy hint/patch channel, and fresh reviewed TripleStore queries
remain the only source of displayed semantic truth.

## Gate And Phase Mapping

| Phase gate | Required result | Phase |
|---|---|---|
| HUI-D1 | Per-page signal schemas, request classes, CSRF/CSP rules, coherent fragments, stable roots, and native fallback are implemented | [Phase 1](./phase-01-closed-request-signal-and-fragment-contracts.md) |
| HUI-D2 | One bounded authorized page/tab stream coordinator owns admission, takeover, lifetime, queues, cleanup, and safe terminal states | [Phase 2](./phase-02-authorized-page-tab-stream-coordinator.md) |
| HUI-D3 | Existing server-owned subscriptions map hints to authorized re-query/patch or bounded nudges and converge across loss, restart, reconnect, and revocation | [Phase 3](./phase-03-projection-subscription-convergence-and-revocation.md) |
| HUI-D4 / HUI4 | Production proxy/HTTP2, capacity, resource, browser/accessibility, failure, recovery, and real-adapter evidence accept live delivery | [Phase 4](./phase-04-proxy-capacity-recovery-and-delivery-acceptance.md) |

## Phase Order

1. [Phase 1 - Closed Request, Signal, And Fragment Contracts](./phase-01-closed-request-signal-and-fragment-contracts.md)
2. [Phase 2 - Authorized Page/Tab Stream Coordinator](./phase-02-authorized-page-tab-stream-coordinator.md)
3. [Phase 3 - Projection Subscription, Convergence, And Revocation](./phase-03-projection-subscription-convergence-and-revocation.md)
4. [Phase 4 - Proxy, Capacity, Recovery, And Delivery Acceptance](./phase-04-proxy-capacity-recovery-and-delivery-acceptance.md)

Receipts use
`docs/architecture/hypermedia-ui-milestone-d-phase-01-receipt.md` through
`hypermedia-ui-milestone-d-phase-04-receipt.md`. The final receipt closes HUI4
and is the only stream/fragment baseline Milestone E controls may use.

## Parallelism And Boundaries

Signal schemas and fragment renderers may be implemented in parallel by
disjoint page families after stable root ownership is pinned. Only the stream
coordinator owns connection lifecycle; page modules do not start independent
unbounded streams. Several repositories, attempts, users, routes, and tabs are
mandatory test cases. No phase adds a semantic command or browser-side durable
state.

## Completion Definition

Milestone D completes when every enhanced page retains its native path; all
signals/requests/patches/connections are closed and bounded; scope changes
terminate future delivery and reconnect; lost/duplicate/reordered hints
converge through server-known revisions; focus/overlay state remains usable;
and production proxy/resource evidence passes at the pinned candidate.
