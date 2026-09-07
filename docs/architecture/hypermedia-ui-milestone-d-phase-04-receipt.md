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
Phoenix telemetry logger. Production restart preserves the graph revision and
the persisted named-human login; the same browser checks pass after restart.
These checks do not substitute for load/fault, complete browser/AT or
independent-review evidence. No section is accepted yet.

Section 4.2 adds fixed-cardinality in-memory counters, a four-stream local
factory/tenant envelope, and pressure admission with three-high/ten-low sample
hysteresis. Seven pressure/coordinator tests pass, including rejection without
allocation and refusal to retain arbitrary telemetry keys or payloads.

On Linux Mint 22.1, OTP 28 / Elixir 1.19.5, 20 online schedulers, production
Chromium 151.0.7922.34 sustained four live tabs in two sessions with two SHA-256
workers each retaining 64 MiB. The empty-factory workload delivered eight
patches (36,144 HTML bytes) in 7,499 ms and rejected a fifth stream. Peaks were
369,885,136 BEAM bytes, 564,482,048 process RSS bytes, 1,124 BEAM processes,
nine process sockets, run queue two, query queue zero, four streams and zero
queued protected payload bytes. The measured interval used 21,364 CPU-runtime
ms across schedulers. There were no query errors or slow-owner warnings.
These are small-corpus smoke measurements, not a large-corpus soak, minimum
hardware promise, percentile SLO, or cross-OS performance acceptance.

Section 4.3 adds the trusted disable-delivery switch and closes both new
enhanced admission and protected-delivery races while preserving native routes.
Its real HTTP rollback test passes. The production runner passes Chromium
151.0.7922.34, Firefox 153.0 and WebKit 26.5 for signed-in real graph reads,
direct SSE, periodic refresh, reduced-motion configuration, offline clearing,
and cross-tab revocation while paused. All three engines pass JavaScript-off
native sign-in, navigation/reload and sign-out after rollback. A pre-existing
session remains valid and the graph revision is unchanged by rollback.

The named production Orca/Xvfb run passes announced connected/paused/reload
states, keyboard activation, focus preservation and terminal revocation focus
(`/tmp/hui-d4-orca.I91ccX`, ephemeral speech artifacts). Desktop portal/FUSE
warnings occurred outside the application; they did not replace or satisfy
the speech/focus assertions. No independent reviewer approval is claimed.

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
