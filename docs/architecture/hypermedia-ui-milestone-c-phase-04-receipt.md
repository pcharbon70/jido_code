# Hypermedia UI Milestone C Phase 4 Receipt

## Status

Status: **merge-pending**

This receipt records the HUI-C4 implementation candidate while review,
clean-checkout CI, merge, and immutable candidate pinning remain pending. It
does not authorize Milestone C Phase 5. A narrow closure change must replace
every merge-pending marker with the actual implementation PR, full merge SHA,
merge date, and clean-checkout job evidence before this gate can be accepted.

All HUI-B2/HUI-B4 and HUI-C1 through HUI-C3 reopening conditions remain
cumulative and binding. Nothing here weakens or reinterprets them.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-C3 closure baseline | `3515b1f3ba0c2e8dfdde0c77a2782a2873f3ee42` - closure PR #122 |
| Accepted HUI-C3 implementation candidate | `fa5203a9aefe08d741b2898a01299c7d960c80d9` - implementation PR #121 |
| Section 4.1 | `56fbb5b2c6f439f8fd9124b74d186b5bfc480169` - attention, health, fleet, and project-catalog projections |
| Section 4.2 | `528e9b975bb98ea15680a9a944503e26eb4e5a30` - project and attempt read workspaces |
| Section 4.3 | `5ef1935338473a2c8aa891e0af0d0a2f7c568189` - canonical states, refresh, cache isolation, and telemetry |
| Section 4.4 | `implementation-PR-head-merge-pending` - integrated store, controller, browser, architecture, and repository evidence |
| Implementation PR head | `merge-pending` |
| Merged candidate | `merge-pending` |

Merged candidate: `merge-pending`
Merge date: `merge-pending`

## Gate HUI-C4.1 - Attention And Fleet Projections

Status: **merge-pending**

The candidate uses the reviewed QueryCatalog protocol version `2.11.0`
through a closed query-binding adapter. Factory attention derives only from
authorized graph outcomes and covers blocked, failed, stale, budget-near,
verification-needed, approval-needed, incident, and unavailable families.
Every displayed item is bounded and shaped with safe text, opaque links,
freshness, provenance, lifecycle/readiness, and current source revision data.
No process-liveness observation becomes semantic progress or durable
acknowledgement.

Fleet discovery admits at most 100 registry candidates, scans at most 24, shows
20 rows per page, and enforces a 5.5-second surface deadline. Repository rows
are resolved against their registered graph scope, authorized before each
query, field-redacted independently, and counted only after visibility is
established. Unknown totals remain unknown; hidden projects never enter rows,
totals, facets, errors, timing dimensions, or browser state.

## Gate HUI-C4.2 - Project And Attempt Read Workspaces

Status: **merge-pending**

Project overview, attempts, wiki, and dependency pages compose independently
authorized bounded reads. Repository identity, desired/current work, attempt
summaries, evidence posture, wiki enrollment/freshness, dependency posture,
cost/budget truth, source revisions, and safe destinations are displayed only
when supported. Unavailable data is not rendered as zero, empty, healthy, or
runnable. Project aliases do not create inferred multi-repository grouping.

The attempt workspace keeps task, repository, attempt, interaction session,
artifact, effect, verification, decision, receipt, cost, candidate, and source
identities distinct. It labels plan versus observation, claim versus verified
evidence, candidate versus externally applied source, and running versus
semantic progress. Pause, stop, retry-command, approve, and other Milestone E
effects remain capability statements only; no decorative command form or
button exists.

## Gate HUI-C4.3 - Projection States, Refresh, Cache, And Telemetry

Status: **merge-pending**

Every projection family normalizes to exactly ready, empty, stale, incomplete,
contradicted, truncated, unauthorized, unavailable, maintenance, or recovery.
Legacy loading/unconfigured/error inputs normalize to unavailable;
partial/contradiction and denied/concealed normalize to their canonical safe
states. Protected states clear all rows, detail maps, summaries, capability
lists, and totals. Retryable states expose ordinary safe GET links.

The process-local cache retains fresh entries for 5 seconds, stale entries for
at most 30 seconds, and no more than 512 entries. Keys bind exact named-human
principal, bearer-session reference and generations, tenant/project/resource
scope and revision, policy/grant/delegation/obligations, graph and revocation
revisions, surface, closed query, and protocol version. Every hit is
reauthorized. Stale data forces a refresh; concealment, revocation, timeout,
and protected errors clear the entry and never fall back to hidden rows.

