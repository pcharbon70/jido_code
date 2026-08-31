---
id: plan.jido_code_secure_hypermedia_control_plane_ui
status: proposed
intent: feature
source:
  - docs/research/12-secure-hypermedia-coding-factory-ui.md
  - docs/adr/0008-server-rendered-heex-and-datastar-product-runtime.md
  - docs/adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md
  - docs/adr/0010-shadcnui-as-product-component-primitive-layer.md
  - docs/adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md
  - docs/architecture/hypermedia-product-governance-baseline.md
  - docs/architecture/human-identity-scope-and-authorization-contract.md
  - docs/architecture/shadcn-ui-adoption-and-component-contract.md
  - docs/architecture/datastar-dstar-dependency-and-consumer-qualification.md
  - docs/architecture/secure-product-shell-and-information-architecture.md
  - docs/architecture/datastar-request-signal-fragment-and-stream-contract.md
  - docs/architecture/agent-attempt-workspace-and-command-contract.md
  - docs/architecture/graph-lens-and-visualization-contract.md
  - docs/architecture/ui-security-privacy-and-threat-model.md
  - docs/architecture/incident-control-plane-contract.md
  - docs/architecture/ui-accessibility-usability-and-release-qualification.md
  - docs/architecture/hypermedia-runtime-migration-and-rollback.md
---

# Secure Hypermedia Control Plane UI Implementation Plan

This eight-phase plan implements the research milestones in their preserved
order. Milestones use alphabetic product architecture labels; implementation
phases use the repository's usual numeric phase/section/task/subtask delivery
pattern:

```text
Milestone A -> Phase 1
Milestone B -> Phase 2
Milestone C -> Phase 3
Milestone D -> Phase 4
Milestone E -> Phase 5
Milestone F -> Phase 6
Milestone G -> Phase 7
Milestone H -> Phase 8
```

The plan replaces the current LiveView/LiveVue product runtime incrementally
with named human identity, explicit Phoenix controller/HEEx pages, qualified
ShadcnUI primitives, Datastar/Dstar delivery, durable attempt workspaces,
reviewed graph lenses, and a security/accessibility-qualified release. It does
not change TripleStore authority, allow raw graph access, or treat browser/SSE
state as durable truth.

## Goal

Deliver a secure factory control plane that:

1. gives named humans exact role/delegation/project scope with step-up and live
   revocation;
2. renders ordinary authenticated HEEx pages with meaningful native fallback;
3. uses a pinned ShadcnUI primitive layer behind JidoCode-owned components;
4. uses pinned Datastar/Dstar for bounded fragments and authorized SSE without
   LiveView product routes/processes/state;
5. directs attention to durable exceptions across parallel repositories and
   attempts;
6. gives each attempt a durable workspace correlating plan, interactions,
   effects, evidence, costs, controls, and receipts;
7. exposes all graph domains only through reviewed, bounded, accessible lenses;
8. provides separately authorized security, incident, cost, knowledge, and
   governance areas;
9. proves cross-scope isolation, accessibility, usability, reconnect,
   revocation, recovery, and rollback with real adapters; and
10. removes superseded LiveView/LiveVue/SaladUI product runtime only after
    parity and rollback evidence.

## Governing Inputs And Baseline

The proposed ADRs and specifications listed in the front matter are the
governing inputs. They are not binding until accepted. Phase 1 accepts or
narrows them, pins the exact merged baseline, and records all current route,
dependency, asset, identity, graph, runtime, test, and operations owners.

The accepted graph-native factory, secure harness, total memory, managed coding,
delegated-agent, and repository-wiki contracts remain binding. Their gate
reopening conditions cannot be weakened or deleted by this plan.

The current product is not a fully composed production fleet. Scheduler/
reconciler, managed service, coding loaders, delegated rollout, publication,
wiki gateways, named identity, and Datastar live delivery MUST expose honest
disabled, unconfigured, unavailable, evaluation, or contract-only posture until
their own release evidence exists.

## Milestone, Gate, And Phase Mapping

| Milestone | Gate | Required result | Implementation phase |
|---|---|---|---|
| A — Architectural Authority | HUI1 | Decisions, vocabulary, current-state inventory, supersession, identity model, and architecture checks are accepted | Phase 1 |
| B — Dependency And Consumer Proof | HUI2 | Immutable ShadcnUI/Dstar/Datastar provenance and real consumer/browser/CSP evidence pass | Phase 2 |
| C — Read-Only Hypermedia Shell | HUI3 | Named identity, authorized controller/HEEx shell, attention/fleet/project/attempt reads, native fallback pass | Phase 3 |
| D — Datastar Delivery | HUI4 | Bounded signals/fragments/SSE, server subscription, reconnect, revocation, backpressure, and convergence pass | Phase 4 |
| E — Governed Agent Control | HUI5 | Attempt timeline, admitted controls, canonical approvals, costs, idempotency, conflicts, and receipts pass | Phase 5 |
| F — Knowledge And Wiki Lenses | HUI6 | All enabled graph domains have reviewed bounded lenses, provenance, accessible views, and wiki isolation | Phase 6 |
| G — Security And Release Qualification | HUI7 | Threat, incident, accessibility, usability, load, real-adapter, operations, and rollback gates pass | Phase 7 |
| H — Remove Superseded Runtime | HUI8 | Old route/runtime/dependency/assets/docs are removed or explicitly retained, rollback closes, final release is pinned | Phase 8 |

