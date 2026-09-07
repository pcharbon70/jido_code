# HUI-D3 — Projection Subscription and Convergence Receipt

Status: **merge-pending**. Sections 3.1–3.4 passed local qualification; clean-checkout
implementation PR checks and merged-candidate pinning remain required.

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
state stores no event, result, display value or replay queue.

Section 3.2 consumes refresh credits under the existing pre-patch authorization
fence. Initial and incremental stream queries bypass the disposable projection
cache and use the reviewed provider with a 1,500 ms surface deadline inside the
2,000 ms owner watchdog. Route authorization is reconstructed before query and
again after query/render and before transport. The evaluated query revision is
checked before delivery; hint revisions are never rendered.

Each coherent patch has one `#product-owned-content` root. Its encoded event,
including closed `nudge` (registered projection name) and `delivery`
(`visual`/`required`) metadata, shares D2's byte/rate/count budget. Metadata is
not a graph revision, query selector, expression or executable callback. The
client may turn a visual update into a named new-data notice while paused;
the offered refresh/form remains the existing closed D1 request path.
The event's protected HTML is immediately discarded, not buffered. Resume
starts a new snapshot request. Unavailable/security/session replacements bypass
visual pause. Connection and data freshness remain separately labelled.

Section 3.3 compares query results with both the last evaluated revision and
coalesced hints before delivery. Gaps are observable, never replayed. Lag,
backward results and unavailable queries clear the affected content into a
required recovery fragment, retry after 1/2 seconds (quantized by the 2-second
authorization clock), and stop after three failures. New hints cannot bypass
backoff. A successful fresh result resets the failure count. Lost subscription
processes clear content and close the response; the existing client allows at
most two fresh reconnects with 1/2-second delays inside its original deadline.
Revocation, concealment and expiry never take that transient path.

Signed cursors now include the last server-evaluated revision as a continuity
floor, bound to the existing full identity/session/tab/route/resource/filter/
authority fingerprint. A reconnect still runs a fresh query; a result older
than that verified floor cannot start a protected response. Unknown legacy
cursors fail closed and require a new explicit connection. Only fixed outcome
and projection labels and bounded count/duration measurements enter convergence
telemetry. Initial projection payloads are dropped after initial delivery.

## Integration Qualification

The [implementation contract](hypermedia-ui-milestone-d-phase-03-implementation.md)
records the closed registry, reviewed query/root bindings, scoped replay, numerical
bounds, fault-to-test matrix and fixture/deployment limitations.

- `mix precommit`: 1,493 tests, zero failures (800.7 seconds; seed 17338), including
  all accepted predecessor architecture and security gates.
- Full production-asset browser/proxy matrix: 123 passed, 162 applicability skips,
  zero failures/retries (285 combinations across five profiles, 13.1 minutes).
- Named Orca journey: keyboard connect/pause, truthful paused announcement, retained
  focus, cross-tab revocation while paused, concealed terminal alert and native reload
  focus passed. Executable script retained; ephemeral local speech evidence was
  `/tmp/hui-d3-orca.eGFnmG`.
- Real TripleStore/HTTP matrix: three tests passed, covering actual writer revisions,
  complete hint loss, parallel route convergence, distinct named users sharing only
  an untrusted tab value, independent revocation and subscription loss/reconnect.
- Incremental all-route and fault HTTP matrix: four tests passed. Seeded D3 plus D2
  HTTP/revocation/subscription regression: 32 tests passed (seed 3103).
- Strict production compilation and Dialyzer passed. Dialyzer retained the existing
  178 filters with no new warning or unused filter; no suppression was added.

Integration found and fixed an existing registry/provider mismatch: reviewed queries
request up to 100 projects or attempts, but the registry previously accepted only
projects with a maximum of 50. The exact bounded interface now agrees, with negative
limit/kind tests. Enumeration still grants nothing and field authorization remains
mandatory. D2 source hashes are preserved in predecessor evidence, not rewritten.

The real-store adapter retains actual named-human route/query/field checks but maps
the authorized human to the independent dataset's explicitly granted fixture graph
principal. This is not production graph-authority adapter acceptance. Initial failed
fixture runs exposed the registry mismatch; corrected runs above passed. An initial
copied AT runner still invoked D2; the corrected D3 runner was rerun successfully.

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
