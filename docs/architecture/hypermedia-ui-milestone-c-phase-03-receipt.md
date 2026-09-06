# Hypermedia UI Milestone C Phase 3 Receipt

## Status

Status: **accepted-at-merged-candidate**

This receipt accepts HUI-C3 only at merged implementation candidate
`fa5203a9aefe08d741b2898a01299c7d960c80d9`. Implementation pull request #121
passed the required clean-checkout verify and Dialyzer jobs and merged on
2026-09-05. This narrowly scoped closure transition pins that immutable
candidate and authorizes Milestone C Phase 4 subject to every reopening
condition below.

All HUI-B2/HUI-B4, HUI-C1, and HUI-C2 reopening conditions remain cumulative
and binding. Nothing here weakens or reinterprets them.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-C2 closure baseline | `7c77e2270cf754b6a04d5f95e12ca070083902ae` - closure PR #120 |
| Accepted HUI-C2 implementation candidate | `da7ab6a4478bb278aa31a7636fa92135843249ff` - implementation PR #119 |
| Section 3.1 | `4720fb46145e9d46d1c856b8516a8d946bbbb03b` - explicit authenticated route groups |
| Section 3.2 | `26360a536c5082477235f08c31cb425b5653473f` - native product shell and view models |
| Section 3.3 | `c7d4621ba666b6e180c3f6b6afd5d617d9b9159e` - native identity and session workflows |
| Section 3.4 | `306405e0e01d76a856b4c33639bd3b79744e02c2` - integrated route, browser, architecture, and repository evidence |
| Implementation PR head | `306405e0e01d76a856b4c33639bd3b79744e02c2` - implementation PR #121 |
| Merged candidate | `fa5203a9aefe08d741b2898a01299c7d960c80d9` - merge commit for implementation PR #121 |

Merged candidate: `fa5203a9aefe08d741b2898a01299c7d960c80d9`
Merge date: `2026-09-05`

## Gate HUI-C3.1 - Explicit Authenticated Route Groups

Status: **accepted-at-merged-candidate**

The candidate owns explicit Phoenix controller actions and HEEx templates for
factory attention/fleet, project catalog/overview/attempts/wiki/dependencies,
attempt workspace, closed knowledge lenses, candidate review, operations,
costs, security/incidents, governance, account, and session pages. `/factory`
is the new native shell entry; the existing `/` `HomeLive` route remains a
compatibility-only rollback dependency until its HUI-G qualification and HUI-H
cutover/removal gates close. No new product LiveView, catch-all action,
fragment, stream, island, or semantic command is introduced.

Every handler accepts only bounded opaque registry refs and closed query/lens
values. Project and child routes authorize the project and child separately,
then repeat kind, parent, tenant, and conceptual-project containment checks.
Candidate, attempt, interaction-session, wiki-preview, and graph identities
remain distinct registry kinds. Unknown, malformed, wrong-kind,
cross-project, and unauthorized references retain the same concealed 404
exterior.

Protected responses are private/no-store and origin-only referrers disclose no
path or query. Origin-only, rather than `no-referrer`, is required because
Chromium serializes ordinary form POSTs as `Origin: null` under
`no-referrer`; the accepted policy retains an exact verifiable Origin while
preventing path/query referrer leakage. Trailing slashes redirect canonically,
absolute canonical links omit unrecognized intent, and invalid bounded filter
values render a linked error summary without becoming authority.

## Gate HUI-C3.2 - Full-Page Shell And Server View Models

Status: **accepted-at-merged-candidate**

`JidoCodeWeb.ProductPageViewModel` shapes current named-human display,
assurance, route, exact membership explanation, independently authorized
navigation, project/attempt context, readiness, freshness, notices, account
links, and support metadata. Role labels explain accepted results only. Every
navigation and project-switch candidate is independently reauthorized before
presentation; registry enumeration is bounded to 50 and never rendered before
authorization.

`JidoCodeWeb.Components.ProductPage` composes the accepted application shell,
masthead, primary/utility/responsive navigation, project switcher, context,
breadcrumbs, page header, attempt context, service banner, bounded native GET
filter/search, error summary, pagination, empty state, native sign-out, and
footer components. Stable IDs, one H1, skip/focus targets, canonical title,
current-location semantics, landmarks, native history/reload/bookmark
behavior, and flash ownership remain explicit.

Project switching accepts only `project_switch[project_ref]`, reauthorizes the
selected project, and redirects to its overview so attempt/candidate/preview,
lens, cursor, filter, and page selections are cleared. Filter and pagination
forms contain no actor, authority, assurance, grant, scope, delegation,
revision, graph, incident, fence, or generation field.

## Gate HUI-C3.3 - Native Authentication And Session Workflows

Status: **accepted-at-merged-candidate**

Sign-in, sign-out, account, sessions, step-up, and recovery use ordinary
controller routes and `to_form/2`/HEEx forms with CSRF and exact Origin
enforcement. Parameter schemas and lengths are closed, return targets are
bounded and local, credential-like log parameters are filtered, password
manager autocomplete is explicit, authentication errors are generic, and
recovery responses do not confirm account existence.

