# Hypermedia UI Milestone B Phase 4 Qualification Receipt

## Status

Status: **merge-pending**

This receipt records the HUI-B4 implementation candidate. It does not accept
HUI-B4 or close HUI2 before the implementation pull request passes
clean-checkout CI and merges. Milestone C remains unauthorized until a closure
pull request pins the full merged-candidate SHA and date.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-B3 closure baseline | `e14ee7fa268eb6bd5a4d7bb7e519cce748d7b5e2` - closure PR #114 |
| Section 4.1 | `ab2d29065259d4e9a2f720abeffc3672f235f3e3` - dependency fitness policy and drift enforcement |
| Section 4.2 | `0ea83345a3be68993e640c7bfb6a5ab01ef30844` - release qualification and browser/accessibility evidence |
| Section 4.3 | `96badb46f1d2f19a8443363980cc88615d8e78e5` - product-consumption baseline and production exclusion |
| Section 4.4 | `commit-pending` - integration matrix, mutation proof, and receipt preparation |
| Implementation PR head | `merge-pending` |
| Merged candidate | `merge-pending` |

Merged candidate: `merge-pending`
Merge date: `merge-pending`

## Dependency And Consumer Fitness

The executable HUI-B4 policy pins every predecessor manifest, exact Mix/npm
lock, selected source commit, local browser/CSS asset digest, license, direct
and transitive application, and approved consumer. Architecture checking runs
the HUI-B1/B2/B3 verifiers first, then rejects mutable sources, remote assets,
unreviewed overrides/forks, unexpected applications, broad ShadcnUI imports,
new product LiveView/LiveVue/Vue/SaladUI consumers, Dstar Scripts, inline/eval
CSP weakening, browser authority, and unapproved build/network steps.

Any update must renew immutable provenance, license/usage authority, advisory
results, dependency and consumer diffs, browser/protocol evidence, manual
accessibility, release startup, and rollback evidence as one candidate.

## Qualification Evidence

ShadcnUI's upstream suite passed 420 tests with zero failures and one recorded
test-only static typing warning. Dstar 0.2.0 compiles but publishes no upstream
tests, so the application protocol, hostile-input, SSE, and browser suites are
the compensating control. The downstream focused suite passed 49 tests;
warnings-as-errors compilation, Dialyzer (178 accepted ignores, zero unignored
or unnecessary ignores), Hex advisory scan, npm production audit, license and
SBOM checks all passed.

Two production asset builds produced identical static-tree digest
`2f360d1cd037f8c86ef38bf484da68e4c29d2d59b24672d85ca997d4110f6347`.
The release assembled and started/stopped cleanly twice against distinct empty
stores. No persistent product-store restart or qualification-route production
credit is claimed.

The full real-browser suite passed 21 applicable cases with 39 intentional
profile skips across Chromium, Firefox, WebKit, no-JavaScript Chromium, and a
Pixel 7 touch/narrow profile. It exercised production assets, enforcing CSP,
native and enhanced behavior, HTTP/1.1 and HTTP/2 TLS proxy seams, offline and
stale clients, malformed/hostile input, overlay/focus continuity, bounded
streams, and recovery. Hands-on inspection covered accessibility tree,
keyboard/focus, dialog/disclosure behavior, light/dark themes, and 320px
reflow. Named screen-reader speech output is not claimed and remains risk
HUI-B4-R03.

## Product Consumption And Production Boundary

The machine dossier and product-consumption document define the exact facade,
primitives, Datastar attributes/events, Dstar helper surface, local assets,
supported profiles, operating ceilings, failure modes, rollback, upgrade
workflow, and Milestone C-owned application composites. Product code may use
ShadcnUI only through `JidoCodeWeb.Components.UI`; Dstar only in explicit
controllers or application-owned bounded SSE adapters; and Datastar only from
the local `app.js` asset under closed server-owned protocols.

The HUI-B3 fixture source remains deterministic, but its pipeline, routes, and
coordinator are compiled only in the test build. Production configuration has
the build flag false, zero `__qualification` routes, and zero qualification
supervision children even if runtime configuration tries to enable it.

## Integration Verification

The local integration candidate reproduced the unchanged Mix and npm locks,
all predecessor and architecture checks, strict production compilation,
production asset deployment, SBOM/license/advisory results, production release
assembly and clean-store startup, the real-browser/proxy matrix, production
fixture exclusion, and rollback identity. The static tree remained exactly
`2f360d1cd037f8c86ef38bf484da68e4c29d2d59b24672d85ca997d4110f6347`;
Hex and npm production audits reported zero advisories. The browser result
remained 21 applicable passes and 39 profile skips.

The repository `mix precommit` gate passed with 1,238 tests and zero failures.
Existing test-only fixture and static-typing warnings remain visible and are
not production compilation warnings; the strict production build is clean.
Dialyzer passed with 178 accepted ignores, zero unignored errors, and zero
unnecessary ignores.

The executable mutation matrix covers Hex, source, and npm versions; manifest,
source, and asset digests; licenses; ShadcnUI import boundaries; the Datastar
asset; Dstar Scripts; inline/eval CSP; remote assets; browser authority; new
LiveView, LiveVue/Vue, or SaladUI consumers; production qualification routes
or supervision; operational ceilings; Datastar attributes/events; browser
profiles; residual risks; and receipt lifecycle. Every mutation must be
rejected with its named diagnostic. Clean-checkout CI remains merge-pending
and HUI2 remains open until the exact PR candidate passes and merges.

## Exceptions And Residual Risks

There are no HUI-B4 exceptions. The five time-bounded residual risks and their
controls, owners, expiries, and update triggers are pinned in
`phase_b4_qualification_evidence.json`: Dstar's absent upstream tests;
ShadcnUI's upstream test-only warning; named screen-reader coverage deferred to
the first product composition; loopback HTTP/2 fixture evidence not proving
production TLS/proxy/capacity; and Playwright fallback/browser plus
development-only nested Babel engine warnings.

## Gate HUI-B4 / HUI2 Reopening Conditions

HUI-B4 and HUI2 remain merge-pending. Once accepted at the exact merged
candidate, the gate reopens if any HUI-B1, HUI-B2, or HUI-B3 gate reopens; if
any source, source commit, version, lock, checksum, license, usage authority,
advisory, dependency edge, SBOM entry, direct/transitive application, import,
consumer, facade API, primitive, attribute, event, signal schema, asset,
manifest, CSS order, theme token, CSP, browser/profile, browser revision,
proxy, accessibility result, operational ceiling, failure mode, build, release,
rollback, upgrade workflow, evidence, residual risk, owner, expiry, or exception
posture drifts; if ShadcnUI is imported outside the facade; if a new product
LiveView, LiveVue/Vue, SaladUI, Dstar Scripts, dynamic dispatch, remote asset,
inline/eval CSP, or browser-authority consumer appears; if admission,
authorization, CSRF, Origin, Fetch Metadata, redaction, stable-root, escaping,
native-fallback, focus, overlay, reconnect, cleanup, telemetry, or fail-closed
behavior regresses; if retries, queues, connections, lifetime, events, bytes,
signals, or patches become unbounded; if the qualification fixture enters a
production route, supervision tree, product query, command, durable state, or
authority path; if a claimed browser/OS/TLS/proxy/capacity or assistive-
technology profile lacks evidence; if a required reopening condition is
weakened or removed; or if strict compile, architecture/security/a11y checks,
focused/upstream/browser tests, dependency audits, deterministic asset build,
release startup, `mix precommit`, or clean-checkout CI fails at the candidate.
