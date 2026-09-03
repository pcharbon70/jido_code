# Hypermedia UI Milestone A Phase 4 Governance And Authority Receipt

## Status

Status: **merge-pending**

This receipt records the HUI-A4/HUI1 implementation candidate prepared on
2026-09-03. It remains merge-pending until the implementation pull request
passes clean-checkout CI and merges. Milestone B Phase 1 is not authorized by
this branch, its checkboxes, local verification, or an open pull request.

HUI-A4 accepts contributor guidance, architecture guardrails, traceability,
and the authority dossier only. It does not implement or grant readiness to
named-human identity, ShadcnUI, Dstar, Datastar, target pages/fragments/
streams/commands/lenses, incident controls, export delivery, compatibility
runtime removal, or final release evidence.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-A3 implementation candidate | `167c6cac0dd148bc919b4969f3c6fb691c0863a1` - PR #105 merged 2026-09-03 |
| Accepted HUI-A3 closure baseline | `e9da1fe3a9f0a1017f35fcb29136f390e2da954f` - PR #106 merged 2026-09-03 |
| Section 4.1 | `ab4e6dc1f90d804edcb4dd9266414ba8bf0c7e95` - contributor and target implementation guidance |
| Section 4.2 | `9f0a3af68740a7ea1d2bf6d1d8a6fa518fa06d71` - architecture guardrails, traceability, fixtures, and tests |
| Section 4.3 | `29f9fe276797fab918b8d1672f7dea1ed60746ba` - authority dossier and merge-pending receipt |
| Section 4.4 | `af98c32b5ac6a5a8e0a2f38b8620475ae71d1e45` - final acceptance matrix and candidate evidence |
| Implementation PR head | `merge-pending` |
| Merged candidate | `merge-pending` |

Merged candidate: `merge-pending`
Merge date: `merge-pending`

## Artifact Identity

| Artifact | SHA-256 |
| --- | --- |
| `AGENTS.md` | `150f7fbfded79ef63af18c302f7fb1d23e24c015a4caa152494d572076488a54` |
| Hypermedia product contribution contract | `ccca1097171f286680f05d80eba327c1a380514076e2753ea7016ef35dfe4926` |
| HUI-A4 governance guardrail manifest | `8ee74ebdcd5ffa0896f4918b4437e064bb22e688ef0b6495bbeea84493eea5d6` |
| HUI-A4 program traceability manifest | `8378cb971f72b2a05ca35b79736890b0972a10abd31176b5ef334c35011312c7` |
| HUI-A4 authority dossier manifest | `5435838660be57d8cbaf96ef392127a2ec38a8d4364f9537203918a97e03e70c` |
| HUI-A4 acceptance matrix | `78c46ba8e085124367c14f9370459b622aa74f725fa91ab103e5cdc2722e192a` |
| Milestone A authority dossier | `c8e744270c28d9952be8ede56d016a3b8157b6da24cd5002e415e59634216c17` |
| HUI-A4 validator source | `e2fcc6775a1559dec507ded0ae4bace4d885962ba24667eeb9e7972255dde0e9` |
| HUI-A4 integration test | `81baa1c4363de96521a7b0eb4031bfaa8fe409cbdea97343cef50b84b7a78b83` |
| Allowed/prohibited fixture tree | `bf5ae8588abbcfa61b0c20ca2e177fa275159817618a1b537eff9a883eb4e186` |

## Toolchain Identity

| Tool | Candidate version |
| --- | --- |
| Erlang/OTP | 28 / ERTS 16.2 |
| Elixir | 1.19.5 compiled with Erlang/OTP 28 |
| Mix | 1.19.5 compiled with Erlang/OTP 28 |
| Node.js | 24.3.0 |
| npm | 11.4.2 |
| Rust | 1.92.0 (`ded5c06cf`, 2025-12-08) |
| CMake | 3.28.3 |

## Contributor And Implementation Guidance

- New product work uses explicit Phoenix controller routes, HTML modules,
  application layouts, server-rendered HEEx, `to_form/2`, stable DOM roots,
  native links/forms, and qualified Datastar progressive enhancement.
- Product LiveView/LiveComponent routes, processes, events, streams, hooks,
  LiveVue/Vue bridges, SaladUI imports, remote/CDN assets, and inline scripts
  are prohibited for the target. Current exact consumers remain compatibility
  implementation until evidence-based Milestone H removal.
- Trusted Plugs/helpers reconstruct named human identity, exact tenant/project/
  resource/graph scope, delegation, assurance, policy and graph revisions,
  lifecycle, environment, incident posture, and applicable fence. Browser
  values cannot grant authority or supply authoritative revisions.
- Every page, fragment, stream, query, field shape, command, approval, export,
  and download repeats exact resource/action authorization at its named point,
  applies concealment/redaction/step-up/separation/revocation, and fails closed.
- State changes are non-GET, closed-schema, CSRF- and Origin-protected,
  optimistic-revision/idempotency aware, governed-gateway owned, and report an
  immutable semantic receipt rather than optimistic browser success.
