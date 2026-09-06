# HUI-D1 Request And Fragment Implementation

Authorized baseline: `4d0e3918d732d87ebaad36e56ef90cc781e51d62`.
Accepted HUI-C5 candidate: `5987a7a4a43505b035f5a566588d5201e98686f7`.
Owner: JidoCode web, identity, projection, accessibility, and operations maintainers.

## Closed Read Intent

Every read request has exactly one `read_<surface>` namespace. The eight graph
surfaces are `factory`, `fleet`, `projects`, `project`, `project_attempts`,
`project_wiki`, `project_dependencies`, and `attempt`; `account` and `sessions`
are identity-only surfaces. Collection queries admit `q`, `state`, `sort`,
`direction`, and `page`. Attempt reads admit only `q`, `state`, and `page`.
Account/session refresh has an empty query. Each handler has its own fixed
namespace; another page's namespace is rejected.

`ReadSignals` admits at most 2,048 UTF-8 bytes, one namespace plus five fields,
two object levels, zero list items, and 128 bytes per search scalar. Page is
1–100. State, sort, and direction use the existing native enumerations. Search
uses NFC and trimming; default values normalize to the native empty query.
Duplicate keys (including escaped names), unknown keys, invalid scalar types,
control characters, excessive depth, and oversized values return closed atom
diagnostics, never raw submitted values. Depth is checked before JSON decoding.

`_pending`, `_overlay`, `_pauseVisualUpdates`, and `_selectedRow` describe
local presentation state only and are never transmitted. All ephemeral state
is discarded on a full route/resource change. Filter submission resets page
and sort intent; pagination/sort links carry the native server-authored query.
Cursors and alternative views remain unavailable until a reviewed query
defines their semantics; sending them is rejected. No actor, session, tenant,
project authority, graph, grant, delegation, assurance, profile, fence,
revision, CSRF, idempotency, or command field is admitted.

## Explicit Read Handlers

Ten fixed POST routes under `/ui/reads` map to the existing factory, fleet,
project catalog, overview, attempts, wiki, dependencies, attempt, account,
and session controller actions. There is no caller-selected handler or query.
Graph reads use the same bounded provider and field-shaped view models as
native GETs. After rendering, trusted identity, exact parent/resource scope,
grants, policy/graph revisions, assurance, redaction, and revocation generations
are reconstructed again; a changed authority fence returns 409 without the
earlier content. Expiry/revocation returns 401, concealment 404, denial/step-up
403, unavailable authority 503. Identity-only reads validate the session anew.

Admission requires POST, JSON, no URL query, `Datastar-Request: true`, an exact
same-origin Origin and `Sec-Fetch-Site: same-origin`, and the standard browser
pipeline's CSRF token in the header. Raw JSON is bounded before generic parsing
and parameter logging; duplicate keys survive until the closed parser checks
them. Bodies never become logged controller params. Responses are private,
no-store, no-referrer, nosniff, and noindex, including transport errors.

A disposable supervised limiter admits 30 reads/minute/principal, at most two
concurrent reads/principal and 16 globally, and at most 256 rate-window keys.
Leases are released after responses or caller death. Limits return 429 with a
60-second Retry-After; missing limiter state fails closed with 503. No grant,
query result, or protected projection is stored there. These are single-node
bounds; distributed admission remains later operational scope.

## Coherent Fragment Registry

Every response is finite `text/html` using the pinned Datastar HTML patch
protocol, selector `#product-owned-content`, and outer morph mode. It is not
an SSE subscription and creates no stream/coordinator. The response closes
after one HEEx root of at most 131,072 UTF-8 bytes. Output exceeding that cap
is withheld with 503. No Scripts, signal patches, raw HTML, executable source,
inline/remote assets, or caller-selected selector/mode are emitted.

The existing native template invokes the same ProductPage content component
for full pages and fragments. One projection/query snapshot owns all children
below the root; splitting trust, rows, readiness, or pagination into separate
updates would make an incoherent intermediate state. Stable child families:

| Surface | Coherent children (existing IDs retained) |
| --- | --- |
| factory | attention trust/list, health, family coverage, fleet preview, capability truth |
| fleet | fleet trust/table, pagination, capability truth |
| projects | catalog trust/table and pagination |
| project | overview trust, repository summary/work, attempts, wiki, cost/capability posture |
| project_attempts | attempts trust/table, pagination, capabilities |
| project_wiki | wiki trust/summary, immutable-edition/enrollment and cost posture |
| project_dependencies | dependencies trust/list and capabilities |
| attempt | workspace trust/header/summary/counts/recent/semantics/capabilities |
| account | named account, assurance and recovery capability posture |
| sessions | session management/list and ordinary revocation forms |

`product-read-status` and `product-read-errors` are always children of the same
root. Projection state, revision, freshness, provenance, completeness,
truncation, readiness, redaction, notices, attempt context, and pagination
travel atomically with the shaped data. A protected/unavailable state contains
no old rows. Session row/form IDs use non-bearer management references, so a
removed session cannot transfer keyboard focus to a different session.

`ReadEnhancement` supplies only two static expressions, `@readProjection(evt)`
for delegated click/submit events. The local app bundle registers that action
under the accepted HTTP nonce CSP. It intercepts only the filter form and
same-page read links; navigation, project switching, mutation forms, modified
clicks, and reload recovery remain native. CSRF travels only in a header.
The explicit JSON payload never gathers global signals or browser storage.

Filter input and shell/navigation stay outside the patch. Immediately before
morphing, the adapter captures current focus/selection, surviving native
dialog/disclosure state, and scroll; it never restores removed content. If a
focused control disappears, the current status becomes the focus target.
Normalized filters update only when the user has not edited them in flight.
Successful reads update the native URL/canonical link and history; traversal
reloads through full route admission. A random response marker detects missing
patches, but conveys no authority and never enters request signals.

The last explicit read cancels its predecessor. Requests have a 20-second
client deadline and no retry/reconnect. HTTP, network, timeout, or missing-patch
failure removes all earlier protected children and presents a fixed local
transport alert plus an ordinary full-page reload link. No optimistic result,
cached HTML, hidden row, or authority-bearing local state is retained.

## Reopening Conditions

Reopen HUI-D1 if a signal gains authority, an unknown/duplicate/deep/oversized
input is admitted, errors reflect protected values, a page accepts another
namespace, local state survives a scope change, or an unreviewed query mode is
introduced. All HUI-C5 native behavior, authorization, privacy, accessibility,
truthfulness, and bounded-resource invariants remain binding.

Also reopen on generic dispatch, any method/CSRF/Origin/Fetch Metadata/content-
type/privacy/logging/rate bypass, stale post-shape authority, a widened patch
cap, non-coherent roots, missing row clearing, focus/selection/overlay/scroll
loss, executable content, nonce/CSP drift, automatic retries/streams, or a
broken native workflow. Unconfigured cost, semantic effects, alternative
views/cursors, and live graph authority remain unconfigured; D1 adds no claim
of support for them.
