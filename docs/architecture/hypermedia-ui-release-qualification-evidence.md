# Hypermedia UI Release Qualification Evidence

- Status: HUI-B4 qualification evidence complete for the isolated candidate
- Candidate baseline: accepted HUI-B3 closure `e14ee7fa268eb6bd5a4d7bb7e519cce748d7b5e2`
- Review date: 2026-09-04
- Machine record: `priv/architecture/hypermedia_ui/phase_b4_qualification_evidence.json`

## Upstream And Downstream Results

The pinned ShadcnUI source ran 420 tests with zero failures. Its test suite
emitted one static typing warning for `hd(options)` in a generated non-empty
test list; the application strict compile remains warning-free and the exact
facade render/escaping suite passes. Dstar 0.2.0 compiles but publishes no
upstream executable tests, so this is an explicit residual risk rather than a
silent success. Its selected request, fragment, and SSE helpers are exercised
by the 49-test downstream HUI-B1-through-B4 component, CSP, controller,
protocol, security, and architecture matrix.

Dialyzer passed with 178 accepted ignores, zero unignored errors, and zero
unnecessary ignores. `mix hex.audit` found no retired or vulnerable package,
and `npm audit --omit=dev` found no production vulnerability. The existing
SBOM/license evidence contains the exact HUI components and assets with only
MIT and Apache-2.0 licenses.

Two clean production asset deployments produced the same complete static-tree
SHA-256,
`2f360d1cd037f8c86ef38bf484da68e4c29d2d59b24672d85ca997d4110f6347`.
The production release assembled, started twice against distinct clean
isolated stores, and stopped gracefully. No persisted product-store restart or
qualification-route production credit is claimed.

## Browser, Proxy, Offline, And Restart Conditions

The exact Playwright 1.62.0 matrix passed 21 applicable cases with 39 deliberate
profile skips across Chromium, Firefox, WebKit, Chromium without JavaScript,
and a Pixel 7 touch/narrow profile. It uses the production Vite bundle and
enforcing CSP. Coverage includes native and enhanced flows, hostile input,
closed signals, CSRF/Origin, fragments, overlay and selection continuity,
bounded SSE, multiple tabs, retry ceilings, malformed events, missing assets,
offline/stale-client recovery, browser sleep/wake and restart hints, terminal
closure, and native reconvergence.

The HTTP/1.1 proxy proves early streaming pass-through. A separate TLS edge
negotiates real HTTP/2 with Chromium, rewrites only its trusted external origin
to the internal loopback origin, keeps CSP assets on the browser-facing origin,
and proves enhanced fragments plus multi-chunk unbuffered SSE. Its committed
self-signed certificate and key are non-secret loopback test fixtures. They do
not provide production certificate, termination, capacity, or topology credit.

## Manual Accessibility Review

The adopted button, field input, link, badge, table, disclosure, dialog, and
status primitives were inspected hands-on in the Chromium accessibility tree
and visually at 1280 by 720 and 320 by 720 in light and dark themes. Landmarks,
headings, labels, table caption/headers, native disclosure state, live status,
and control names were exposed. Keyboard focus was visible. The dialog reduced
the accessible tree to the modal, placed initial focus on its close action,
closed with Escape, and returned focus to its invoker. The 320-pixel layout
reflowed without page-level horizontal overflow; the bounded table retained an
explicit local overflow surface.

The browser suite separately proves focus/selection and overlay continuity
during a sibling patch, reduced motion, forced colors, RTL, 200% zoom, touch,
and all five browser profiles. Named screen-reader speech output on every
production OS was not claimed. It is residual risk HUI-B4-R03 and must be
reviewed again for the first Milestone C product composition; the
qualification route remains absent from production.

## Residual Risks And Update Triggers

There are no local patches, forks, upstream reports, or HUI-B4 exceptions.
Five residual risks remain explicit in the machine record: Dstar's absent
upstream tests, the ShadcnUI test-only warning, named screen-reader/OS speech
coverage, production TLS/proxy capacity, and fallback-browser/nested-Babel
tooling. Each has an owner, compensating control, expiry, and version or
product-consumption update trigger.

Any dependency, source, bundle, compiler, browser, proxy, CSP, protocol,
consumer, accessibility, advisory, license, build, release, or rollback drift
reopens HUI2. The evidence is qualification for this isolated combination; it
does not authorize a product route, product authority, product effect, or
production qualification consumer.