- Signals are bounded hints; patches use stable roots and static expressions;
  protected SSE sends a current authorized snapshot, reauthorizes/requeries
  before each patch, bounds lifetime, and terminates/suppresses reconnect on
  revocation. Native fallback remains functional.
- Graph lenses use closed reviewed queries, exact grants, bounded datasets,
  source/revision/limit labels, and accessible table/text alternatives. Wiki
  isolation, enrollment, immutable edition, cost/budget, opt-out, review, and
  activation/release invariants remain binding.
- Parallel sessions share no mutable browser authority and converge through
  server-owned revisions with explicit winner/idempotent/conflict/stale/
  revoked receipts.
- Controller/HTML tests use `Phoenix.ConnTest` and `LazyHTML`; milestone-owned
  browser, accessibility, security, proxy, load, fault, operations, migration,
  rollback, and real-seam evidence remains mandatory where specified.
- Each numbered plan section is one commit and each phase one implementation
  pull request. The post-merge closure transition pins the merge SHA/date;
  local `main` is synced before merged branches are deleted.

## Architecture Guardrail Record

The HUI-A4 checker enforces 15 rule classes:

1. product LiveView route/module/session/socket/render;
2. product LiveComponent;
3. LiveView event/stream/hook;
4. LiveVue or Vue bridge/source;
5. SaladUI consumer;
6. unauthorized LiveDashboard exposure;
7. inline HEEx script;
8. remote/CDN product asset;
9. raw Knowledge internals or SPARQL;
10. direct TripleStore/graph write;
11. caller-selected graph/grant/revision;
12. browser-derived authority/assurance/delegation/revision;
13. GET semantic effect;
14. direct runtime effect outside the command gateway; and
15. target surface missing its closed hypermedia contract.

Target surface contracts declare kind, interface, trusted authority builder,
exact resource/action, reviewed query catalog, concealment, redaction, stable
DOM, CSRF/Origin, command gateway, receipt, native fallback, and honest
availability. Positive and negative fixtures exercise every class.

Twenty-six current compatibility files are excepted only at their exact
SHA-256. Each record has an owner, reason, exact path and symbol, applicable
rules, evidence, 2027-03-31 expiry, and reopening condition. A changed digest,
expired date, widened use, missing file, directory/pattern scope, implicit
renewal, or new consumer fails closed.

## Plan, Owner, And Receipt Traceability

The program checker reproduces eight milestone directories and 37 phase files,
validates milestone/phase IDs and statuses, requires unique task anchors,
resolves every dependency, requires exactly one phase receipt task and one
final integration-test section per phase, and resolves internal Markdown
links. A completed plan must have an accepted receipt with a full merged SHA
and date. Proposed/merge-pending, accepted, and mixed states cannot be
confused, and a dependent phase cannot acquire authorization from checkboxes,
an unmerged head, merge-pending evidence, or an unpinned receipt.

Twelve cross-cutting requirements cover runtime, identity, authorization,
queries/projections/lenses, commands/receipts, streams, dependencies/assets,
accessibility, wiki invariants, parallel ownership, evidence, and planning
governance. All 24 HUI-A1 gaps map to an authority owner, existing ADR/spec,
milestone, exact phase task, evidence class, and reopening condition.

## Authority Dossier Findings

- All 13 current consumer groups reconcile to a replacement, removal, or
  narrowly qualified retention disposition. No current consumer is silently
  converted into target authority and none may be deleted by milestone label.
- Pages, fragments, streams, commands, approvals, exports, incidents, and
  revocation share the trusted identity/authority builder but retain distinct
  interfaces, authorization points, safe outcomes, implementation owners,
  evidence, and reopening conditions.
- ADRs 0008 through 0011 are accepted as architecture authority. Dependency/
  asset acquisition and LiveDashboard disposition remain deferred. Browser-
  authoritative application state, superseded target runtime ownership, and
  an unrestricted universal graph browser are rejected.
- Ten residual risks remain open, blocked, contract-only, unqualified,
  deferred, tooling-limited, or merge-pending with explicit owners,
  mitigations, expiry/gates, and reopening conditions.
- Eight Milestone B blockers require exact dependency/source/license/lock/
  asset identity, reproducible local builds, a real controller/HEEx consumer,
  browser/security/accessibility/failure/native evidence, allowlists, full
  qualification, precommit, clean-checkout CI, and a pinned merged candidate.

## Evidence Owners And Reviewers