Session management shows at most 20 active same-account summaries and supports
ending the current, one other, or all sessions. HTML never receives a bearer
session ref. Per-session forms use a SHA-256 preimage-resistant management ref
derived from the random bearer; it cannot authenticate a browser and is
atomically resolved only within the current account. Revocation, logout-all,
session rotation, concurrent tabs, expired/revoked session redirects, and
safe cache/back-button behavior are covered by controller and identity tests.

The accepted production capability remains honest: local baseline identity is
the configured authenticator, while phishing-resistant step-up and independent
recovery are unavailable until configured. The UI does not solicit a step-up
secret or simulate elevation when unavailable. Recovery gives generic,
independently verifiable operator guidance and performs no account lookup or
credential change in the unconfigured posture.

## Gate HUI-C3.4 - Integrated Route And Native-Browser Candidate

Status: **accepted-at-merged-candidate**

The 29 focused controller, identity, and architecture tests pass and cover
route ownership, exact authorization, kinds and
containment, deep-link return, malformed/unknown concealment, query bounds,
canonicalization, shell landmarks, independently authorized navigation,
project switching, search/filter/page intent, title/focus/current semantics,
safe HTML fields, sign-in/step-up/recovery posture, current/other/all session
revocation, and concurrent-session invalidation.

The exact Playwright command
`npx playwright test test/browser/hypermedia_ui_phase_c3.spec.mjs` passed 14
applicable cases, skipped 11 deliberately profile-inapplicable cases, and
failed 0 in 18.6 seconds across Chromium, Firefox, WebKit,
Chromium-with-JavaScript-disabled, and narrow/touch Chromium. It exercised the
actual authenticated product routes and test-only trusted registry bootstrap:
all route groups, project/attempt/candidate deep links, concealed refs,
project switching, GET filtering/pagination, back, reload, native sign-out,
recovery, step-up truth, keyboard skip/focus, unique IDs, canonical links,
RTL, 200% zoom, touch reflow, responsive navigation, local assets, and absent
inline event handlers.

Automated keyboard and semantic-tree checks do not claim named screen-reader
speech-output evidence. That release evidence remains assigned to HUI-C5.
Phase 4 projection data is intentionally not present: authorized pages state
that projections are unconfigured and never render invented rows.

## Configuration, Exceptions, And Limitations

There are no HUI-C3 architecture exceptions. Two project/attempt/candidate
trees exist only in `config/test.exs` to exercise trusted registry resolution
and native browser workflows; they are not production resources or grants.
The production graph-authority adapter, phishing-resistant step-up provider,
and recovery provider remain explicitly unconfigured. No page claims a real
attention, fleet, project, attempt, wiki, dependency, review, cost, incident,
or governance projection before HUI-C4.

The strict production compile and architecture checks pass. The repository
precommit gate passes all 1,356 tests with 0 failures. On implementation PR
#121, clean-checkout Dialyzer job `101382702919` passed in 2m30s. Verify's first
run encountered the existing `GraphTopologyTest` temporary-directory cleanup
race after completing the suite; its unchanged-head rerun job `101385012698`
passed in 20m10s. These exact results and immutable PR/merge provenance are
recorded in the executable HUI-C3 manifest.

## Gate HUI-C3 Reopening Conditions

HUI-C3 reopens after acceptance if any
predecessor gate reopens; if a C3 controller page becomes LiveView/LiveVue/Vue,
catch-all, client-routed, inline-scripted, remotely sourced, or Datastar-owned;
if any route lacks an explicit controller/action/template, route admission,
exact response authorization, canonical identity, or safe unavailable state;
or if a GET produces a semantic effect.

The gate reopens if a parameter, header, cookie field, query, DOM value,
browser storage value, signal, hidden input, role, navigation item, or disabled
control supplies identity, scope, authority, grant, delegation, assurance,
classification, graph/revision, incident, generation, or containment; if refs
are unbounded, caller-selected in kind, conflated, enumerable before
authorization, or retained across a scope change; if project and child
authorization is collapsed; or if unknown and unauthorized exteriors diverge.

The gate reopens if navigation includes an unconfirmed destination, unions
roles or sessions, or grants from visibility; if project switching retains
attempt/candidate/preview/lens/cursor/filter/page selection; if title, H1,
landmarks, skip/focus target, breadcrumbs, current-location, error summary,
responsive navigation, native fallback, keyboard operation, RTL, zoom/reflow,
touch sizing, back/forward, reload, or bookmark behavior regresses; or if
protected content enters canonical URLs, referrers, caches, logs, telemetry,
or browser storage.

The gate reopens on session fixation, missing rotation, CSRF or Origin bypass,
unsafe return targets, account enumeration, secret logging, bearer refs in
HTML/URLs, cross-account session management, stale/concurrent revocation,
logout-current/all failure, cache restoration of authenticated content,
simulated assurance, recovery without independent evidence, or unavailable
identity capability presented as ready. It also reopens if source/test/browser
digests drift, the test-only registry fixture reaches production, any
limitation or reopening condition disappears, or focused tests, strict
production compilation, architecture checks, `mix precommit`, or
clean-checkout CI fails at the candidate.
