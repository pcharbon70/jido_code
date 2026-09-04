# Hypermedia UI Milestone B Phase 3 Consumer Spike Receipt

## Status

Status: **merge-pending**

This receipt records the verified HUI-B3 implementation candidate. It remains
merge-pending until the implementation pull request passes clean-checkout CI
and merges. HUI-B4 is not authorized until a closure pull request pins that
full merge commit and date without weakening any reopening condition below.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-B2 closure baseline | `21e659819f4ccce7a4ba5fb1a9d858183fb65564` - closure PR #112 |
| Section 3.1 | `094f6b55342a50c156529872f3c456acc6830a24` - isolated native controller/HEEx consumer |
| Section 3.2 | `c0d49072a66d008ab49ed01abfa1c811debe1bda` - closed Datastar request and fragment boundary |
| Section 3.3 | `cfb7e84d10f234462cb77b84ae32ed1825334fe4` - bounded SSE lifecycle and coordinator |
| Section 3.4 | `merge-pending` - browser/proxy matrix, verifier, and receipt |
| Implementation PR head | `merge-pending` |
| Merged candidate | `merge-pending` |

Merged candidate: `merge-pending`
Merge date: `merge-pending`

## Isolated Consumer Boundary

The consumer is an explicit Phoenix controller and HEEx page under
`/__qualification/hypermedia`. It uses the application layout, stable DOM IDs,
the qualified `JidoCodeWeb.Components.UI` facade, immutable hostile fixture
data, ordinary GET navigation, ordinary CSRF-protected POST forms, deep links,
filtering, pagination, validation, native disclosure/dialog primitives, and
loading, ready, empty, error, and maintenance outcomes. It adds no product
query, semantic command, durable record, LiveView route/process, LiveVue
island, graph access, or runtime effect.

The route is concealed unless the qualification flag is explicitly true, the
host is on an explicit allowlist, and the request peer is loopback. The default
configuration is disabled, and runtime enablement without a nonempty host list
fails startup. The production-built asset override is separate and is used
only by this browser harness.

## Request, Fragment, And Security Evidence

The harmless signal schema has exactly `q`, `state`, `page`, `note`, `tabId`,
and `scenario`. It bounds bytes, keys, strings, integers, state/scenario
enums, and tab syntax; normalizes pages; and rejects missing transports,
duplicate transport fields, duplicate JSON keys, malformed JSON, nested
values, unknown keys, and oversized bodies. No identity, tenant, project,
graph, delegation, assurance, policy, grant, or revision field is expressible.

Enhanced reads require the Datastar request header and same-origin Fetch
Metadata. Enhanced writes additionally require an exact Origin and Phoenix
CSRF header. Responses are private, use no-referrer policy, and never put CSRF
or sensitive data in signals or URLs. Dstar emits escaped element and signal
patches only for stable, deterministic roots. Unsupported events fail closed.
Browser tests prove focus/selection preservation, disclosure/dialog continuity
and focus return, pending/error outcomes, hostile-text escaping, missing asset
fallback, malformed patch safety, hard reload, and back/forward navigation.

## Bounded Stream And Cleanup Evidence

When the qualification flag is enabled, the application-owned qualification
coordinator permits four concurrent connections, one connection per normalized
correlation bucket, at most eight events and 12,288 conservatively accounted
bytes per connection, and no waiting/producer queue. It is absent from the
default supervision tree. Excess and duplicate connections fail immediately.
The synchronous fixture waits for each chunk before producing another, has a
1,200 ms scheduled lifetime, sends a heartbeat and a 1,500 ms retry hint, caps
browser retries at two with a 3,000 ms maximum wait, and always releases its
token on completion, cancellation, send failure, or owner death.

Initial snapshot, element patch, nudge, explicit completion, duplicate,
reordered, dropped, slow, sleep/wake, restart, and terminal-close fixture hints
are deterministic and non-authoritative. Connection state, fixture freshness,
fixture truth, sequence, and tab correlation remain distinct. Coordinator
tests prove global/per-tab ceilings, event/byte limits, fail-fast zero queue,
several owners, and zombie cleanup; cleanup emits telemetry with no tab ID,
token, process, or fixture payload.

## Browser, Proxy, CSP, And Accessibility Evidence

