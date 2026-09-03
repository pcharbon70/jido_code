# Hypermedia UI Milestone A Phase 3 Runtime Supersession And Interface Receipt

## Status

Status: **merge-pending**

This receipt records the HUI-A3 implementation candidate prepared on
2026-09-03. ADRs 0008, 0010, and 0011 and their linked target contracts are
accepted for architecture authority only. Dstar, Datastar, ShadcnUI,
named-human identity, target routes, streams, attempt controls, knowledge
lenses, incident controls, exports, and runtime removal remain unavailable
until their later milestone gates close.

The implementation pull request and clean-checkout CI have not yet merged.
HUI-A3 therefore remains merge-pending and Milestone A Phase 4 is not
authorized.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-A2 implementation candidate | `911b8d7c8a25abf998af832f7ae8e6766e971962` - PR #103 merged 2026-09-03 |
| Accepted HUI-A2 closure baseline | `02e16cbb6cd4c56fb93c19db8c9f4a535e580dcb` - PR #104 merged 2026-09-03 |
| Section 3.1 | `9e8a66f` - accepted target runtime, component, product, and lens authority |
| Section 3.2 | `6244fb6` - superseded presentation ownership and froze versioned target interfaces |
| Section 3.3 | `23b1c52` - froze validation, real-seam, evidence, retention, and receipt contracts |
| Section 3.4 | `merge-pending` - integration validator, hostile matrix, receipt, and full verification |
| Merged candidate | `merge-pending` |

Merged candidate: `merge-pending`
Merge date: `merge-pending`

## Artifact Identity

| Artifact | SHA-256 |
| --- | --- |
| Runtime and product authority manifest | `10390c783246b79f0e096bf8bc40da6d607683aec8df748709b5fc234fd5afd4` |
| Supersession matrix | `ec611e6ecbfb26e6d80b22aeac43fbaed46230ab5b8cf5ab22df6581bb9d49f9` |
| Interface registry | `3428fa8de13c4d20805a7d455b026069237c9dfc920b76cd6db86249603a11e4` |
| Evidence contract | `e45d275180508886bafedb8485c6404a20ac263b41884118acb0cd38a37d3836` |
| Traceability and hostile scenario manifest | `ac68efc02a145c67c08c9a0483e19c68b0ba448a16eb328a2b00143b8206a2f5` |
| Runtime supersession contract | `cfcd2253e275535883d7e500b5a55a8267c3e0152ead355bbf3471729ad6dcd9` |
| Validation and release evidence contract | `b331b75cb4146095db7b1260f8d9bdcef3ea07364f7558954932c565baaee5a7` |
| HUI-A3 validator source | `bc76bc6b1237241c4eaf64171d44e2360dd70f97f82e07ed3772ddca62b36c5e` |
| HUI-A3 integration test | `1ce539782c6d0bd9d7b6e1da029c2a782da6b8fb34cefdff2fe9252cd865591e` |

## Accepted Decision And Interface Record

- ADR 0008 binds explicit controllers/HEEx for pages and fragments,
  application controllers for semantic actions, and one application-owned
  authorized Dstar/SSE coordinator for protected delivery. Datastar signals,
  DOM, transport, processes, and caches remain untrusted and non-durable.
- Product LiveView routes/processes/events/streams/state, LiveVue islands,
  SaladUI product components, remote/CDN assets, client-authoritative
  revisions, and browser-granted authority are prohibited in the target.
  Current consumers remain a compatibility implementation until Milestone H.
- `phoenix_live_view` may remain only for qualified compile-time
  `Phoenix.Component`/HEEx use. LiveDashboard must be removed, replaced, or
  separately approved before a literal zero-LiveView claim. Vite remains the
  target compiler for local `app.js` and `app.css` bundles.
- ADR 0010 accepts only the narrow `JidoCodeWeb.Components.UI` primitive
  facade and JidoCode-owned composites. ShadcnUI remains absent and blocked on
  immutable identity, license/usage, dependency, CI, asset, accessibility, and
  real-consumer evidence in Milestone B.
- ADR 0011 binds factory, repository-backed project, task, attempt workspace,
  distinct `InteractionSession`, evidence, and provenance vocabulary; durable
  attention; ten closed lens groups; reviewed queries; task-specific bounded
  visualizations; and accessible alternatives. Raw SPARQL, unrestricted graph
  browsing, a universal hairball, chat as truth, and heartbeat as semantic
  progress are prohibited.
- Ten versioned interfaces cover identity/session, product projections,
  signals/fragments, streams, component facade, command adapter, lens registry,
  incident, audit/export, and migration ownership.
- Forty-one closed route records cover eleven pages, nine bounded fragment
  reads, one multiplexed stream, finite semantic actions and previews, and
  export creation/retrieval. Six signal namespaces, eleven patch roots, ten
  projection states, sixteen safe outcomes, and ten reauthorization points
  are frozen in `hui.interfaces/1.0.0`.
- Stream architecture fixes a 900-second maximum lifetime, 60-second maximum
  reauthorization interval, current authorized initial snapshot, eight
  revocation sources, pre-patch reauthorization/requery, terminal replacement,
  close, reconnect suppression, privileged-state clearing, and safe audit.
- Additive, breaking, old-reader, feature-flag, no-dual-write, shadow-read,
  deprecation, shared-file ownership, and exact-consumer removal rules prevent
  parallel worktrees or milestone labels from silently changing meaning.

## Preserved Contract Evidence

The twelve-row supersession matrix traces each affected product, wiki,
delegated-agent, security, projection, recovery, fleet, install/rollback,
contributor, module-boundary, historical, and current-state contract through
its target owner, interface, implementation milestone, test class, rollback
dependency, and removal condition.

