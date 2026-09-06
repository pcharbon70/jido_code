# Hypermedia UI Milestone C Phase 5 Receipt

## Status

Status: **merge-pending**

HUI-C5 and program gate HUI3 remain merge-pending until this implementation
pull request passes clean-checkout verification and Dialyzer and merges. The
merged candidate and merge date must be pinned in a narrow closure change.
Milestone D is not authorized by this receipt state.

All HUI-B2/HUI-B4 and HUI-C1 through HUI-C4 reopening conditions remain
cumulative and binding. Nothing here weakens or reinterprets them.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-C4 closure baseline | `2542e9ceed021d42dbbde6cdc9eb9e9613c8546f` - closure PR #124 |
| Accepted HUI-C4 implementation candidate | `4532ff304816ad0a229192f0e0bc0f9a3abb66da` - implementation PR #123 |
| Section 5.1 | `18d9c7f9dbcc6045ed3815fcc7a297960f21bbbd` - native browser, WCAG, and Orca qualification |
| Section 5.2 | `024de7793dbdbd5c4d9ec986ad958c72126a836b` - real-adapter, capacity, failure, privacy, and operations qualification |
| Section 5.3 | `635bfb4f7454bdac284f7eb6320dc179de605680` - native shell and fragment-candidate baseline |
| Section 5.4 | `candidate-head-pending` - integrated HUI-C5/HUI3 release evidence |
| Implementation PR head | `merge-pending` |
| Merged candidate | `merge-pending` |

Merged candidate: `merge-pending`
Merge date: `merge-pending`

## Gate HUI-C5.1 - Native Browser And Accessibility

Status: **merge-pending**

The supported browser matrix is Chrome for Testing 151, Firefox 153, WebKit
26.5, JavaScript-disabled Chrome 151, and Pixel 7/touch Chrome 151 on Linux.
Four native acceptance journeys produce 14 applicable passes and six explicit
profile skips with no failures. They cover the complete sign-in, factory,
project-switch, project, attempt, filter, error, unavailable, concealment,
retry, and sign-out path plus semantics, landmarks, headings, names, roles,
values, descriptions, link purpose, focus, status, 200/400 percent reflow,
320 CSS-pixel width, touch targets, RTL, reduced motion, forced colors,
themes, print, and no-JavaScript operation.

The named assistive-technology profile is Orca 46.1 with Chrome
140.0.7339.80 on Linux 6.8.0-51. A real AT-SPI session traversed sign-in,
factory attention, fleet, projects, project overview, and attempt workspace;
the ephemeral debug trace contained the expected speech labels and was not
retained because raw traces are outside the durable evidence package. The
bounded manifest records the exact commands, profile, results, owner, expiry,
limitation, and reopening conditions.

## Gate HUI-C5.2 - Adapters, Capacity, Privacy, And Operations

Status: **merge-pending**

The production-like adapter matrix uses integrity-protected persistent
`JidoCode.Identity.Store`, the real RocksDB quad TripleStore and StoreServer
filesystem/readiness path, production Vite assets, and direct HTTP/1.1,
streaming reverse-proxy, and TLS HTTP/2 profiles. The production graph-
authority adapter remains deliberately `Unconfigured`; its accepted behavior
is fail-closed unavailable, not a live grant claim.

Declared ceilings are 100 registry candidates, 24 scanned projects, 20 page
rows, 121 bounded queries per factory surface, 5.5 seconds, 256 KiB serialized
projection size, eight concurrent users with four tabs each, and a 512-entry
cache with 5-second freshness, 30-second retention, 16 MiB process-memory
growth, and 25 ms p95 operation time. Focused tests pass persisted-identity
restart, real-store effect-free reads, 100-project/32-tab load, cache
contention, hostile filters, concealment, and private response policy.

Identity/store/asset outage, graph lag, timeout, restart, stale cache,
revocation, clock skew, malformed content, maintenance, and safe read-only
fallback evidence remains green through the cumulative suites. Protected
responses are private/no-store, referrers disclose origin only, telemetry has
closed safe dimensions, and HTML/headers contain no raw IRI, secret, reusable
session, graph scope, or cross-scope diagnostic.

## Gate HUI-C5.3 - HUI3 Native Shell Baseline

Status: **merge-pending**

The machine manifest and companion architecture record inventory 27 accepted
controller routes, ProductPageViewModel and ReadProjection shapes, five
component facades, every page and projection root, focus/error targets, exact
authorization owners, query protocol and bounds, native interaction, all ten
canonical states, and every unsupported placeholder.

