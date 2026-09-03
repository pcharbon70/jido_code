# Hypermedia UI Milestone A Authority Dossier

Status: **accepted-at-merged-candidate HUI-A4/HUI1 authority dossier; implementation gated by later milestones**

This dossier binds Milestone A's accepted decisions, contracts, contributor
rules, deterministic checks, current-consumer inventory, authority paths,
proposal dispositions, exceptions, risks, and dependency blockers to one
candidate. Its machine-readable record is
[`phase_a4_authority_dossier.json`](../../priv/architecture/hypermedia_ui/phase_a4_authority_dossier.json).
The dossier grants architecture authority only. It does not make named-human
identity, ShadcnUI, Dstar, Datastar, target routes, fragments, streams,
commands, lenses, incident controls, exports, or runtime removal available.

## Accepted Baseline

HUI-A1 pinned the current-state inventory and 24 owned gaps. HUI-A2 accepted
named-human identity, exact scope and graph grants, assurance, delegation,
separation of duty, approval, and live revocation authority. HUI-A3 accepted
the controller/HEEx/Datastar target, component facade, product/lens contracts,
supersession matrix, versioned interfaces, and evidence schema. HUI-A4 started
only from HUI-A3 closure commit
`e9da1fe3a9f0a1017f35fcb29136f390e2da954f` and is accepted at merged
candidate `59ffca10f3ac9f262a81ce46b9f9f0e61550697c`.

The following outcomes are now architecture-authoritative:

- ADR 0008 assigns target pages/fragments to explicit controllers and HEEx,
  effects to application controllers and the governed command gateway, and
  protected delivery to one application-owned Dstar/SSE coordinator.
- ADR 0009 assigns identity and authority to the trusted named-human mapping
  boundary with exact account/session/scope/grant/delegation/assurance/
  revision/incident bindings and fail-closed reauthorization.
- ADR 0010 permits only the narrow `JidoCodeWeb.Components.UI` facade and
  application-owned composites; source adoption remains blocked on HUI-B.
- ADR 0011 binds the attention control plane, attempt workspace, distinct
  interaction session, evidence/provenance vocabulary, and closed lens groups.
- Browser signals, DOM, storage, routes, tabs, transports, processes, caches,
  and caller-provided revisions remain untrusted and non-durable.
- Product LiveView/LiveComponent events and streams, LiveVue/Vue bridges,
  SaladUI imports, remote assets, inline scripts, raw Knowledge access,
  direct graph/runtime effects, GET effects, and browser-derived authority are
  rejected for new target work.

## Current Consumer Reconciliation

All 13 HUI-A3 consumer groups have an exact disposition in the dossier:

| Consumer group | Replacement owner | Removal owner | Disposition |
| --- | --- | --- | --- |
| Router LiveView routes/session | HUI-C | HUI-H | explicit controller routes, then remove live routes |
| Endpoint LiveView socket | HUI-D | HUI-H | qualified HTTP/SSE, then remove socket |
| Product authentication hooks | HUI-C | HUI-H | trusted controller Plugs/helpers, then remove hooks |
| Root factory/wiki LiveView | HUI-C/HUI-F | HUI-H | controller projections and closed lenses |
| Coding-agent LiveView | HUI-C/HUI-E | HUI-H | catalog/submission controllers and governed command receipt |
| Attempt LiveView | HUI-C/HUI-D/HUI-E | HUI-H | workspace pages/fragments/stream/commands |
| LiveVue component bridge | HUI-B/HUI-C/HUI-D | HUI-H | server components and ephemeral signals |
| `Components.UI` SaladUI facade | HUI-B | HUI-H | retain facade identity, replace implementation |
| `app.js` compatibility runtime | HUI-B/HUI-D | HUI-H | pinned local Datastar/application bundle |
| `app.css` compatibility sources | HUI-B | HUI-H | owned tokens and qualified components |
| `assets/vue` | HUI-B/HUI-C/HUI-D | HUI-H | remove after component/signal parity |
| LiveView product tests | HUI-B through HUI-G | HUI-H | replace with controller/native/enhanced/browser suites |
| Dependency graph | HUI-B | HUI-H | qualify compile-only component need; remove unneeded runtimes |

No consumer may be deleted because a milestone label was reached. Removal
requires the exact consumer manifest to be empty for the target, replacement
evidence accepted, the rollback window closed, the last qualified artifact
retained, and clean-checkout CI at the merged candidate.

Twenty-six exact files that implement those compatibility groups are frozen by
SHA-256 in
[`phase_a4_governance_guardrails.json`](../../priv/architecture/hypermedia_ui/phase_a4_governance_guardrails.json).
Every exception names an owner, reason, path, symbol, applicable rules,
evidence, expiry, and reopening condition. All expire on 2027-03-31 unless a
new review records a new digest with narrower or equal scope. Directories,
patterns, future consumers, and implicit renewal are forbidden.

