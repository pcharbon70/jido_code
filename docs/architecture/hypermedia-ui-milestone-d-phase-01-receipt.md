# Hypermedia UI Milestone D Phase 1 Receipt

## Status

Status: **merge-pending**

HUI-D1 implements closed, finite request/fragment delivery. It remains
merge-pending until the exact implementation head passes clean-checkout CI,
merges, and this receipt pins the full merged candidate. Phase D2 is not yet
authorized. All HUI-A through HUI-C and program HUI3 reopening conditions remain
cumulative and binding; none are weakened or reinterpreted.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted C5 closure baseline, PR #126 | `4d0e3918d732d87ebaad36e56ef90cc781e51d62` |
| Accepted C5 implementation, PR #125 | `5987a7a4a43505b035f5a566588d5201e98686f7` |
| Section 1.1: closed signal schemas | `5f2c2de7b86469af615da93e99bdd7516aff076f` |
| Section 1.2: explicit authorized handlers | `9a7228a9e04e14fed0dc6c4becbb2abfd15f3fc0` |
| Section 1.3: coherent HEEx fragments | `23a153e703108a972377f76fcddee946bd50ae1b` |
| Section 1.4 / implementation head | Pending section commit |
| Merged candidate | Pending implementation merge |

## Gate HUI-D1.1 - Closed Request Intent

Status: **merge-pending**

Ten code-owned `read_<surface>` namespaces admit only reviewed native filter,
search, sort, direction, and page intent. Account/session refresh admits no
query. The duplicate-preserving parser enforces 2,048 UTF-8 bytes, one namespace,
five fields, two object levels, no lists, 128 search bytes, page 1–100, closed
enums, NFC/trim/default normalization, and non-reflecting typed diagnostics.
Local-only pending/overlay/pause/selection intent never enters the payload.
Identity, scope, graphs, grants, assurance, revisions, fences, commands, CSRF,
and idempotency are prohibited. Unsupported cursors/views remain rejected.

## Gate HUI-D1.2 - Explicit Authorized Read Handlers

Status: **merge-pending**

Ten explicit POST controller routes reuse the accepted native queries and
typed view models. Server-side route/query/row/field authorization is followed
by fresh exact authority reconstruction after rendering and before response.
Changed policy/graph/resource/grant/session fences withhold the earlier
projection. Parent-child mismatches remain concealed. Session/account reads
revalidate the current named human; semantic effects remain native commands
outside this read boundary.

JSON, no URL query, standard header CSRF, exact Origin, same-origin Fetch
Metadata, and the enhancement header are required. Raw bodies are bounded
before generic parsing/logging. Every outcome is private/no-store/no-referrer.
The limiter admits 30 reads/minute/principal, two concurrent/principal, 16
globally, and 256 rate-window keys. Caller death and completion release leases.

## Gate HUI-D1.3 - Coherent Fragments And Native Parity

Status: **merge-pending**

One finite HTML outer morph updates `product-owned-content` with a 131,072-byte
ceiling. The existing HEEx templates render full and partial pages through the
same component. Data, state, revision, freshness, provenance, completeness,
truncation, redaction, notices, readiness, errors, accessible status, and
pagination travel together. The architecture implementation record inventories
the ten surfaces and all retained child roots, including truthful unavailable
wiki/cost/semantic capability posture and non-bearer session management IDs.

Static reviewed expressions call one local bundle action under the accepted
nonce CSP. The shell/filter stay outside the patch. Focus, selection, surviving
dialog/disclosure state, scroll, and user edits during a pending read survive.
Ordinary forms, links, query history, refresh, project switching, sign-out, and
session revocation retain native behavior. No global signals/storage confer
authority. Failed, empty, timed-out, revoked, or unavailable reads clear earlier
protected content and provide a native reload. There is no retry, stream,
subscription, server Scripts event, or second product runtime.

## Gate HUI-D1.4 - Integration Candidate

Status: **merge-pending**

Post-merge reopening: PR #127 merged as
`c73fb6d44ea305b86acc504114ac7036bbd7caa1`, but one Firefox CSP assertion passed
only on retry. Early event capture reproduced the retained Vue bootstrap policy
denial in 15/15 runs. The prior local totals below do not supersede that failure.
The [compatibility CSP repair](./hypermedia-ui-compatibility-csp-repair.md) defers
unused upstream policy creation and captures violations before navigation;
repair qualification and a newly pinned merged candidate are required before
D1 can close or D2 can start. The enforcing CSP and every gate remain unchanged.

The 28-test focused parser/controller/limiter/architecture/runtime-inventory
matrix passes. It includes 1,000 bounded fuzz inputs, all ten route namespaces,
all ten projection states, single-root and byte caps, real CSRF enforcement,
cross-origin/IDOR/concealment, revocation during shaping, rate-key/concurrency
bounds, and native placeholders. `mix precommit` passes with 1,416 tests and
zero failures in 674.4 seconds. Follow-up native and D1 checks validate the
refresh link through the existing UI facade.