## Phase Plans

1. [Phase 1 — Architectural Authority And Governance](./phase-01-architectural-authority-and-governance.md)
2. [Phase 2 — Dependency, Asset, And Consumer Proof](./phase-02-dependency-asset-and-consumer-proof.md)
3. [Phase 3 — Secure Read-Only Hypermedia Shell](./phase-03-secure-read-only-hypermedia-shell.md)
4. [Phase 4 — Datastar Delivery And Stream Convergence](./phase-04-datastar-delivery-and-stream-convergence.md)
5. [Phase 5 — Governed Agent Attempt Control](./phase-05-governed-agent-attempt-control.md)
6. [Phase 6 — Knowledge And Wiki Lenses](./phase-06-knowledge-and-wiki-lenses.md)
7. [Phase 7 — Security, Incident, Accessibility, And Release Qualification](./phase-07-security-incident-accessibility-and-release-qualification.md)
8. [Phase 8 — Superseded Runtime Removal And Rollback Closure](./phase-08-superseded-runtime-removal-and-rollback-closure.md)

Phase evidence is recorded in
`docs/architecture/hypermedia-ui-phase-01-receipt.md` through
`docs/architecture/hypermedia-ui-phase-08-receipt.md`. Receipt files are created
by their phase and do not claim acceptance before clean-checkout CI and merge.

## Planning Structure And Closure

Every phase follows this hierarchy:

~~~text
Phase
  description
  Section
    description
    Task
      description
      Subtask
~~~

- Phases use `N`; sections use `N.M`; tasks use `N.M.K`; subtasks use
  `N.M.K.L`.
- Every phase, section, and task begins with its own description.
- Stable anchors use `hui-pNN-*`; every task declares `[repo: jido_code]`.
- Phase 1 pins the accepted baseline. Each later phase depends on the prior
  hypermedia-UI phase receipt.
- Every phase ends with a section named `Phase N Integration Tests`.
- Implementation uses one intentional commit per section and one implementation
  pull request per phase.
- After the implementation PR passes clean-checkout CI and merges, a
  documentation-only closure PR records the full merge SHA/date, changes the
  receipt and gate from merge-pending to accepted-at-merged-candidate, and
  checks the phase, final integration section, receipt task, and merged-
  candidate pinning subtask.
- The next phase starts only from that pinned merged closure. Any gate reopens
  if a listed invariant fails regardless of checklist state.

## Non-Negotiable Invariants

1. TripleStore remains the only application-owned durable semantic authority.
2. Product web code uses Product/Factory public projections and gateways, never
   raw Knowledge internals or unrestricted SPARQL.
3. Browser signals, DOM, URLs, opaque refs, tab IDs, cookies before validation,
   streams, caches, and processes never grant authority.
4. Every page, field, query, stream, patch, command, approval, export, and
   incident operation is independently authorized and redacted.
5. Unknown and unauthorized resources remain concealed; unavailable
   projections clear rows; stale data is labeled and bounded.
6. Project initially aliases conceptual repository scope. Attempt,
   `InteractionSession`, candidate, browser session, provider thread, runtime,
   and process remain distinct.
7. Datastar requests/signals/events/patches and SSE queues/retries/connections
   are closed, bounded, and CSP/CSRF-qualified.
8. ShadcnUI, Dstar, Datastar, assets, and browser profiles are immutable,
   locally served, licensed, and qualified before product use.
9. The UI exposes only accepted semantic commands with current state,
   revision, lease/fence, profile, idempotency, step-up, and receipt bindings.
10. Execution, candidate, verification, decision, draft publication, external
    application, re-observation, post-change verification, follow-up, and
    satisfaction remain distinct.
11. Graph families appear only through reviewed bounded lenses with provenance,
    states, truncation, and accessible alternatives.
12. Current disabled/unconfigured/contract-only capability is never presented
    as production-ready.
13. LiveView/LiveVue/SaladUI removal occurs only after qualified parity and
    rollback. Vite may remain as the asset compiler.
14. Existing accepted ADR/spec/receipt reopening conditions remain binding.

## Test And Evidence Rules

- Unit tests accompany every parser, Plug, authority builder, query, view model,
  component, handler, signal schema, stream transition, command adapter,
  redactor, and limit.
- Integration sections exercise real TripleStore and owned filesystem/runtime
  seams. Mocks cannot close identity, authorization, graph isolation, command,
  stream revocation/convergence, receipt, accessibility, or rollback gates.
- Network tests use closed Req adapters and immutable fixtures; ordinary CI does
  not depend on a live third-party service.
- Browser evidence covers supported engines, native fallback, Datastar mode,
  keyboard, screen reader, zoom/reflow, touch, RTL, reduced motion, forced
  colors, several tabs/users, stream loss/reconnect, and stale assets.
- Security tests cover IDOR, signals, injection, CSRF, CSP, Origin, approval
  spoofing, concurrent humans, revocation, replay, resource exhaustion, cache/
  log leakage, graph inference, and supply-chain drift.
- Fixed clocks, deterministic IDs, pinned dependencies/assets/profiles, bounded
  fixtures, and exact release digests make evidence reproducible.