| Evidence | Primary owner | Independent reviewer | Current limitation |
| --- | --- | --- | --- |
| Contributor contract | HUI-A architecture owner | security and migration owners | architecture-only; no target consumer |
| Runtime/authority source guardrails | HUI-A architecture owner | HUI-H removal owner | current files remain excepted and deployed |
| Identity/authorization boundaries | HUI-A identity owner | security owner | implementation deferred to HUI-C/E/G |
| Plan/gap/receipt traceability | HUI-A planning owner | milestone owners | later receipts do not exist yet |
| Dependency/asset blockers | HUI-B owner | security/license owner | no selected source or consumer evidence |
| Dossier and residual risk | HUI-A program owner | HUI-B through HUI-H owners | later milestone evidence remains unavailable |
| Candidate verification | repository maintainer | clean-checkout CI | merge-pending until PR passes and merges |

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| HUI-A4 focused guardrail/traceability/dossier/acceptance suite | Passed; 9 tests, 0 failures |
| `mix architecture.check` | Passed with graph-native source and HUI-A1 through HUI-A4 gates returning zero findings |
| Architecture/security/documentation regression suites | Passed; 72 tests, 0 failures |
| `mix precommit` | Passed; 1,180 tests, 0 failures, with formatting, unused-dependency, compile, and combined architecture gates clean |
| Clean-checkout CI | `merge-pending` |

The `mix conformance` task remains unconfigured for this repository layout and
expects a missing `specs/` tree. It is not a HUI gate. The checked-in HUI
validators, applicable security/documentation suites, `mix precommit`, and
clean-checkout CI are authoritative.

## Gate HUI-A4 / HUI1

Status: **merge-pending**

HUI-A4 and program Gate HUI1 remain merge-pending. They transition only when
the final acceptance matrix, architecture/security/documentation suites,
`mix precommit`, and clean-checkout CI pass for the exact implementation
candidate; the implementation pull request merges; a closure pull request pins
the full merge SHA/date and exact artifact/toolchain/evidence identity; the
Phase 4 and Milestone A plan statuses become completed; closure checkboxes 4,
4.4, 4.4.2, and 4.4.2.3 become checked coherently; and every reopening
condition below remains intact.

HUI-A4/HUI1 reopens regardless of checklist state if contributor guidance
again makes product LiveView/LiveComponent/LiveVue/SaladUI normative, omits the
controller/HEEx/layout/form/explicit-route/native-fallback contract, weakens
CSRF/Origin/CSP/local-asset/no-inline-script rules, treats signals/DOM/storage/
tabs/transports/processes/caches as authority or durability, omits stable DOM
roots or SSE lifetime/reauthorization/revocation behavior, permits remote or
mutable assets, or makes unsupported readiness claims; if named identity,
exact account/session/tenant/project/resource/graph/delegation/assurance/
revision/incident binding, concealment, redaction, reauthorization, step-up,
separation of duty, revocation, immutable receipts, graph-lens bounds and
alternatives, wiki isolation/enrollment/edition/cost/budget/opt-out/release,
parallel-session conflict, accessibility, or current-capability honesty
weakens; if raw Knowledge internals/SPARQL, direct TripleStore/graph writes,
caller-selected graphs/grants/revisions, GET effects, direct runtime effects,
optimistic success, unrestricted graph browsing, chat-as-truth, or heartbeat-
as-progress enters the target; if a guardrail becomes bypassable, its positive
or negative fixture disappears, an exception lacks owner/reason/exact path and
symbol/digest/rules/expiry/evidence/reopening condition, an exception expires,
widens, renews implicitly, or matches a new consumer, or current consumers are
removed without exact parity/removal/rollback evidence; if any of the eight
milestone directories or 37 phase files disappears, a plan/parent/status/
anchor/dependency/receipt/source link/integration section becomes duplicate,
missing, broken, or inconsistent, a requirement or any of 24 gaps loses its
ADR/spec owner/milestone/task/evidence/reopening mapping, a proposal is silently
superseded, a dependent phase is authorized from merge-pending/mixed/unpinned
evidence, a parallel session or worktree selects an interface version or
shares mutable authority, or a semantic race lacks an explicit conflict
receipt; if any current consumer loses its replacement/removal/retention
disposition, any page/fragment/stream/command/approval/export/incident/
revocation surface loses its trusted authority builder, interface,
authorization points, safe outcomes, evidence, owner, or reopening condition,
any accepted/deferred/rejected proposal is reinterpreted, any residual risk or
Milestone B blocker becomes unowned or disappears, or dependency acquisition
starts before all HUI-B entry evidence; if the qualification unit loses its
candidate/tree/toolchain/dependency/lock/source/archive/asset/configuration/
browser/assistive-technology/proxy/fixture/corpus/graph-protocol/adapter
identity, deterministic clock/ID/seed/order/timezone/policy/revision/fault
inputs, findings, limitations, retention, owner, or independent reviewer; if a
mock, fake, screenshot, badge, prose claim, or unchecked checklist replaces a
required real TripleStore/identity/filesystem/semantic-command/network/browser/
assistive-technology/proxy seam; if evidence transfers across an incompatible
qualification unit; if the receipt accepts an unmerged or different candidate,
omits the full SHA/date, loses a reopening condition, or enters mixed closure
state; if any HUI-A1, HUI-A2, or HUI-A3 reopening condition triggers; or if
architecture checks, applicable security/documentation suites, `mix precommit`,
or clean-checkout CI fails at the exact candidate.