The complete real-browser suite enumerates 210 browser/profile combinations:
99 applicable passes, 111 explicit profile-inapplicable skips, zero failures
in 1.8 minutes. It covers production CSP/assets, proxy/TLS, native keyboard and
no-JavaScript behavior, all ten finite read routes, coherent state/row clearing,
scope reset, latest-request wins, query history, focus/selection, disclosure,
dialog, removed-control focus, and terminal account/scope-shell clearing.

Named Orca 46.1 with Chrome 140.0.7339.80 on Linux passes both the new keyboard
filter/refresh/status journey and the predecessor's native factory/project/
attempt journey. The AT-SPI trace confirms refreshed status speech; raw traces
remain ephemeral rather than entering durable evidence. Strict production
compilation, cumulative architecture checks, and local Dialyzer pass. Dialyzer
filters the existing 178 warnings with no new finding or unnecessary filter;
the ignore file is unchanged. The pinned Datastar bundle remains SHA-256
`5d6b7794a50a83d82da962aec5e382f5ae83ac7afbc751f903f7a9c6bd433c65`.

Clean-checkout CI and the implementation merge remain pending. Reproduction:
`mix precommit`; `MIX_ENV=prod mix compile --warnings-as-errors`;
`mix dialyzer --format short`; `MIX_ENV=test mix assets.build`;
`npx playwright test`; and the D1/C5 Orca scripts under
`dbus-run-session -- xvfb-run -a bash`.

Initial fixture failures were corrected: expected IDs now match the accepted
templates; providers return the typed fixture itself; empty-state rows are
correctly absent; final patch byte bounds are tested independently of provider
field truncation. Playwright's delayed-request fixture now explicitly preserves
Fetch Metadata and requests uncompressed bytes because the Node replay path
does not reproduce browser zstd decoding. Real browser admission was never
relaxed. These failures remain recorded rather than hidden by retries.

The cumulative browser run also caught a real skip-link regression: a history
listener reloaded same-page hash navigation and lost focus. It now ignores
hash-only transitions and reloads only on path/query traversal. The full native
keyboard suites pass with this correction. Integration hardening additionally
clears the earlier account/scope/navigation shell on lost or stale authority,
and preserves the user's current focus when transport failure arrives. A
native-placeholder regression check also preserves errors, notices, and
pagination on the unenhanced operations/governance/security/knowledge routes.
The first repository run had 1,414 passing tests and one exact-source privacy
guard failure: the native `origin` referrer policy had become a conditional
expression. Separate native/enhanced clauses now retain that frozen native
contract and the stricter enhanced `no-referrer` policy without an exception.

## Limitations And Ownership

Owner: JidoCode web, identity, projection, accessibility, and operations
maintainers. No architecture exceptions are introduced. Distributed admission,
automatic SSE/coordinator behavior, multi-node sustained load, and later
Milestone D/G qualification are outside D1. The existing graph-authority
adapter is unconfigured and qualified only for fail-closed availability, not
live production grants. Step-up, recovery, semantic controls, alternative
views/cursors, and unconfigured wiki/cost capabilities remain unavailable.
The named AT support remains Orca 46.1 / Chrome 140 on Linux; other AT/OS
profiles are not implied by browser automation.

## Gate HUI-D1 Reopening Conditions

Reopen HUI-D1 whenever a predecessor gate reopens; any namespace becomes open
or authority-bearing; duplicate/unknown/malformed/oversized/deep/list/invalid
UTF-8 input is accepted; scalar, key, range, byte, or concurrency limits widen;
diagnostics reflect protected values; or local intent survives a scope change.

Reopen for generic/caller-selected handlers, unreviewed query modes, skipped
route/query/row/field/destination/post-shape authorization, stale grants,
policy/resource/graph/session revisions, cross-scope inference, optimistic
state, hidden-row retention, or semantic effects from read handlers.

Reopen for GET effects, CSRF/Origin/Fetch Metadata/content-type bypass,
identity/authority leakage in headers, URLs, logs, telemetry, caches, browser
storage, or signals, an unbounded parser/limiter/patch/deadline, missing cleanup,
or a missing/unavailable dependency being described as ready.

Reopen for incoherent root/state/data/trust/pagination updates, executable or
unescaped content, inline/remote assets, nonce/CSP drift, server Scripts,
automatic retries/streams, retained revoked content, loss of focus/selection,
dialog/disclosure/scroll/reading position, inaccessible errors/status,
keyboard/AT/reflow/touch regression, or broken native navigation/forms/history.

Reopen if an accepted path/root/schema/route/query/adapter/asset identity drifts
without fresh qualification; any limitation, owner, expiry, prohibition, or
reopening condition is removed or weakened; source/evidence digests drift;
or focused/browser/AT/security/architecture tests, production compilation,
`mix precommit`, or clean-checkout CI fail at the merged candidate.
