# HUI-D4 / HUI4 Local Delivery Receipt

Status: **merge-pending**

## Candidate Provenance

Baseline: `8cac85172eeda04a41ee68f4b3a6dbba935ca8eb`.
Accepted D3 implementation: `a25d1ba65138935bbd065e09518bcdc7c7945301`.
Implementation is in progress; no merged D4 candidate exists.
Source and preserved predecessor digests are recorded in
`priv/architecture/hypermedia_ui/phase_d4_implementation_evidence.json`.

## Qualification

Candidate topology: direct IPv4 loopback HTTP/1.1, single local writable-store
owner; no proxy, cluster, LAN/public exposure or TLS/HTTP2 support is claimed.
Section 4.1 implements the loopback production profile, non-forwarded origin
guard, local HTTP cookie policy, bounded Bandit transport, drain/readiness,
named-human graph-grant composition and pristine local bootstrap ceremony.
Seven focused checks pass, including a real store grant and outage case.
The production-build Chromium 151.0.7922.34 runner passes direct delivery,
periodic refresh, offline clearing/recovery and paused cross-tab revocation.
Request-parameter logging is disabled in production without detaching the
Phoenix telemetry logger. Production restart qualification is in progress.
These checks do not substitute for load/fault, complete browser/AT or
independent-review evidence. No section is accepted yet.

## Gate HUI-D4 / HUI4

**merge-pending**. Milestone E is not authorized.

## Reopening Conditions

The gate remains open or reopens, regardless of checkboxes, if:

- Identity, scope, policy, grant, revision, CSRF, Origin or CSP checks weaken, or protected data leaks.
- A browser/event/cached fragment supplies authority or replaces a fresh authorized graph query.
- A claimed transport/runtime/browser profile lacks matching real production evidence, or non-loopback exposure becomes possible.
- Streams, sockets, processes, queues, payloads, queries, retries or cleanup breach their declared bounds.
- Loss, reordering, outage, restart, sleep/wake or overload prevents bounded recovery and graph convergence.
- Revocation, pause, focus, overlays, assistive behavior, native fallback or safe stale-state replacement regresses.
- Disable-delivery rollback changes authoritative data, identity, sessions, routes or bookmarks, or fails its rehearsal.
- Source/config/assets/limits/candidate provenance is incomplete, clean-checkout CI fails, or required independent review is missing.
- Any predecessor gate reopens or single-writer/store integrity is violated.
