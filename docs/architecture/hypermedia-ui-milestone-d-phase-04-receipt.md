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

## Section 4.4 Integration Record (in progress)

The real LocalGraph authority adapter now has a non-empty HTTP integration:
two repositories are enrolled through semantic commands, the authorized
repository converges into the stream, and the other repository stays absent
and returns 404 on direct navigation. Reading does not change graph revision.
There is no fixture principal substitution in this test.

The full precommit run passed 1,507 tests (seed 597252, 775.4 seconds).
The pre-upgrade browser matrix passed 123 tests with 162 declared applicability
skips in 13 minutes. Normal-environment Dialyzer passed with its existing
178 filters and no new unfiltered warning. These runs do not by themselves
qualify the subsequent browser-toolchain upgrade.

Production fault probes stop the real query runner and identity store, and
kill the coordinator. Protected content was cleared in approximately 2.3
seconds for service outages and 7–8 milliseconds for coordinator failure;
fresh navigation recovered and graph revision stayed unchanged. One probe
also encountered a failed reconnect after query recovery: the unavailable
query runner correctly triggers pressure degradation. The harness now waits
for the existing ten-low-sample recovery window before fresh admission.
Repeated production probes pass without weakening that guard. The latest
query/identity/coordinator cleanup measurements were 2,317/2,308/2 ms.

Repeated WebKit 26.5 production runs failed the unchanged 10-second refresh
assertion. Diagnostic runs at 20 seconds observed delivery around 11 seconds;
those diagnostic passes are **not** acceptance. TCP nodelay and padding
experiments did not fix the issue and were removed. The behavior matches
[WebKit bug 322545](https://bugs.webkit.org/show_bug.cgi?id=322545), whose
[upstream fix](https://github.com/WebKit/WebKit/pull/72494) landed August 27.
The candidate pins Playwright 1.63.0: Chromium 153.0.8010.12, Firefox 155.0
and WebKit 26.6. All three pass production qualification with the original
10-second assertion, including restart, offline clearing, paused revocation
and native-only rollback. The new regression matrix passed 105 tests outside
WebKit; its 42 WebKit launch failures were missing host libraries, not failed
product assertions. After isolated Ubuntu library installation in the temporary
browser cache, the complete WebKit project passed 21 tests with 36 applicability
skips. Clean-checkout CI must still repeat the complete matrix together.
The earlier WebKit smoke result above is historical only.

The latest production load run completed three rounds in 85,383 ms: four tabs,
two sessions, one named human and an empty factory, under two bounded SHA-256
workers. It delivered 60 patches / 271,080 HTML bytes and rejected the fifth
stream. Peaks: 404,137,912 BEAM bytes, 658,223,104 RSS bytes, 5,218 BEAM processes,
11 process sockets, run queue three, query queue one, four streams and zero
queued protected payload bytes. Query errors and pressure entries were zero.
Reload rounds allow the existing disconnect-cleanup window before reconnecting;
immediate replacement admission can correctly encounter the four-lease ceiling.
This bounded empty-corpus run is not the full production corpus or soak gate.

A subsequent full precommit run had two failures in 1,507 tests: a historical
package-lock assertion and a test command timestamp truncated before its newly
created grant. Both were corrected and their focused reruns passed. Historical
asset evidence remains unchanged; the current browser pin uses bounded successor
provenance. The grant test now keeps full timestamp precision.
Final `mix precommit --failed` passed architecture, formatting and compilation
checks and both previously failed tests (seed 330435, 10.1 seconds).

Declared local hardware: Intel Core i7-12700F, 20 online logical CPUs,
65,619,420 KiB physical RAM, Linux Mint 22.1 x86_64. The production runner emits
the exact candidate/dirty-state, normalized asset-manifest digest, transport
digest (including its ephemeral port), fixed limits, runtime versions, bounded
resource peaks and privacy-safe counters. Disposable data is never a release
artifact. CI repeats production qualification after building digested assets.

Outstanding acceptance evidence includes several-scope production corpus/soak
reconciliation, the remaining storm and
slow-reader/upgrade-failure matrix, actual workstation suspend/resume evidence,
independent security/accessibility/operations-release review, clean-checkout
CI, and merged-candidate closure. No exception or waiver is inferred.

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
