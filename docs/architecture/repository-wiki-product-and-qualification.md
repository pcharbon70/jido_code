# Repository Wiki Product And Qualification Specification

- Status: Approved and normative under accepted ADRs 0005, 0006, and 0007
- Specification version: `0.2.0`
- Owners: JidoCode product, knowledge, security, and release maintainers
- Decisions:
  [ADR 0005](../adr/0005-repository-wikis-as-compiled-knowledge-projections.md),
  [ADR 0006](../adr/0006-per-repository-wiki-maintainer-agents.md), and
  [ADR 0007](../adr/0007-repository-wiki-enrollment-and-cost-governance.md)
- Enrollment and accounting: [Repository wiki enrollment, budget, and accounting](./repository-wiki-enrollment-budget-and-accounting.md)
- Extends:
  [Product surface and island contract](./product-surface-and-island-contract.md),
  [product security and privacy](./product-security-privacy-and-threat-model.md),
  and [fleet capacity, retention, and observability](../operations/fleet-capacity-retention-and-observability.md)

## Purpose And Product Posture

This specification defines how humans and coding agents discover, navigate,
trust, search, review, refresh, and evaluate one repository wiki. The wiki is a
knowledge product inside the existing repository workbench, not a raw graph
browser, generic content management system, or separate authority plane.

The target product owns the wiki beneath
`GET /projects/:project_ref/wiki/...` through explicit controllers, HEEx, and
reviewed fragments. The deployed `GET /` workbench remains a compatibility
surface until route cutover. A route or query parameter is presentation
selection only. It never selects a graph, command, query text, actor, tenant,
source revision, or visibility rule.

## User Outcomes

For an authorized repository, a user can:

- understand what the project is, its exact current source, version/toolchain
  posture, architecture, major source areas, and operational boundaries;
- navigate all discovered user, developer, operator, contributor, upgrade,
  release, ADR, and reference documents;
- view all admitted Mix dependencies, their scope and parentage, why they are
  present, exact resolved identities, verified docs/source/project links, and
  explicit metadata gaps;
- distinguish repository-authored text, deterministic extraction,
  synthesized explanation, accepted graph knowledge, live status, and gaps;
- follow citations back to an authorized exact source or graph projection;
- see freshness, completeness, compiler/profile, source snapshot, warnings,
  and edition history;
- search and traverse internal links/backlinks without crossing repository or
  tenant boundaries;
- preview an exact candidate wiki when separately authorized without exposing
  concurrent sessions on the same repository;
- opt out, select manual or automatic maintenance, choose deterministic-only
  or synthesis-enabled generation, and inspect token/cost exposure;
- request a refresh, review, or documentation task through finite semantic
  intents; and
- understand why content is stale, incomplete, contradicted, truncated,
  unavailable, or concealed.

## Navigation And Information Architecture

The repository workbench adds `Wiki` alongside the accepted areas. The wiki
landing page presents a bounded hierarchy:

```text
Repository wiki
  Overview
    Project
    Architecture
    Source and tests
  Guides
    User
    Developer and contributor
    Operator, upgrade, and release
  Dependencies
    Complete index
    Direct and transitive detail
  Decisions and research
    ADRs
    Research notes
  Operations and releases
  Known gaps and drift
  About this wiki
```

The hierarchy is a versioned page projection, not a directory walk performed
by the browser. Empty categories show explicit coverage/gap state. Product
navigation uses opaque presentation references that the server decodes,
authorizes, validates against the selected repository and edition, and then
passes to a reviewed query.

Direct URL entry, browser history, stale island state, guessed slug, dependency
name, source path, or copied reference grants no visibility. Unknown and
unauthorized resources have the same concealment-oriented presentation.

## Page Presentation Contract

Every page begins with a compact trust header containing:

- page title and kind;
- repository presentation identity;
- edition purpose and root abbreviation;
- exact source revision abbreviation and immutable-source action when
  authorized;
