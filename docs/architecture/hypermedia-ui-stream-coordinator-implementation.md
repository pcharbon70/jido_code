# Product Stream Coordinator Implementation

Owner: JidoCode web, security and operations maintainers. Gate: HUI-D2.
Status: sections 2.1–2.2 candidate; revocation/browser qualification is pending.

## Admission and Identity

Ten explicit POST `/ui/streams` routes mirror the accepted D1 read surfaces.
JSON is capped at 2,048 bytes before generic parsing/logging. The outer object
has exactly `stream` and the route's `read_<surface>` namespace; nesting is two,
duplicate keys survive parsing and are rejected, and lists/unknown fields fail.
Read intent retains all D1 bounds. `stream` admits only `tab`, `request` and an
optional `cursor`. Tab and request are canonical base64url encodings of 16 random
bytes. The server can validate representation, not client entropy.

Missing/invalid correlations have zero fallback capacity. No cookie-derived
replacement tab, shared anonymous stream or default grant exists. A cursor is
at most 256 ASCII bytes, signed by Phoenix.Token, valid for 120 seconds and bound
to server-known subject, session/generation, account generation, tenant, project,
resource, fixed route/projection, normalized query and tab. Last-Event-ID must be
absent or exactly equal that cursor. Cursor acceptance always means a new current
snapshot, never replay. It contains only a digest, never data or an authority grant.

Exact SSE Accept, named session, real Phoenix CSRF, exact Origin and same-origin
Fetch Metadata complete before authorization and response start. Native controller
specifications select `:stream` before querying, including stream-grant obligations
and redaction. Parent scope, query and field checks remain intact. Background
authorization does not touch session idle expiry. Account/session-only pages use
current same-human session ownership. Final authority fingerprint equality and
current coordinator lease are required after shaping and immediately before send.

## Takeover and Admission Bounds

The coordinator derives the owner PID from the GenServer caller. The key is
trusted session plus untrusted tab; route/scope are claimed state, not key material.
A successful newer request invalidates and terminally notifies the older lease,
including cross-route takeover. Duplicate request nonce rejects with 409 before
evicting anything. Rejected admission never displaces an existing owner. Old owners
must check their exact lease before sending. Closing owners continue to consume
capacity until release/DOWN; takeover needs room for both old and new owners
during its bounded grace. At a hard cap it rejects without evicting the old owner.
Different browser sessions remain
separate even when they copy a tab value.

Fixed limits per application/factory node: 32 connections total, 4 per principal,
2 per session, 16 per tenant (session-only nil tenant shares a bounded bucket),
16 admissions per principal per 60 seconds, 256 rate keys and 1,024 nonce entries.
Nonce reuse is rejected within a 120-second tombstone window; expired tombstones
and process restarts never preserve authority and still require fresh admission.
The manager stores no protected payload. Owner DOWN and controller `after` release
capacity. Encoded initial SSE event is at most 131,072 bytes including its ID and
framing, using Dstar.Elements only. Headers remain private/no-store and disable
proxy buffering. Lifecycle telemetry has fixed reason/projection labels, no refs,
session values, query text or grants. Identity authorization decisions retain the
existing durable audit boundary.

## Supervised Lifecycle and Backpressure

`StreamCoordinator` is an application child. Its one bounded owner watchdog per
HTTP request runs under `StreamOwnerSupervisor`, a DynamicSupervisor capped at 32
temporary children. A watchdog independently monitors both HTTP owner and
coordinator. Coordinator death (including untrappable kill) kills a blocked owner;
watchdog death makes the coordinator kill the now-unguarded owner. HTTP owner DOWN
retires the watchdog and frees the lease. Supervisor restart retains no grants,
payloads, cursors or replay log. Node death closes its local sockets; multi-node
deployment qualification remains D4, not a claim of a cluster-global counter.

| State | Transition and ownership |
| --- | --- |
| admitted | Fresh exact admission, initial query/render deadline; no response yet |
| connected | Last authority fence, exact encoded-byte reservation and bounded write |
| idle | Snapshot sent; no protected data queued; awaiting bounded control credit |
| retrying | Client-only bounded transport retry; server must admit anew, never reuse a lease |
| revoked / expired | Terminal cause; immediately invalidates lease and cancels queued credit |
| closing | Best-effort unprotected terminal event; still consumes capacity |
| closed | Owner release/DOWN; monitored watchdog and lease removed |

Fixed maxima: 60-second connection lifetime, 30-second owner idle lifetime,
10-second initial query/admission, 2-second check/write work, 250ms terminal grace,
100ms sweep, 5-second heartbeat and 2-second reauthorization interval. Hard session
and connection deadlines are checked on every operation, with an independent
monotonic owner deadline and wall-clock session fence. Heartbeat, reauthorization,
successful writes and arbitrary traffic never extend hard or idle lifetime.

The coordinator issues at most one outstanding control credit. Additional timer
work coalesces; no protected payload is queued. Unacknowledged checks and blocked
writes terminate. Each encoded event is capped at 131,072 bytes; the stream caps
at 120 events and 1,048,576 bytes, reserving one event and 1,024 bytes for a fixed
unprotected terminal replacement. Normal events are at least 100ms apart. Overflow
terminates instead of buffering or replaying. Before every protected frame, shared
delivery evaluates fresh authority and verifies the exact current lease. D2 sends
one current snapshot followed by heartbeat/control events, not domain changes.

Deploy drain terminally closes all owners and rejects admission until restart.
Disconnect, exceptions and cancellation use controller `after` cleanup; independent
watchdogs cover blocked or crashed cleanup. Test-owned options may only reduce
fixed positive ceilings. They cannot widen production limits or enter from HTTP.

## Pending Sections

Section 2.3 adds generation subscriptions and browser terminal behavior. Section
2.4 qualifies real HTTP, browser/proxy and failure matrices. Until those pass, no
product UI control advertises a continuous connection. The client retry ceiling
is two retries with 1/2-second backoff, implemented in section 2.3; it never
restores server authority or extends an existing lease.
