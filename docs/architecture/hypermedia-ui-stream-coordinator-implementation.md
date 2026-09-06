# Product Stream Coordinator Implementation

Owner: JidoCode web, security and operations maintainers. Gate: HUI-D2.
Status: sections 2.1–2.4 integration candidate; clean CI, merge and pinning are pending.

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
resource, fixed route/projection, normalized query, complete authority fingerprint
and tab. Last-Event-ID must be
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
watchdogs cover blocked or crashed cleanup. Isolated tests can lower positive
numeric limits to accelerate timers and exercise exhaustion; lowering an interval
is a faster test clock, not a stronger production rate limit. The application
child supplies no overrides, and HTTP cannot supply any limit configuration.

## Revocation and Browser Lifecycle

The coordinator subscribes to all eight identity revocation dimensions. Six
scope generations are store-global; account and session generations belong to
their respective records. Hints conservatively wake bounded owners, coalesce
behind one control credit, and never contain a protected replacement. Lost or
reordered hints cannot bypass periodic and final fresh authority/fingerprint
checks. Each stream has a server-generated audit correlation, independent of
browser tab/request values. Authorization decisions use the existing immutable
identity audit boundary.

Integration exposed an existing identity-store defect: session validation ignored
`touch: false`. The narrow repair now returns the unchanged valid session for
background checks. Default foreground validation still touches idle expiry, and
expired/revoked validation still fails closed. Regression tests pin the original
idle deadline through repeated background checks and verify all eight changed
generation fingerprints even with no revocation hint.

Revocation/expiry replaces the entire `#product-shell` with fixed unprotected HEEx,
not merely its data rows. The generic alert and ordinary reload link contain no
identity, query, resource or authority data. Encoded terminal frames are 912–913
bytes, within the reserved 1,024 bytes. A connected browser aborts transport,
focuses the safe alert and suppresses automatic reconnect.

The ordinary “Refresh and connect” anchor works without JavaScript. Its reviewed
local action starts a fresh POST snapshot with Datastar's retries disabled. The
application permits at most two transient retries after 1/2-second backoff and
enforces an independent 30-second deadline, including sleep/wake checks. Each
attempt has a new nonce. Random tab correlation and cursors remain in page memory;
reload creates a new correlation and browser storage is never used. Cursors require
fresh server authorization. Terminal admission outcomes do not retry.

Each attempt has a distinct detached event origin. A capture-phase listener drops
already-buffered patches from replaced/aborted origins before the SDK applies
them. Finite read intent cancels the connection and requires deliberate manual
reconnection. A stream gesture during an in-flight finite refresh asks for a new
gesture after completion, preventing an earlier query from racing the finite
result. This is presentation ordering, never an authorization decision.
Offline, pagehide, deadline and bfcache restoration clear protected
content and do not revive a socket. Focus restoration applies only to surviving
controls. Status distinguishes access checks from data freshness: D2 sends an
initial snapshot and heartbeats; domain-change subscriptions belong to D3.

## Integration Qualification

`StreamHTTPTest` starts a real Bandit listener with the application Endpoint and
the actual application-owned coordinator/watchdog supervisor. The reviewed query
provider is replaced only with bounded test projection data. Named sign-in, cookie
rotation and CSRF use real HTTP and Req. A separate passive TCP fixture intentionally
does not read its small receive buffer; a disposable child BEAM VM proves that
whole-node termination closes the stream. No test backdoor route or production
limit override was added.

The 13 HTTP cases cover pre-header security/schema/scope rejection; initial events
before EOF; private headers and bounded framing; duplicate/cross-route takeover;
session/principal concurrency caps; reduced tenant/factory/admission exhaustion;
encoded/cumulative/event overflow; heartbeats and expiry; disconnect/owner/coordinator
failure and drain; a blocked query; all eight lost-hint generation changes while
idle and while querying; stale same-tab Last-Event-ID/cursor reconnect; hard expiry;
and passive readers/node death. A fingerprint is now part of cursor binding, so
the reconnect test cannot accidentally pass merely by changing tab correlation.

HTTP fixtures accelerate positive timers (100ms checks, 200ms heartbeats, 700ms
idle; selected 200ms admission), lower individual exhaustion limits and restore
the production child between cases. Production values remain those above. Some
transports can retain a disconnected owner until the independent idle deadline;
response arrival also precedes controller `after` cleanup. Tests assert bounded
convergence, not same-instant cleanup. The passive-reader fixture does not claim
kernel send-buffer saturation: D2 sends only one bounded protected snapshot.
Independent blocked-writer/watchdog tests supply that complementary failure fence.

Browser fixtures share a named principal with predecessor suites. Each D2 profile
waits for a fresh 61-second rate window, and each case explicitly signs out its
session to avoid accumulating idle owners. No 429 retry or widened limit masks
exhaustion. Coverage includes local-only storage-disabled operation, copied-tab
same-session takeover versus separate-session isolation, fixed retry/backoff,
late frames, sleep/wake, focus, native fallback, and HTTP/1 plus TLS HTTP/2 proxy
delivery before EOF. Proxy testing exposed absolute upstream asset URLs; the
layout now uses `static_path` for the same single local bundles. CSP is unchanged.
The accepted test HTTP/2 proxy's origin normalization remains a fixture, not a
production proxy trust policy or D4 deployment claim.

Named Orca qualification runs `scripts/qualify_hui_d2_orca.sh`: keyboard connect,
spoken connected status, retained focus, cross-tab revocation, safe alert focus
and keyboard access to the native reload link. Raw speech/browser traces remain
ephemeral. Full precommit and cumulative browser results are recorded in the
phase receipt before the implementation PR; acceptance still requires clean CI,
merge and a narrowly scoped merged-candidate closure.