- active/preview/release/historical badge;
- freshness and completeness state;
- last compilation and source-observation times;
- authored/deterministic/synthesized/live/gap section legend; and
- warnings, review requirement, or replacement edition availability.

Each section visibly labels its authority class. Synthesized sections expose
their citation count, uncertainty/warnings, and bounded “how this was built”
detail. Authored guides expose exact path and revision and are rendered as
repository-authored content. Live panels display their evaluated time and may
fail independently.

Citation interaction returns only authorized bounded detail: source type,
exact revision/digest, safe locator, claim role, and a verified action to the
source or product projection. It never reveals a raw graph IRI, SPARQL,
absolute checkout path, hidden resource label, secret, or unauthorized
snippet.

## Projection States

Wiki surfaces use the existing product states:

- `ready`;
- `empty`;
- `stale`;
- `incomplete`;
- `contradicted`;
- `truncated`;
- `unauthorized`;
- `unavailable`;
- `maintenance`; and
- `recovery`.

Wiki-specific reasons refine, but do not replace, those states:

| State | Example safe reason | Required behavior |
| --- | --- | --- |
| `empty` | `not_compiled` or `no_authored_guides` | Explain scope and offer an authorized refresh/task action |
| `stale` | source head, metadata, or compiler profile advanced | Keep permitted content visibly stale or conceal under policy; never label current |
| `incomplete` | unsupported Mix semantics, source bound, missing artifact | Show exact bounded gaps and affected coverage |
| `contradicted` | static/dynamic, source/docs, or metadata conflict | Preserve both attributed observations and block false synthesis |
| `truncated` | page, citation, dependency-parent, or search bound | Show continuation only through reviewed cursor/reference |
| `unavailable` | store, provider, artifact, sandbox, or model outage | Clear affected streams; do not use browser/process state as fallback |
| `maintenance` | compilation, lint, review, or activation pending | Show last permitted edition and pending posture without inventing progress |
| `recovery` | ambiguous effect or restore validation | Disable consequential actions until reconciled |

An authored page may be ready while its live panel is unavailable. The UI
preserves component-level state rather than flattening the whole wiki into a
misleading success or failure.

## Search Contract

Search is repository-first and authorization-before-candidate. The server:

1. resolves authenticated actor, tenant, selected repository, active or exact
   preview edition, visibility, and evaluated dataset revision;
2. validates the bounded normalized search term without atom creation;
3. runs one reviewed repository-scoped candidate query;
4. ranks only returned authorized candidates using an application-owned
   deterministic profile;
5. returns bounded opaque page/section references with safe snippets,
   source-class labels, freshness, and truncation; and
6. reauthorizes a selected result on page read.

The first release does not require embeddings. If semantic/vector search is
later introduced, its index is disposable, partitioned by repository and
authorization class, built only from authorized/redacted text, bound to exact
edition roots, and never the durable wiki. Cross-repository top-k candidate
generation is forbidden even if post-filtered.

Search input cannot become SPARQL, a regular expression without fixed safety,
an arbitrary source path, an external search query, a model prompt with
unbounded context, or a command.

## Dependency Experience

The dependency index provides bounded filters for direct/transitive,
environment, target, SCM, metadata freshness, and completeness. Filters are
closed server-validated values and do not alter edition completeness.

Each dependency page shows:

- exact resolution and lock provenance;
- direct declaration and requirement when present;
- all admitted environments and targets;
- parent set and bounded canonical “why present” paths;
- source-analysis use examples with exact citations;
- description, license, retirement, and metadata observation state;
- verified package, exact docs, immutable source, homepage, changelog/release,
  issue, license, and advisory actions when available; and
- explicit gaps for missing, private, stale, unsupported, or unverifiable
  information.

External actions use safe fixed link components and server-admitted HTTPS
URLs. User-supplied and model-supplied HTML is never rendered. A missing exact
documentation link is not silently replaced by “latest.”

