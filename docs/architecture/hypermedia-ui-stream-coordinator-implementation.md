# Product Stream Coordinator Implementation

Owner: JidoCode web, security and operations maintainers. Gate: HUI-D2.
Status: section 2.1 admission candidate; long-lived delivery is not yet accepted.

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
must check their exact lease before sending. Different browser sessions remain
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

## Pending Sections

Section 2.2 adds continuous lifecycle, deadlines, backpressure and drain handling.
Section 2.3 adds generation subscriptions and browser terminal behavior. Section
2.4 qualifies real HTTP, browser/proxy and failure matrices. Until those pass, the
route emits only its bounded authorized snapshot and closes; no product UI control
advertises a continuous connection.