## Surface Authority Reconciliation

Pages, fragments, streams, commands, approvals, exports, incidents, and
revocation all use `hui.identity_authority.v1`. Each surface record pins its
own interface, authorization points, safe outcomes, implementation owner,
evidence class, and reopening condition.

- Pages authorize route admission, query, field shape, and response start.
- Fragments additionally parse a closed signal schema and authorize before a
  bounded patch to a stable root.
- Streams authorize before start/subscription and before every protected
  patch; revocation replaces protected content, closes, and suppresses
  privileged reconnect.
- Commands authorize preview/construction and again inside the gateway. They
  bind server-owned revisions and report immutable receipt outcomes.
- Approvals bind action digest, current step-up, unique independent humans,
  expiry/invalidation, and atomic compare-and-set.
- Exports authorize creation and every retrieval, shape/redact fields before
  materialization, expire, and revoke signed access.
- Incident resources/actions use exact posture, concealment, step-up,
  separation, receipts, audit, and runbooks.
- Account, session, role, delegation, project, tenant, graph, and incident
  revocation applies across every protected surface.

## Proposal Dispositions

The target runtime, named-human authority, component facade, and attention/
lens architecture proposals are accepted as architecture contracts. Dstar,
Datastar, ShadcnUI source/dependency adoption, and the final LiveDashboard
remove/replace/retain choice are deferred to their named owners. Browser-
authoritative signals/grants/revisions/workflow state, target ownership by the
superseded runtime, and an unrestricted universal graph browser are rejected.

Accepted does not mean implemented. Deferred items cannot be acquired or used
until their entry evidence passes. Rejected items require a new ADR and a
reopened HUI1 review; a later phase cannot silently reinterpret them.

## Residual Risks And Milestone B Blockers

The machine-readable dossier owns ten residual risks. The deployed product is
still the compatibility runtime; named-human authority and target surfaces are
contract-only; dependency/assets and real consumers are absent; security,
accessibility, browser, proxy, identity, adapter, load, fault, install,
upgrade, rollback, and observation evidence remains unqualified; and the
LiveDashboard final disposition remains deferred.

Milestone B remains blocked until all of the following have named evidence:

1. Exact Dstar source/release/lock/archive/license/API/risk identity.
2. Exact Datastar source commit/version/bundle/digest/license/security/local
   hosting identity.
3. Exact ShadcnUI source namespace/provenance/license/supported usage/update
   policy.
4. Clean Phoenix.Component/HEEx dependency resolution without a hidden target
   LiveView consumer.
5. Reproducible local `app.js`/`app.css`, CSP, asset digests, and no remote or
   inline executable assets.
6. A real isolated controller/HEEx native and Datastar-enhanced consumer.
7. Real-browser CSRF/Origin/CSP/injection/focus/keyboard/accessibility/
   disconnect/reconnect/native-fallback evidence.
8. Consumer/license/asset allowlists, full qualification dossier,
   `mix precommit`, clean-checkout CI, and a pinned HUI-B merged candidate.

Milestone B Phase 1 is authorized only from Phase 4 merged candidate
`59ffca10f3ac9f262a81ce46b9f9f0e61550697c`, whose receipt is
accepted-at-merged-candidate with the full merge SHA and date. Checkboxes, a
branch head, an open pull request, or successful local tests cannot authorize
it. The eight Milestone B entry blockers above remain binding.

## Enforceable Evidence

`mix architecture.check` now combines the graph-native source checks with
HUI-A1 through HUI-A4 validation. HUI-A4 verifies:

- all current exception paths, digests, owners, symbols, expiry, evidence, and
  reopening conditions;
- permitted target controller/component fixtures and every prohibited runtime,
  asset, Knowledge, graph, authority, effect, and surface-contract fixture;
- eight milestone directories, 37 phase files, stable unique task anchors,
  resolved dependencies, one receipt task and final integration section per
  phase, and valid internal links;
- 12 cross-cutting requirements and all 24 HUI-A1 gaps mapped to an authority
  owner, source document, milestone, task, evidence class, and reopening
  condition;
- coherent completed-plan/accepted-receipt states and the prohibition on
  authorizing dependents from merge-pending, mixed, or unpinned evidence;
- all 13 consumer, eight surface, ten proposal, 26 exception, ten risk, and
  eight Milestone B blocker records.

The exact artifact digests, final findings, limitations, toolchain, reviewers,
and clean-checkout results are pinned in the Phase 4 receipt at the merged
candidate. Any required real seam remains unavailable rather than simulated.