## Guide Experience

The guide index groups discovered repository-authored content by audience and
purpose. Every guide retains its exact path, revision, digest, source action,
rendering status, and authored label. The wiki may add a generated abstract,
outline, related pages, backlinks, prerequisites, freshness, and drift, but
the generated material is visibly separate.

Unsafe or unsupported markup renders as bounded plain text or an unavailable
state; it is never injected directly. Relative links are normalized against
the exact repository snapshot and validated. Images/artifacts use verified
content boundaries and policy. External scripts, inline scripts, arbitrary
styles, active embeds, and repository-controlled client hooks are forbidden.

When user, developer, operator, contributor, upgrade, security, or release
guidance is missing, the product shows the gap and an authorized “propose
documentation work” action. It does not generate a source-authored-looking
guide or let the wiki maintainer commit one.

## Candidate Preview And Review

Preview access requires exact coding-session, attempt, candidate, fence, and
audience authorization. Repository access alone is insufficient. The shell
and every page show a persistent `candidate preview` badge, session-safe
presentation reference, base/source identity, candidate digest, verification
posture, and expiry. Preview results do not enter current navigation, ordinary
search, agent default context, or public source links.

When an actor has more than one authorized parallel session, preview selection
uses an opaque session-scoped reference. Switching repository, session,
attempt, candidate, fence, or edition clears page/search/review selections and
rendered fragment rows before re-query. Counts, slugs, backlinks, notifications,
cache keys, and PubSub hints cannot reveal sibling-session preview existence.

Review surfaces show:

- source and input identity;
- predecessor-to-candidate page manifest changes;
- authored guide changes separately from generated changes;
- added/removed/changed citations and external links;
- synthesized sections and uncertainty;
- dependency graph/link differences;
- gaps, drift, lint findings, and truncation;
- required reviewer class and prior approvals bound to the exact root; and
- activation readiness without an activate-by-generator control.

Approval is a finite semantic form with exact edition, review profile,
expected revisions, reason, and idempotency. Browser-supplied graph, actor,
query, policy, source, command version, or approval scope is ignored.

## Enrollment And Cost Experience

An unconfigured repository shows wiki creation as `Off`; it does not show a
spinner or imply that compilation is pending. The rest of the repository
workbench remains fully available.

Authorized settings expose independent controls for:

- `Off`, `Manual`, or `Automatic` maintenance;
- `Deterministic only` or `Allow cited synthesis` generation;
- candidate-preview permission;
- existing-edition read and retention posture; and
- finite invocation, edition, preview/session, repository, and time-window
  token/cost ceilings available to that actor.

Before enabling synthesis or submitting a manual synthesized refresh, the UI
shows the exact provider/model, pricing observation and limitations, maximum
admitted calls/tokens/money, remaining aggregate budget, and whether any
dimension is estimated or unavailable. Confirmation binds the exact profile,
pricing, budget, and graph revisions and expires when any changes.

Edition and repository cost views distinguish provider-reported, gateway-
measured, estimated, unavailable, and contradicted tokens; calculated charge;
outstanding reserved exposure; current/release/recovery/preview purpose; and
the applicable window boundary. Deterministic-only editions say `Zero model
calls and tokens`, not `Free`, unless broader infrastructure accounting proves
that statement.

Opt-out commits before runtime cancellation. The UI explains that already
dispatched calls may still incur attributable cost, unresolved reservations
remain held, and existing editions are retained or concealed according to a
separate policy. It never claims that opt-out erased prior spend.

## Controls And Feedback

Initial durable actions are limited to:

- configure or disable repository wiki generation when authorized;
- request wiki compilation/refresh;
- request exact candidate preview when eligible;
- cancel an authorized compilation;
- record an edition review decision;
- request retry/reconciliation where the effect contract allows;
- propose a documentation or drift-remediation task; and
- operator-only profile transition, invalidation, or rollback selection.

