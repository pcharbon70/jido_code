# HUI-D3 subscription and convergence contract

The phase receipt owns acceptance. This document describes the implementation;
it does not authorize D4 or replace any predecessor reopening condition.

## Closed registry

Every entry renders only `#product-owned-content` through its existing controller,
HTML module and reviewed `Product.read_projection/2` provider. Query names and
version remain the C4 `ReadProjectionQuery` catalog bindings at `2.11.0`.
No raw graph query or effect is added to the HTTP boundary.

| Projection | Hint families | Server scope |
| --- | --- | --- |
| factory, fleet, projects | factory_catalog, repository_control, observation_batch, run_attempt, run_event_segment, evidence | current factory |
| project | same six families | current factory plus exact registered repository |
| project_attempts, attempt | factory_catalog, repository_control, run_attempt, run_event_segment, evidence | current factory plus exact registered resource scope |
| project_wiki | factory_catalog, repository_control, repository_wiki, run_attempt | current factory plus exact registered repository |
| project_dependencies | factory_catalog, repository_control, source_revision | current factory plus exact registered repository |
| account, sessions | none | identity-only; D2 reauthorization and terminal replacement |

The trusted route, resource registry, current named identity and exact authority
choose the entry and scopes. Caller graph/query/root/callback values are not inputs.
Bootstrap resources lacking a valid semantic scope subscribe only to the factory;
periodic fresh queries cover missing hints and still fail closed when graph authority
is unconfigured. The graph provider enumerates at most 100 registered projects or
attempts, authorizes each candidate, and retains its existing 24-row scan/20-row page
bounds. D3 fixes the registry/provider mismatch (previously project-only, maximum 50)
without granting enumerated resources or exposing registry rows directly.

## Ownership and limits

`ProjectionSubscription` page mode is a disposable, independently owner-monitored
process. Unlike its legacy callback mode, it holds one pull credit; the admitted HTTP
owner performs the fresh query and render under the D2 watchdog. State contains no
query result, display payload, receipt identifier or replay queue. Only evaluated
revision advances truth; incoming revisions coalesce to one maximum hint.

At most two semantic scopes and 20 registered families are accepted. Mailbox overflow
is detected when dequeuing above 64 messages and terminates the subscription normally,
avoiding scoped-message crash logs. This is overflow detection, not a hard BEAM mailbox
allocation cap. It never forwards hints into the HTTP owner's mailbox. D2 connection,
admission, nonce, byte, event, lifetime and work caps remain unchanged.

Reconciliation runs every five seconds, quantized by D2's two-second authorization
checks. A fresh query has a 1,500 ms deadline inside the 2,000 ms owner watchdog.
Lag, backward results and unavailable results clear data with a required recovery
fragment and back off 1/2 seconds; three failures terminate delivery. New hints cannot
bypass backoff. Lost subscriptions clear content then end the response, allowing
D2's two bounded reconnects inside the original client deadline. Manager/node loss,
drain, disconnect and expiry retain D2 cleanup and reconnect/terminal rules.

Every encoded patch (including cursor and closed metadata) fits the inherited 131,072
byte event cap, one-MiB total, 120-event cap and minimum interval. Authorization runs
before query, during field shaping, after render and immediately before transport.
No event is constructed from a hint payload. Initial projection payload references
are removed from connection state after sending the initial snapshot.

## Revision continuity and visual intent

Signed cursor payloads include the server-evaluated dataset revision, bound to the
full existing principal/session generation/tab/route/repository/attempt/projection/
filter/authority fingerprint. They are continuity floors, never grants. Connect and
reconnect always requery; older results cannot start a protected response. Unknown,
legacy or copied cursors fail closed. Authority changes invalidate the fingerprint.

`delivery=visual|required` and a registered projection-name `nudge` are closed data
metadata, not executable expressions. Pause discards visual HTML immediately and
announces new data; it does not queue protected content. Required recovery/security
patches bypass pause. Resume starts a new snapshot with a new request nonce. Existing
D1 bounded refresh/form schemas carry any current harmless filter intent. Native
links/forms remain usable without JavaScript; connection is not presented as freshness.

## Evidence map and limitations

| Boundary/fault | Executable evidence |
| --- | --- |
| All ten routes, closed signals, root and admission | stream_controller_test, stream_intent_test, stream_projection_registry_test |
| All eight incremental graph routes and registered family hints | stream_convergence_http_test |
| Duplicate/reordered/coalesced/delayed/gap hints, lag, finite backoff, overflow and owner exit | stream_subscription_test and stream_convergence_http_test |
| Real durable writes, total hint loss, parallel route convergence, two named users, revocation isolation, subscription loss/reconnect | stream_real_store_test |
| Query-time revocation, escaped rendering, patch overflow, unavailable clearing | stream_update_test |
| Scoped/unknown/copied cursors, revision floor and safe telemetry | stream_recovery_test, stream_continuity_test, D2 stream_reauthorization_test |
| Disconnect, stalled owner, manager/node loss, restart, drain, limits, all eight revocations | predecessor stream_http_test and coordinator suites |
| Pause/resume, fresh periodic query, native fallback, keyboard/focus, security replacement | hypermedia_ui_phase_d3.spec.mjs plus complete predecessor browser/proxy matrix |
| Named screen-reader speech and keyboard pause/revocation/reload | qualify_hui_d3_orca.sh and hypermedia_ui_phase_d3_orca.mjs |

The real-store fixture uses actual TripleStore, reviewed queries and writer commits,
real named-human admission and field reauthorization, and real Bandit/Req HTTP. Its
test-only adapter maps that authorized human to the independent dataset's explicitly
granted fixture principal. This bridge is not production identity-to-graph integration
acceptance. Production deployment and real-adapter qualification remain D4 work.
Browser pause injection tests exercise the SDK event boundary; real HTTP/store tests
separately prove server query/delivery semantics. Offline DOM cannot be remotely erased.