All prior graph-only truth, reviewed-query, semantic-command, immutable
receipt, projection-state, lossy-hint, concealment, unavailable-row,
named-identity, exact-grant, separation-of-duty, accessibility, current-
capability, and reopening invariants remain binding. Historical receipts and
current-state inventories remain evidence rather than target requirements.

Repository wiki presentation changed without weakening explicit default-off
enrollment, repository/tenant/same-repository-session isolation, one logical
maintainer profile, deterministic-only zero-model-call capability, immutable
edition/source/candidate identity, token reservation and usage/cost
attribution, hard aggregate budgets, opt-out, or review/activation/
deterministic-release separation.

## Evidence Contract

The `hui.evidence/1.0.0` contract defines unit, integration, browser,
accessibility, security, usability, load, fault, real-adapter, install,
upgrade, rollback, and observation classes. It pins candidate and tree,
toolchain, dependency/lock, source/archive, asset, configuration, browser,
assistive technology, proxy, fixture/corpus, graph protocol, and adapter
identity with deterministic clocks, IDs, seeds, order, timezone, policies,
revisions, and fault schedules.

TripleStore, identity, filesystem, semantic command/receipt, network adapter,
browser, assistive technology, and proxy release seams require the selected
real implementation. A mock or screenshot cannot replace them. Evidence
owners, independent reviewers, primary artifacts, limitations, retention, and
reopening triggers are explicit.

Merge-pending and accepted-at-merged-candidate are the only valid receipt
states. Closure requires the full merge SHA/date and coherent plan status plus
checkboxes 3, 3.4, 3.4.2, and 3.4.2.3. Mixed state fails closed and all
reopening conditions survive closure verbatim.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Five HUI-A3 JSON schemas and cross-manifest trace | Passed with exact set, ownership, version, route, link, consumer, evidence, and closure coherence |
| Focused HUI-A3 validation, hostile mutation, and closure-state suite | 6 tests, 0 failures |
| `mix architecture.check` | Passed with source, HUI-A1, HUI-A2, and HUI-A3 gates returning zero findings |
| `mix precommit` | Passed; 1,171 tests, 0 failures, with formatting, unused-dependency, compile, and combined architecture gates clean |
| Clean-checkout CI | Pending implementation pull request |

## Unresolved Risks And Accepted Limits

- The deployed product still uses its accepted LiveView, LiveVue, SaladUI,
  socket, asset, route, and single-operator compatibility runtime. HUI-A3
  changes target authority, not current code or readiness.
- Dstar, Datastar, and ShadcnUI are not dependencies and have no consumer,
  supply-chain, browser, accessibility, security, proxy, or operations credit.
- Named-human identity/authority composition, step-up, two-human approval,
  live revocation adapters, target pages, fragments, streams, commands,
  incident controls, audit/export, and knowledge lenses remain contract-only.
- Exact route, stream, component, command, lens, incident, export, and migration
  versions may change only through their owners and the breaking-change rules;
  a later phase cannot reinterpret version 1 in place.
- Real browser, assistive-technology, identity, proxy, filesystem, command,
  adapter, install, upgrade, rollback, load, fault, usability, and observation
  evidence remains blocked on Milestones B through H.
- LiveDashboard remains a development-only compatibility consumer without a
  final remove/replace/retain decision.
- The generic `mix conformance` task is not configured for this repository's
  layout and expects a missing `specs/` tree; it is not an HUI gate. The project
  `mix architecture.check`, `mix precommit`, and clean-checkout CI gates remain
  authoritative.

## Gate HUI-A3

Status: **merge-pending**

HUI-A3 remains merge-pending until the implementation pull request passes
clean-checkout CI, merges, and this receipt records the full merge commit and
date through the coherent closure transition. Milestone A Phase 4 is not
authorized before that pinned baseline.

HUI-A3 reopens regardless of checklist state if an accepted ADR or target
contract loses architecture authority or falsely gains runtime credit; a
preserved graph, query, command, receipt, projection, hint-recovery,
concealment, named-identity, exact-grant, separation-of-duty, accessibility,
current-capability, wiki enrollment/isolation/maintainer/cost/budget/release,
or prior gate invariant weakens; presentation ownership is ambiguous; an
accepted target document requires product LiveView, LiveVue, or SaladUI use;
the compile-time `phoenix_live_view` or development-only LiveDashboard
exception widens; a remote/CDN asset, browser-derived authority, raw SPARQL,
unrestricted graph browser, chat-as-truth, or heartbeat-as-progress enters the
target; a page, fragment, action, stream, signal namespace, projection state,
patch root, safe outcome, native fallback, identity builder, reauthorization
point, stream revocation rule, command preview/receipt/recovery path, export,
incident, audit, interface version/owner/consumer, compatibility rule,
parallel-edit fence, rollback dependency, or removal condition is missing or
silently reinterpreted; two route owners share mutable browser authority;
dual-write or browser-authoritative dual-read occurs; removal follows a
milestone label instead of the exact consumer/evidence manifest; a mandatory
evidence class, real seam, digest, deterministic input, independent reviewer,
retention rule, or reopening condition disappears; evidence transfers across
an incompatible qualification unit; a mock, screenshot, badge, or unchecked
prose replaces required proof; the receipt accepts an unmerged/different
candidate or enters mixed closure state; any HUI-A1 or HUI-A2 reopening
condition triggers; or architecture checks, documentation validation,
precommit, or clean-checkout CI fails at the exact candidate.