The owning controller resolves and reauthorizes every intent against current
graph state, then submits it through the semantic command gateway. Optimistic
browser updates cannot claim compilation, closure, review, or activation
success.

The product never offers arbitrary page editing for generated wiki content.
Repository-authored documentation changes follow the normal coding workflow.
Feedback about a generated explanation becomes a bounded finding or proposed
work item with citations; it does not mutate the closed edition.

## Agent Consumption Contract

Coding and verification agents may consume the wiki only through a bounded
`RepositoryWikiContext` projection. It pins:

- coding session/attempt and audience when context is session-scoped;
- repository and exact active or explicitly authorized preview edition;
- evaluated dataset revision, source snapshot, edition root, and freshness;
- selected page/section/citation identities and content digests;
- authority class, uncertainty, omissions, and truncation for every section;
- live-query identity and evaluation time when live facts are included;
- context-selection query/profile and complete token/byte counts; and
- explicit exclusions.

Retrieval is task- and scope-specific. The context builder prefers exact
authored/deterministic facts and small citation neighborhoods. It cannot turn
wiki prose into policy, tool instructions, verification evidence, or source-
write authority. Agents are instructed and structurally constrained to treat
page content as untrusted data.

The context is immutable for that session/attempt. A newly activated wiki does
not silently alter a running session's prompt or evidence. Explicit refresh
creates a successor context package with a new digest, preserves the prior
context provenance, and reauthorizes every selected page. Sibling sessions can
therefore advance independently without sharing mutable context state.

The wiki is helpful context, not proof that a candidate is correct. Verifiers
use fresh source and registered checks independently.

## Privacy And Security

Product conformance MUST address:

- cross-repository/tenant page, search, backlink, dependency, citation,
  edition-history, preview, artifact, and cache disclosure, including between
  parallel sessions on the same repository;
- repository-controlled markup, prompt injection, unsafe links, Unicode
  spoofing, path traversal, and oversized content;
- synthesized secret memorization, fabricated citation, attribution confusion,
  and hidden instructions;
- external-link SSRF/open redirect, private package metadata, and mutable
  destination risk;
- visibility changes, actor revocation, stale browser references, and shared
  client/cache state; and
- logging, telemetry, error, server-render assign, signal, patch, and DOM
  leakage.

Server projections contain only the minimum presentation values. HEEx
fragments and Datastar signals receive JSON-safe labels, opaque identities,
counts, freshness, completeness, truncation, and finite presentation intent.
They never receive RDF, SPARQL, graph names/handles, credentials, provider
sessions, raw source bodies, complete dependency graphs, or a writer.

## Accessibility And Interface Requirements

The wiki MUST remain usable through native server-rendered HTML and support
keyboard navigation, visible focus, semantic headings/landmarks, reduced
motion, sufficient contrast in light/dark/system modes, and accessible labels
for freshness, authority, warnings, citation popovers, filters, and external
links.

Color alone never indicates authored versus generated content, current versus
preview, completeness, or severity. Loading states retain layout and announce
progress without claiming semantic completion. Collections are server-bounded,
paginated, and rendered beneath stable unique DOM and fragment IDs; empty and
count state come from the same reviewed projection envelope.

## Qualification Unit

Qualification applies to one immutable tuple:

```text
wiki protocol
+ ontology/shape/graph-registry versions
+ compiler/page/renderer/redaction/link/lint profiles
+ source-analysis and Mix profiles
+ metadata adapter/provider revisions
+ reviewed query/projection versions
+ maintainer runtime/tool profile
+ repository generation/budget/accounting profile
+ provider/model pricing profile
+ optional model/profile/prompt revision
+ product build and rollout policy
```

A change to any material member creates a new qualification unit. Prior
evidence cannot be generalized to an untested provider, model, toolchain,
sandbox, repository class, page schema, or visibility mode.

## Evaluation Corpus

The corpus MUST contain, at minimum:

