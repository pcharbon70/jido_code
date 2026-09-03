# Hypermedia UI Dstar And Datastar Source/Protocol Baseline

- Status: HUI-B1 protocol baseline accepted; dependency and asset adoption blocked
- Recorded: 2026-09-03
- Owner: HUI-B supply-chain, request-security, asset, and stream owners
- Dstar candidate: [`v0.2.0@4bfb911`](https://github.com/ricotrevisan/dstar/tree/4bfb9110645f3831cd350f25434493c76a42bfae)
- Datastar candidate: [`v1.0.3@73ab00e`](https://github.com/starfederation/datastar/tree/73ab00e7c06d8c2bad030fdddafba800fcccbde2)
- Machine record: [`phase_b1_datastar_dstar_pairing.json`](../../priv/architecture/hypermedia_ui/phase_b1_datastar_dstar_pairing.json)

## Immutable Pair

Dstar is pinned to Hex `0.2.0`, checksum
`4766c1f3da802aa7e842aa78cbb778c8d764599e18fc67bbe32fbe25ac2c6460`,
and source commit `4bfb9110645f3831cd350f25434493c76a42bfae`. Its source archive SHA-256 is
`8ea84f50f5a9d4877f3cffad7861927d555140cdb779573b22de0d225c12d06e`.
The annotated `v0.2.0` tag is unsigned. The exact commit passed upstream tests
on Elixir 1.16/OTP 26 and Elixir 1.18/OTP 27.

Datastar is pinned to signed tag `v1.0.3`, commit
`73ab00e7c06d8c2bad030fdddafba800fcccbde2`, and archive SHA-256
`3cc36052c8036e42bbc456bcd4190a17d6644f3ae0bab7a1b8145d9a775c70cb`.
GitHub verified the tag signature from key
`210FDD28983C35883AC94DA509D799816F1CF332`; the key is not in the local
trust store, so local `git tag -v` cannot independently establish trust.

The selected client is the full standard-attribute ES module
`bundles/datastar.js`, 33,538 bytes, SHA-256
`5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65`.
Its source map has SHA-256
`78460dcfbadbd8ffd4954753fae02337d7afd6537b5975916280aa5532cfa72a`
and embeds 35 sources. The tag publishes no unminified bundle and no uploaded
release asset. The pinned tree/archive and embedded source map are the
unminified source identity; no fabricated unminified digest receives
provenance credit.

## Why Datastar 1.0.3

Dstar `0.2.0` targets the Datastar 1.0 request and SSE protocol. Datastar
`1.0.0` through `1.0.2` compile expressions with `Function`, which requires
`unsafe-eval` and conflicts with the accepted JidoCode security contract.
Datastar `1.0.3` adds an opt-in nonce mode that instead compiles expressions
through transient scripts carrying the response nonce. This makes it the
first acceptable 1.0 patch candidate; the earlier patch releases are
explicitly rejected for JidoCode's enforcing CSP.

Nonce mode activates only when the server renders a fresh nonempty
`data-nonce` on the `html` element before the module runs. Datastar removes
that attribute, applies the nonce to transient scripts, and creates a Trusted
Types policy named `datastar` where supported. HUI-B2 must prove the module,
transient expressions, Trusted Types policy, and production response work
under enforcing CSP with no `unsafe-eval`, `unsafe-inline`, or remote source.
Static reviewed expressions remain mandatory.

The tag's Taskfile invokes `pnpm` under `library`, but the release tree carries
neither a package manifest nor a package lock. Rebuilding the official bundle
from that tree alone is therefore not reproducible. HUI-B2 must vendor the
exact selected bytes into `assets/vendor/datastar/datastar.js`, import them
through `assets/js/app.js`, serve only the fingerprinted local `app.js`, and
compare source, vendor, build, and production digests. Source maps remain
production-disabled unless separately approved.

## Server Surface And Application Boundary

Dstar requires `plug ~> 1.14` and `jason ~> 1.4`, with Phoenix `~> 1.7` and
Phoenix LiveView `~> 1.0` optional. JidoCode selects only the SSE, element,
signal, and test formatting primitives. Dstar Page, Component, Router,
Page.Plug, Dispatch, dynamic module/event routing, and Scripts are prohibited
or deferred. They do not replace explicit Phoenix controllers, application
authorization, bounded coordinators, or semantic command gateways.

The default Dstar `RenameCsrfParam` pattern is also rejected for the product
path. It exposes a nonlocal `csrf` signal, and Datastar serializes all such
signals into the URL for GET and DELETE. Native forms use the normal Phoenix
token. Enhanced JSON actions must use a qualified same-origin header/body
mechanism. GET remains read-only and enhanced DELETE is avoided.

## Exact Protocol Contract

Datastar sends `Accept: text/event-stream, text/html, application/json` and
`Datastar-Request: true`. JSON signals travel in the `datastar` query
parameter for GET/DELETE and in the request body for POST/PUT/PATCH. Form mode
uses URL-encoded or multipart bodies for body-capable methods. Every enhanced
route, method, content type, signal key, nesting level, and aggregate byte
limit remains a closed application contract.

Dstar and Datastar agree on `datastar-patch-elements` and
`datastar-patch-signals`, the `outer`, `inner`, `remove`, `replace`,
`prepend`, `append`, `before`, and `after` element modes, HTML/SVG/MathML
namespaces, `onlyIfMissing`, SSE IDs, and retry fields. Dstar's CR/LF framing
and selector validation fixes are present in the pinned release. Datastar can
also map 200 `text/html` and `application/json` responses into element and
signal patches; 200 `text/javascript` execution is prohibited.

Datastar's `retryMaxCount` counts consecutive transport failures and resets
after a successful HTTP 200 response. It cannot bound a successful reconnect
cycle. JidoCode therefore owns admission, connection/queue/patch ceilings,
hard lifetime, periodic and pre-patch reauthorization, terminal revocation,
and reconnect suppression. Dstar `StreamRegistry` may help deduplicate a tab
but provides none of those guarantees.

## Gaps, Risk, And Reopening

Neither an ES2021 compiler target nor a GitHub release label is browser
qualification. The Datastar release commit has no attached check runs, and
the exact patch pair has not yet passed JidoCode's CSP, request, morph, focus,
disconnect, proxy, or accessibility matrix. Those remain adoption/release
blockers for HUI-B2 through HUI-B4. GitHub and Hex returned no repository or
package security advisories for the exact candidates at review time; that is
a time-bounded observation, not proof against transitive or future findings.

The record expires on 2026-10-03 or immediately on source, tag, bundle,
license, signature, dependency, CSP, protocol, CI, browser, or advisory drift.
It reopens if an older `unsafe-eval` client is used; a CDN/tag/branch replaces
the exact local digest; release-tree rebuildability is inferred; the default
CSRF signal enters a URL; Dstar Scripts or dynamic dispatch enter product
code; retry count or StreamRegistry is called authority; or semver replaces
the exact consumer protocol tests.
