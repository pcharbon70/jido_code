# HUI-D3 — Projection Subscription and Convergence Receipt

Status: **merge-pending**. Implementation and integration qualification are in progress.

## Candidate Provenance

- Authorized baseline: `c39f90316cb90d85a9413c2cc9da0115fdd65a9a` (D2 closure PR #131).
- Accepted predecessor: `1d55390108763052998cc6f6e6dfc4ce319998c0`.
- Section commits, implementation PR, clean-checkout jobs and merged candidate: pending.

## Gate HUI-D3

**merge-pending**. Phase D4 is not authorized by this receipt.

## Evidence

Section 3.1 introduces a closed registry for eight graph read surfaces and two
identity-only surfaces. The existing ProjectionSubscription owns evaluated
revision and coalesced hints; the admitted HTTP owner holds the only refresh
credit. At most two server-resolved semantic scopes are subscribed. Bootstrap
resources without a valid semantic scope use factory hints and periodic fresh
queries, never a fabricated scope or a widened graph grant. Queries still fail
closed while production graph authority is unconfigured.

Lifecycle closure stops the subscription; an independent owner monitor also
cleans up after normal exit, failure or coordinator termination. Subscription
state stores no event, result, display value or replay queue. Section 3.2 will
consume refresh credits under the existing pre-patch authorization fence.

## Reopening Conditions

The gate reopens independently of checkbox state if:

- A hint, browser revision, event ID, cached fragment or connection becomes displayed truth or authority.
- An unregistered route, graph family, scope, query callback or fragment root is selected by caller input.
- Any protected query, field shaping or patch lacks current exact authorization, or revocation fails to clear connected protected content and suppress reconnect.
- Duplicate, reordered, delayed, lost or coalesced hints, lag, failure, restart or reconnect prevent bounded fresh-query convergence.
- A replay cursor crosses principal, session generation, tab, route, repository, attempt, projection, filter or authority scope.
- Paused visual updates suppress a security/session replacement, misrepresent freshness, or retain protected queued payloads.
- Connection, subscription, mailbox, work, retry, event, byte, rate or lifetime limits are absent or bypassed, or cleanup leaks resources.
- Real-store, stream, browser, accessibility, revocation, fault or clean-checkout CI evidence is missing or fails, or merge provenance is not pinned.
- Any accepted predecessor reopening condition regresses.

Offline delivered DOM cannot be remotely erased. D4 production deployment,
multi-node capacity and real-adapter acceptance remain separate gates.
