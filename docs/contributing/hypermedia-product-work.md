# Hypermedia Product Contribution Contract

Status: Accepted contributor guidance under HUI-A4; implementation remains
gated by the milestone receipts named below.

This contract governs new browser-product work. The deployed LiveView,
LiveVue, SaladUI, socket, route, and development-dashboard consumers remain a
tracked compatibility implementation until Milestone H proves replacement
parity and removes or explicitly retains them. Their presence is not
permission to create another consumer or to claim target readiness.

## Product Runtime Boundary

New pages, fragments, actions, exports, downloads, and streams use explicit
Phoenix routes, controllers, HTML modules, and server-rendered HEEx. Use
`Phoenix.Component` and HEEx through the application-owned component facade;
do not add a product LiveView, LiveComponent, LiveVue island, SaladUI import,
socket process, event handler, stream, hook, or client-side semantic state.

Every page uses the application layout. Every fragment has a stable,
documented root DOM ID and a bounded projection contract. Every action has an
explicit non-GET route, a closed parameter schema, a semantic command owner,
and a receipt outcome. Do not hide effects in reads, rendering, component
callbacks, JavaScript, or SSE delivery.

Ordinary anchors and forms are the baseline behavior. Datastar may enhance a
closed request after Milestones B and D qualify the exact Dstar dependency,
browser asset, CSP mode, consumer, proxy behavior, and failure semantics.
Datastar signals are untrusted, ephemeral intent. They never grant authority,
select graph IRIs, establish durable state, or provide authoritative
revisions. Patch targets and expressions are static and reviewed.

Protected SSE belongs to one application-owned coordinator. Authentication,
scope construction, and initial authorization finish before streaming starts.
The coordinator sends a current authorized snapshot, reauthorizes and
requeries before every protected patch, bounds lifetime and patch size, and
on revocation emits the policy-safe terminal replacement, closes the stream,
suppresses privileged reconnect, and clears privileged browser state.

## Identity And Authorization

Build authority only from the trusted named-human mapping boundary. Bind the
current human account, authenticator and browser session, assurance and
authentication age, exact tenant/project/resource containment, exact graph
grants, optional exact delegation, classification, environment, lifecycle,
incident posture, policy revision, graph revisions, and applicable fence.

Route admission is not enough. Reauthorize before the query, before field
shaping, before stream subscription, before every protected patch, before
command construction, inside the semantic command gateway, before approval
commit, before export creation, and before every export or download retrieval.
Never union roles, scopes, sessions, or tabs. Parallel sessions converge only
through server-owned optimistic revisions and explicit winner, idempotent,
conflict, stale, or revoked receipts.

Use the policy result exactly. Conceal resource existence with the accepted
not-found outcome when required, redact before rendering, require current
step-up for the exact high-risk action, and enforce separation of duty for
approval. A disabled button is explanatory UI, not an authorization control.

## Knowledge, Commands, And Receipts

Web code consumes reviewed, bounded projection/query contracts. It must not
read Knowledge internals, open TripleStore, submit raw SPARQL, call low-level
writers, accept caller-selected graphs, or expose raw RDF/store handles.
Graph-lens requests use the closed lens registry, task-specific bounded
datasets, source/revision/limit labels, and a table or text alternative; a
universal unrestricted graph browser is prohibited.

All durable effects enter through an accepted semantic command gateway with a
closed command type/version, server-recomputed actor and authority, exact
resource/action, graph topology, expected revisions, provenance, validation,
and atomic immutable receipt. Browser success is never optimistic. UI state
comes from the committed receipt and a fresh authorized projection.

Repository wiki work also preserves default-off enrollment,
repository/tenant/same-repository-session isolation, immutable edition and
source identity, one logical maintainer profile, deterministic-only
zero-model-call behavior, exact token reservation and usage/cost attribution,
hard aggregate budgets, opt-out, and review/activation/release separation.

## Forms, Assets, Security, And Accessibility

Controllers or HTML modules create `Phoenix.Component.to_form/2` values;
templates render `<.form for={@form}>` and `<.input>` fields. Give forms,
controls, fragment roots, status regions, and stream roots stable unique IDs.
Native forms carry the accepted CSRF token, use the real HTTP method, and
remain usable without Datastar. Enhanced requests additionally enforce the
accepted same-origin/Origin rule. GET must remain safe and idempotent.

Only the local `app.js` and `app.css` bundles may execute or style the product.
Pin every dependency and asset by version, source, license, lock/archive
identity, and digest before adoption. Do not load CDN or remote product
scripts/styles, add inline scripts or inline event handlers, evaluate dynamic
Datastar expressions, or treat CSP as a substitute for HEEx escaping and
explicit sanitization. User, source, wiki, graph, log, model, and agent content
is data, never executable markup.

Preserve keyboard operation, visible focus, semantic headings and landmarks,
labels and descriptions, live-status announcements, reduced-motion behavior,
contrast, responsive bounds, and accessible table/text alternatives for
visualizations. Preserve focus across patches when the target remains valid;
otherwise move it predictably and announce the changed state.

## Testing And Evidence

Use `Phoenix.ConnTest` for controller outcomes and `LazyHTML` selectors for
stable HTML contracts. Test native form behavior before enhancement. Add
negative authorization, concealment, redaction, stale revision, CSRF, Origin,
oversized input, double-submit, revocation, reconnect, conflict, injection,
and unavailable-state cases. Use real browser, assistive-technology, proxy,
identity, TripleStore, command, filesystem, and network seams when the owning
milestone requires that evidence; a mock, screenshot, badge, or prose claim
cannot replace a required real seam.

Before merge, run focused tests, `mix architecture.check`, the applicable
security/documentation/release suites, and `mix precommit`. The implementation
pull request must pass clean-checkout CI. Evidence records pin the candidate,
tree, toolchain, dependency/lock, asset, configuration, browser/proxy,
fixture/corpus, graph protocol, adapter identity, deterministic inputs,
findings, limitations, owner, and independent reviewer.

## Exceptions, Operations, And Phase Closure

An architecture exception is valid only when the checked-in record names its
owner, reason, exact path and symbol, expiry, evidence, and gate-reopening
condition. It may not authorize a directory, pattern, future consumer, or
readiness claim. Expired, widened, unmatched, or unreviewed exceptions fail
closed. Current compatibility consumers follow the exact HUI-A3 consumer
manifest and the Milestone H removal conditions.

Update the threat model, capacity limits, CSP, proxy configuration, runbooks,
install/upgrade/rollback instructions, telemetry, alerts, and migration
manifest whenever their boundary changes. Preserve the last qualified
rollback artifact until the accepted rollback window closes. Never delete a
compatibility consumer merely because a milestone label was reached.

Implement each numbered plan section as one commit and use one implementation
pull request per phase. A phase receipt remains merge-pending until that pull
request passes clean-checkout CI and merges. Then a narrow closure pull request
pins the full merge SHA/date, transitions the receipt and gate coherently,
checks only the prescribed closure boxes, and preserves every reopening
condition. Sync local `main` from `origin/main` before deleting each merged
branch. The next phase starts only from the pinned closure baseline.

## Required References

- [HUI-A2 identity and authorization contract](../architecture/human-identity-scope-and-authorization-contract.md)
- [HUI-A3 runtime supersession contract](../architecture/hypermedia-ui-runtime-contract-supersession.md)
- [HUI-A3 validation and release evidence contract](../architecture/hypermedia-ui-validation-and-release-evidence-contract.md)
- [Graph-native fitness checks](./graph-native-fitness-checks.md)
- [Hypermedia UI program plan](../planning/secure-hypermedia-control-plane-ui/README.md)
