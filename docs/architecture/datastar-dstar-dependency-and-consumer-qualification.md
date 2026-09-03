# Datastar And Dstar Dependency And Consumer Qualification

- Status: Accepted qualification contract under ADR 0008; dependencies remain unqualified
- Specification version: `1.0.0`
- Accepted: 2026-09-03 through HUI-A3 merged-candidate governance
- Owners: JidoCode web, security, supply-chain, and operations maintainers
- Milestone: B — Dependency And Consumer Proof
- Decision: [ADR 0008](../adr/0008-server-rendered-heex-and-datastar-product-runtime.md)
- Inspected Dstar source:
  [`v0.2.0@4bfb911`](https://github.com/ricotrevisan/dstar/tree/4bfb9110645f3831cd350f25434493c76a42bfae)

## Purpose

This specification defines the evidence required before Datastar or Dstar can
enter product code. It proves dependency provenance, protocol compatibility,
assets, CSP, CSRF, fragments, streams, errors, reconnect, and cleanup in a
small consumer without claiming that the libraries provide product authority.

## Immutable Dependency Record

Record for Dstar and Datastar separately:

- package/repository, version/tag, source commit, archive/bundle filename;
- source/archive/browser-bundle digest and license;
- Elixir/Phoenix/Plug and browser compatibility;
- build/import path into `app.js` and `app.css`;
- CSP evaluator mode and nonce contract;
- request/signal/SSE protocol assumptions; and
- upstream docs/tests used as evidence.

Dstar `0.2.0` examples target Datastar `v1.0.0`; the selected browser bundle
MUST still be recorded and tested exactly. Versionless online documentation is
not a compatibility pin.

## Consumer Spike Boundary

The spike uses explicit Phoenix routes and application-owned handlers to prove:

1. a complete authenticated HEEx page;
2. a bounded form with native POST fallback and Phoenix CSRF;
3. a Datastar-enhanced request with a closed signal schema;
4. stable element patch, append/upsert where allowed, nudge, and remove;
5. one authorized page/tab SSE coordinator and initial snapshot;
6. disconnect, bounded retry/backoff, reconnect, takeover, and convergence;
7. hard expiry and independent revocation;
8. native overlay/focus preservation during a sibling patch;
9. CSP nonce mode with no `unsafe-eval` or external asset; and
10. sanitized error handling with Dstar debug errors disabled outside dev.

The spike does not call Factory or Knowledge production commands and creates no
new durable graph resource.

## Security Constraints

- Authorization and concealment complete before `Dstar.start/1`.
- Page/event names are closed and cannot select arbitrary modules/functions.
- Every non-local signal is sent by default, so the page defines allowed keys,
  namespace, nesting, aggregate bytes, and per-action subset.
- CSRF is read from protected page context and sent through the qualified
  header/body mechanism without becoming a transmitted non-local signal.
- GET has no effect. Mutations use POST/PUT/PATCH bodies; DELETE is avoided if
  the selected transport serializes signals into the URL.
- The Dstar Scripts surface is prohibited by default. Fetch-backed 30x does
  not count as top-level navigation.
- `StreamRegistry` is optional deduplication only. Missing/invalid tab IDs and
  claim races are separately limited and tested.
- Retry count, delays, queue, event/patch bytes, heartbeat, connection count,
  lifetime, and cleanup are explicit and bounded.

## Deployment Matrix

Qualification covers Bandit/Plug behavior, TLS/HTTP2, supported reverse proxy,
proxy buffering disabled where required, keepalive, deploy restart, browser
background/sleep, several tabs, session expiry, revocation, server overload,
and fallback when live delivery is unavailable.

## Acceptance Evidence

The gate requires pinned consumer fixtures, exact headers/bodies/SSE events,
browser tests, hostile signal/expression/content cases, CSRF/Origin/Fetch
Metadata tests, CSP report-only then enforcing evidence, resource/connection
metrics, and clean-checkout CI.

## Reopening Conditions

The gate reopens on Dstar/Datastar/Phoenix/Plug/browser/proxy version drift;
bundle digest change; CSP or signal behavior change; unbounded retry/queue;
authorization after response start; CSRF in URL/logs; script-surface use;
reconnect after terminal revocation; or leaked exceptions/source/paths/secrets.