- small, large, umbrella, private, sparse-doc, rich-doc, and legacy Elixir
  repositories;
- multiple repositories compiling simultaneously under at least two tenants,
  plus multiple sessions with divergent candidates on one repository;
- unconfigured, opted-out, manual, automatic, deterministic-only,
  synthesis-enabled, preview-disabled, and preview-enabled repositories;
- provider-reported, estimated, missing, contradicted, ambiguous, adjusted, and
  reconciled token/cost fixtures plus hard-budget parallel races;
- authored user/developer/operator/upgrade/release guides and deliberate
  missing-guide cases;
- dynamic and hostile `mix.exs`, diverse dependency SCM/scope shapes, private
  packages, metadata outage, and stale/adversarial links;
- source/docs contradictions, stale ADRs, moved paths/headings, source-analysis
  truncation, and compiler upgrades;
- candidate previews, rapid commits, accept-without-merge, external merge,
  revert, release, visibility change, and retirement;
- model prompt injection, invented citations/versions/URLs, secret-bearing
  content, malformed output, timeout, and provider outage;
- process/BEAM/node/store loss, partial edition, stale fence, cancellation,
  late result, backup/restore, missing artifact, and rollback; and
- direct URL, search, backlink, dependency-name, cache, PubSub, signal, stream,
  and fragment attempts to cross repository, tenant, session, attempt,
  candidate, and preview authorization boundaries.

Expected page manifests, dependency counts, citations, roots, states, and
allowed product projections are versioned fixtures. Generated-explanation
quality evaluation is blind to repository identity where practical and cannot
override deterministic conformance failures.

## Metrics And Release Thresholds

The release candidate records:

- deterministic inventory/page/dependency precision and recall against the
  corpus;
- project-field provenance completeness;
- direct/transitive/environment/target dependency completeness;
- verified exact-link coverage and false-link rate;
- citation coverage, citation entailment/support, and fabricated-claim rate;
- guide discovery, classification, render, and broken-reference accuracy;
- deterministic rebuild/root equality;
- source-observation-to-active-edition latency by fleet load;
- search/navigation relevance and zero-result accuracy;
- accessibility and responsive behavior;
- per-repository/fleet CPU, memory, graph growth, requests, tokens, cost, and
  retention;
- token/cost attribution and rollup equality, provider-reported versus
  estimated/unavailable posture, reservation utilization, budget denials, and
  opt-out latency;
- crash/restart/recovery time, cancellation latency, and late-result rejection;
  and
- human task success finding project, guide, dependency, source, freshness,
  and provenance information.

Exact numerical thresholds belong to the implementation plan and phase
receipts. They are pinned before qualification runs and cannot be relaxed after
seeing results without a recorded gate reopening.

The following have zero tolerance:

- cross-repository or cross-tenant disclosure;
- cross-session candidate, preview, context, cache, wake-hint, or notification
  disclosure within the same repository;
- unreserved or unattributed wiki model invocation, hard-budget overspend,
  fabricated exact token/cost value, or model call in deterministic-only or
  disabled mode;
- credential, secret, raw query/graph handle, prompt, hidden reasoning, or
  absolute host path disclosure;
- fabricated exact dependency version, source revision, path, citation, or
  external link;
- current activation from a candidate preview or unobserved source snapshot;
- stale-fence, cancelled, revoked, or incompatible-profile mutation;
- authored content represented as generated or generated content represented
  as authored/accepted;
- host execution of untrusted project code; and
- activation with blocking lint or missing required review.

## Rollout Gates

Delivery uses five cumulative gates. Each gate keeps prior invariants and
requires a clean-checkout implementation pull request, merge, full merge SHA,
receipt, and reopening conditions under the planning-phase closure pattern.

### Gate RW1: Deterministic Inventory

Required evidence:

- additive identities, ontology/shapes, graph family, commands, and queries;
- repository-enrollment default disabled and deterministic-only zero-model
  capability tests;