Telemetry permits only duration, row, truncation, and cache-hit measurements
plus closed surface/outcome/state/cache-status/query-version metadata. It
contains no principal, scope, resource, raw query, IRI, label, user input, or
other protected dimension. HTTP responses remain `private, no-store`.

## Gate HUI-C4.4 - Integrated Projection Candidate

Status: **merge-pending**

The focused matrix covers reviewed binding admission, all canonical and source
outcome aliases, bounds, sorting/filtering/pagination, contradiction, timeout,
failure, field/row authorization, copied refs, cache-key separation,
reauthorization, revocation, safe telemetry, hostile labels, unsupported
capabilities, and controller-rendered replacement behavior. A real
TripleStore fixture reconstructs factory, project, and attempt projections and
asserts the dataset revision is unchanged by all reads.

The Playwright matrix exercises the actual authenticated factory, fleet,
project, wiki, dependency, and attempt routes in Chromium, Firefox, WebKit,
Chromium without JavaScript, and narrow/touch Chromium. The browser server
intentionally has no knowledge store, proving protected rows clear and only
safe unavailable/retry UI remains. Keyboard skip/focus, semantic references,
unique IDs, native filter/retry/reload, local assets, absent semantic controls,
RTL, 200% zoom, and touch reflow are covered. Graph-backed positive rows are
kept in the separate real-store suite so no test projection provider enters
production configuration.

The 22 focused projection, controller, real-store, and architecture tests pass
with 0 failures. The exact Playwright command
`npx playwright test test/browser/hypermedia_ui_phase_c4.spec.mjs` passed 12
applicable cases, skipped 8 deliberately profile-inapplicable cases, and
failed 0 in 17.2 seconds. Strict production compilation passes without
warnings, the architecture checker passes, and `mix precommit` passes all
1,378 tests with 0 failures. Clean-checkout CI jobs and immutable PR
provenance remain merge-pending until the candidate is complete and merged.

## Configuration, Exceptions, And Limitations

There are no HUI-C4 architecture exceptions. Incident and aggregate cost
attention, interaction/receipt/cost detail, exact source dependency snapshots,
and semantic controls remain honestly unavailable when their reviewed graph
contracts or command milestones are absent. Wiki enrollment stays default-off
and an unenrolled repository does not fabricate an edition. Automated
keyboard and semantic-tree checks do not claim named screen-reader
speech-output evidence; that release evidence remains assigned to HUI-C5.

## Gate HUI-C4 Reopening Conditions

HUI-C4 remains merge-pending, and reopens after acceptance, if any predecessor
gate reopens; if a query is unreviewed, caller-authored, version-drifting,
unbounded, raw SPARQL, store-coupled from a controller, or capable of a
semantic effect; if candidate, scan, row, page, text, byte, timeout, history,
or derived-explanation bounds disappear; or if process liveness, absence of
facts, missing cost, unknown totals, or unsupported capability is presented as
semantic progress, zero, empty, healthy, complete, or runnable.

The gate reopens if route, row, field, evidence, or destination authorization
is omitted or collapsed; if principal, session/generation, tenant, project,
resource/kind/revision, exact grant, delegation, obligation, policy, graph, or
revocation scope can drift; if copied refs cross containment; or if hidden data
leaks through rows, fields, totals, facets, errors, timing, telemetry, cache
keys, URLs, logs, HTML, browser/proxy caches, DOM state, or browser storage.

The gate reopens if a protected outcome retains prior rows, maps, counts,
links, summaries, or capabilities; if stale retention becomes unbounded; if a
cache hit is trusted without current authorization; if revocation or protected
failure can fall back to cached data; if shared/browser/proxy caching becomes
possible; or if telemetry admits identifiers, free-form values, user input,
raw queries, graph IRIs, or unbounded dimensions.

The gate reopens if repository/project/attempt/interaction/candidate/source or
plan/observed/claimed/verified identities are conflated; if aliases create
unreviewed aggregation; if wiki opt-out is bypassed; if a decorative control,
POST form, LiveView, LiveVue/Vue island, client authority, inline script/event
handler, remote asset, or Datastar product behavior appears; or if native
fallback, keyboard/focus, semantic landmarks, accessible names, state
announcements, RTL, zoom/reflow, touch sizing, responsive layout, or safe retry
regresses.

The gate also reopens if source/test/browser digests drift, a test provider or
fixture reaches production configuration, any limitation or reopening
condition disappears, real-store reads change the dataset revision, or
focused tests, browser tests, strict production compilation, architecture
checks, `mix precommit`, or clean-checkout CI fails at the merged candidate.