The HUI-C1 identity/session/revocation, C2 component/design/assets, C3
route/native-navigation, C4 projection/cache/readiness/wiki/cost, C5
accessibility, and C5 adapter/capacity/privacy/operations evidence is
reconciled. The manifest lists the only eight projection-root families that
Milestone D may enhance and explicitly prohibits breaking ordinary native
behavior, stable identity, exact field authorization, truthful state, privacy,
accessibility, or resource bounds.

## Gate HUI-C5.4 / HUI3 - Integrated Release Candidate

Status: **merge-pending**

The 120-test focused matrix covers named identity, persistence, session,
scope, revocation, routes, native navigation/forms, every projection state,
attention/fleet/project/attempt views, query/row/field authorization,
cross-scope concealment, hostile content, privacy, cache isolation, bounded
100-project/32-tab load, real TripleStore reads, adapter outage, restart,
unsupported capabilities, accessibility manifests, and architecture drift.
It passes with zero failures.

The complete Playwright command enumerates 175 browser/profile combinations
across the HUI-B3 and HUI-C2 through HUI-C5 suites. Chrome for Testing 151,
Firefox 153, WebKit 26.5, JavaScript-disabled Chrome, and Pixel/touch Chrome
produce 84 applicable passes, 91 explicit profile-inapplicable skips, and zero
failures in 1m30s. It includes direct HTTP/1.1, streaming proxy, TLS HTTP/2,
production assets, no-JavaScript, accessibility, fault, and native-shell
paths. The named Orca profile and production asset build also pass.

Strict production compilation, the executable HUI-C5 architecture checker,
and `mix precommit` pass. The repository suite contains 1,394 tests with zero
failures. Clean-checkout verification and Dialyzer remain pending on the exact
implementation PR head; no local result can substitute for those jobs.

## Configuration, Exceptions, And Limitations

There are no HUI-C5 architecture exceptions. The declared supported named
screen-reader profile is Orca 46.1 with Chrome 140 on Linux; other screen
readers and OS combinations are outside Milestone C's support matrix. Capacity
and fault evidence qualifies one local Linux node and bounded synthetic
concurrency; distributed sustained-load and deployment observation remain
Milestone G scope.

The production graph-authority adapter remains deliberately unconfigured and
qualified only for fail-closed unavailability. Phishing-resistant step-up,
independent recovery, semantic controls, and later-milestone projections also
remain unavailable. Selection or configuration of any of these capabilities
requires new real-adapter, security, accessibility, and operations evidence.

## Gate HUI-C5 / HUI3 Reopening Conditions

HUI-C5 and HUI3 reopen if any predecessor gate reopens; if a critical native
journey loses keyboard or named-screen-reader operation; if semantics,
landmarks, headings, names, roles, values, descriptions, focus, errors, status,
link purpose, 200/400 percent reflow, 320 CSS-pixel width, touch targets, RTL,
reduced motion, forced colors, themes, print, or no-JavaScript behavior
regresses; or if browser, OS, AT, asset, route, component, or production-
configuration identity drifts without requalification.

The gates reopen if a real adapter, dependency, lockfile, build, proxy, TLS,
fixture, query, schema, or ontology identity drifts; if any latency, memory,
row, byte, cache, concurrency, query-fanout, timeout, or resource threshold is
exceeded; if outage, lag, timeout, restart, stale data, revocation, clock skew,
malformed content, or maintenance exposes old data or false readiness; or if
protected responses leak identity, authority, scope, IRI, secret, content,
query, or cross-scope diagnostics through HTML, headers, referrers, logs,
telemetry, caches, browser storage, or shared/proxy caching.

The gates reopen if an accepted route, view model, component, stable root,
focus target, state, authorization owner, query version, limit, native
interaction, or unsupported placeholder drifts; if reconciled evidence no
longer agrees; if Milestone D removes native behavior, changes stable identity,
accepts browser authority, skips any route/query/row/field/destination/patch
authorization, weakens truthful state, widens a bound, or adds inline/remote/
executable content or a second product runtime; or if a new candidate surface
appears without fresh qualification.

The gates also reopen if the unconfigured graph-authority posture is described
as a live adapter; if a limitation, owner, expiry, result, command, threshold,
prohibition, placeholder, or reopening condition is removed or weakened; if
source/evidence digests drift; or if focused tests, browser tests, production
assets, strict production compilation, architecture checks, `mix precommit`,
or clean-checkout CI fails at the merged candidate.