Playwright 1.62.0 is a direct exact development dependency. The matrix uses
Chromium revision 1234, Firefox revision 1538, WebKit revision 2336, a
Chromium JavaScript-disabled profile, and a Pixel 7 touch/narrow profile on
Ubuntu 24.04 fallback builds. The page loads the real Vite production bundle,
not the test placeholder manifest. The final local matrix passed 19 applicable
tests; 31 combinations were intentionally skipped by profile-specific cases.

A Node 24.3 core-HTTP reverse proxy passes response chunks through without an
application buffer and marks SSE responses `x-hui-b3-proxy-mode:
unbuffered-sse`. A real browser observed initial bytes more than 100 ms before
the slow stream completed. This is evidence for the fixture seam only; it does
not claim production TLS, HTTP/2, proxy, capacity, or deploy configuration.

The browser suite covers enforcing CSP with the `datastar` Trusted Types
policy and no unsafe-inline/eval, CSRF and signal tampering, native and enhanced
workflows, supported engines, focus and overlay behavior, semantic landmarks,
ARIA snapshot smoke, keyboard focus, reduced motion, forced colors, RTL,
dark theme, 200% zoom, touch, narrow layout, several tabs, duplicate tab IDs,
retry storms, native recovery, and hostile content.

## Verification Record

The machine-readable record is
`priv/architecture/hypermedia_ui/phase_b3_verification_evidence.json`. Its
executable verifier pins the baseline, exact route/security/signal/stream
limits, Playwright and browser profiles, production-asset mode, proxy fixture,
source digests, negative cases, receipt lifecycle, and qualification-only
consumer boundary. The CI `verify` job installs the exact browsers, builds the
production assets, runs the browser/proxy matrix, retains failure traces for
90 days, and still runs the repository `mix precommit` gate.

The implementation candidate passed warnings-as-errors compilation, 28 focused
controller/signal/coordinator/protocol and B2/B3 architecture tests, architecture
checks, the production asset build, the 19-case applicable real-browser matrix,
and `mix precommit` with 1,228 tests and zero failures. The clean-checkout job
identity will be recorded in the implementation PR before merge; any failure
keeps this receipt merge-pending.

## Exceptions And Limitations

There are no HUI-B3 exceptions.

- The fixture supplies no product identity, authority, policy, graph, query,
  command, durable-state, revocation, or business-readiness evidence.
- The Node proxy proves bounded streaming pass-through only. Production TLS,
  HTTP/2, proxy buffering/timeouts, capacity, load, and actual deploy restart
  remain assigned to later milestones.
- Automated semantic/ARIA/keyboard/focus/mode checks do not replace manual
  assistive-technology and supported OS/browser release qualification.
- Ubuntu 24.04 uses Playwright fallback builds for this exact tool release;
  the supported production browser/OS decision remains HUI-B4.
- Phoenix LiveView's nested development-only Babel 8 graph reports Node 24.3
  engine warnings. The exact Playwright and production Vite paths pass.

## Gate HUI-B3 Reopening Conditions

HUI-B3 remains merge-pending. Once accepted, the gate reopens if the B2
baseline or any predecessor gate reopens; if the qualification route becomes
default-enabled, non-loopback, broadly hosted, product-linked, discoverable,
or available without both explicit controls; if the consumer gains a product
query, semantic command, durable state, LiveView/LiveVue consumer, graph/store
access, runtime effect, or browser-derived authority; if signal keys, types,
sizes, normalization, duplicate/unknown/nested rejection, CSRF, Origin, Fetch
Metadata, privacy, referrer, cache, CSP, Trusted Types, escaping, selector, or
unsupported-event behavior drifts; if focus, selection, overlay state, focus
return, pending/error state, scroll/reading continuity, native navigation,
deep links, reload, back/forward, or no-JS fallback regresses; if event, byte,
rate, lifetime, retry, queue, per-tab, or global bounds widen or cease failing
closed; if heartbeat, completion, cancellation, backpressure, owner monitoring,
cleanup, or telemetry regresses; if tab IDs gain identity or authority meaning;
if connection, freshness, sequence, or truth are conflated; if duplicate,
reorder, drop, slow, sleep/wake, restart, terminal, malformed, missing-asset,
multi-tab, or zombie behavior is no longer covered; if the exact dependency,
browser, asset, proxy, source digest, test matrix, evidence, limitation, or
exception posture drifts; if an unsupported browser/profile is claimed; if a
required reopening condition is weakened or removed; or if strict compile,
architecture, focused protocol tests, production asset build, real-browser
matrix, `mix precommit`, or clean-checkout CI fails at the exact candidate.