- exact repository/doc/source inventory and deterministic page manifests;
- no synthesis, metadata network, or production activation;
- cross-repository authorization and hostile-input tests; and
- backup/restore/startup compatibility for incomplete and closed editions.

### Gate RW2: Project And Dependency Catalog

Required evidence:

- static `mix.exs` and lock parsing;
- isolated fixed Mix introspection with host/network/credential denial;
- complete environment/target dependency traversal;
- bounded `Req` metadata and exact-link verification; and
- project/dependency product pages with conformance corpus results.

### Gate RW3: Guides, Navigation, And Activation

Required evidence:

- authored guide rendering and authority labels;
- reviewed search, citation, link/backlink, and live-panel projections;
- whole-edition lint, review, closure, and atomic activation;
- candidate-preview/current-source separation; and
- accessibility, security, privacy, retention, and rollback acceptance.

### Gate RW4: Bounded Maintainer Automation

Required evidence:

- exact per-repository logical profiles;
- graph-discovered work, leases/fences, parallel fairness, capacity, and
  cancellation/recovery;
- deterministic-only production posture first;
- optional synthesis qualified as a separate profile with exact pricing,
  reservations, usage/cost accounting, and hard parallel-session budgets; and
- fast feature disable with last safe edition behavior.

### Gate RW5: Fleet And Agent Context Qualification

Required evidence:

- multi-repository/tenant load and adversarial isolation;
- parallel same-repository session load, preview isolation, and fairness;
- bounded agent wiki-context integration with no authority expansion;
- quality, latency, cost, graph growth, retention, restore, and operator
  runbooks;
- pilot feedback and production thresholds; and
- final architecture audit and accepted product/release receipt.

No later gate begins from an unpinned or merge-pending prior phase. A gate
reopens whenever any listed invariant fails, regardless of checklist state.

## Fast Disable And Rollback

Repository opt-out prevents new compile/reservation requests and cancels active
work without deleting editions or erasing incurred accounting. Navigation and
prior-edition readability follow the separately selected presentation policy.
Profile disable prevents new maintainer leases across its exact scope.
Query/catalog/accounting incompatibility fails before serving wiki content or
dispatching synthesis.

Rollback may select the last compatible, authorized, closed edition and shows
its source mismatch/freshness honestly. It cannot mutate an edition, promote a
preview, bypass review/lint, or label an old source snapshot current. If no
safe edition exists, the product renders `unavailable` or `not_compiled` and
the rest of the repository workbench remains valid.

## Acceptance Requirements

Before production enablement, evidence MUST prove:

1. every repository wiki is explicitly configured, isolated, editioned,
   attributable, safely absent when not compiled, and fully optional without
   affecting the rest of the factory;
2. project overview and all admitted dependencies satisfy exact provenance,
   completeness, and link contracts;
3. every authored guide stays Git-authoritative and every synthesized section
   stays visibly derived and citation-bound;
4. search, navigation, citations, previews, histories, live panels, and agent
   contexts authorize before candidate generation;
5. compilation stages and current activation match the full source/candidate/
   merge/release update matrix;
6. one logical maintainer per enabled repository supports bounded parallel
   repositories and same-repository sessions with isolated previews, captured
   contexts, fairness, leases, fences, recovery, and fast disable;
7. opt-out, deterministic-only zero-model posture, consent, pricing, token and
   cost attribution, hard budgets, reconciliation, and parallel-session
   aggregation satisfy ADR 0007;
8. product states, accessibility, privacy, observability, retention, backup,
   restore, rollback, and operator procedures pass the pinned matrix;
9. all zero-tolerance conditions remain zero across adversarial and fleet load
   tests;
10. each qualification unit has immutable evidence and cannot inherit results
   from an incompatible profile; and
11. every rollout gate closes through a merged clean-checkout candidate and a
    receipt pinned to its full merge commit without weakening reopening rules.
