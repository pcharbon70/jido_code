---
id: program.jido_code_secure_hypermedia_control_plane_ui
status: proposed
intent: feature
source:
  - docs/research/12-secure-hypermedia-coding-factory-ui.md
  - docs/adr/0008-server-rendered-heex-and-datastar-product-runtime.md
  - docs/adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md
  - docs/adr/0010-shadcnui-as-product-component-primitive-layer.md
  - docs/adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md
---

# Secure Hypermedia Control Plane UI Program Index

This directory is the program index for eight independent implementation
plans. Each plan implements exactly one research milestone and owns several
numbered implementation phases, one phase document per delivery pull request.
Milestones retain their alphabetic product-architecture names; phase numbering
restarts at `1` inside each milestone plan.

This corrects the invalid earlier decomposition in which one phase represented
an entire milestone. The delivery hierarchy is now:

```text
Program
  Milestone plan directory
    README and milestone gates
    Phase document
      Phase description
      Section description
        Task description
          Subtasks
      Final Phase N Integration Tests section
```

## Program Goal

Replace the current LiveView/LiveVue product runtime incrementally with a
server-authoritative coding-factory control plane built from explicit Phoenix
controllers, HEEx templates, qualified ShadcnUI primitives, and bounded
Datastar/Dstar delivery. The program must preserve TripleStore authority,
reviewed projections, governed semantic commands, parallel repository/session
isolation, bounded agent conversation, wiki enrollment and token-cost
governance, accessibility, and rollback at every intermediate merged candidate.

## Milestone Plans

| Order | Milestone plan | Phases | Program gate |
|---|---|---:|---|
| A | [Architectural Authority](./milestone-a-architectural-authority/README.md) | 4 | HUI1 |
| B | [Dependency And Consumer Proof](./milestone-b-dependency-and-consumer-proof/README.md) | 4 | HUI2 |
| C | [Read-Only Hypermedia Shell](./milestone-c-read-only-hypermedia-shell/README.md) | 5 | HUI3 |
| D | [Datastar Delivery](./milestone-d-datastar-delivery/README.md) | 4 | HUI4 |
| E | [Governed Agent Control](./milestone-e-governed-agent-control/README.md) | 6 | HUI5 |
| F | [Knowledge And Wiki Lenses](./milestone-f-knowledge-and-wiki-lenses/README.md) | 5 | HUI6 |
| G | [Security And Release Qualification](./milestone-g-security-and-release-qualification/README.md) | 5 | HUI7 |
| H | [Remove Superseded Product Runtime](./milestone-h-remove-superseded-product-runtime/README.md) | 4 | HUI8 |

Milestone order is strict. A milestone's first phase depends on the pinned
final-phase receipt of the preceding milestone; later phases depend on the
immediately preceding phase receipt inside their own plan. No downstream work
is authorized merely because a checklist was edited.

## Governing Architecture

- [Secure hypermedia control plane research](../../research/12-secure-hypermedia-coding-factory-ui.md)
- [ADR 0008: Server-rendered HEEx and Datastar product runtime](../../adr/0008-server-rendered-heex-and-datastar-product-runtime.md)
- [ADR 0009: Human identity, scoped authorization, and separation of duty](../../adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md)
- [ADR 0010: ShadcnUI as the product component primitive layer](../../adr/0010-shadcnui-as-product-component-primitive-layer.md)
- [ADR 0011: Attention-oriented control plane and knowledge lenses](../../adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md)
- [Hypermedia product governance baseline](../../architecture/hypermedia-product-governance-baseline.md)
- [Human identity, scope, and authorization contract](../../architecture/human-identity-scope-and-authorization-contract.md)
- [ShadcnUI adoption and component contract](../../architecture/shadcn-ui-adoption-and-component-contract.md)
- [Datastar and Dstar dependency and consumer qualification](../../architecture/datastar-dstar-dependency-and-consumer-qualification.md)
- [Secure product shell and information architecture](../../architecture/secure-product-shell-and-information-architecture.md)
- [Datastar request, signal, fragment, and stream contract](../../architecture/datastar-request-signal-fragment-and-stream-contract.md)
- [Agent attempt workspace and command contract](../../architecture/agent-attempt-workspace-and-command-contract.md)
- [Graph lens and visualization contract](../../architecture/graph-lens-and-visualization-contract.md)
- [Hypermedia UI security, privacy, and threat model](../../architecture/ui-security-privacy-and-threat-model.md)
- [Incident control plane contract](../../architecture/incident-control-plane-contract.md)
- [UI accessibility, usability, and release qualification](../../architecture/ui-accessibility-usability-and-release-qualification.md)
- [Hypermedia runtime migration and rollback](../../architecture/hypermedia-runtime-migration-and-rollback.md)

These ADRs and specifications remain proposed until Milestone A accepts or
narrows them. Existing accepted graph-native factory, secure harness, total
memory, managed coding, delegated-agent, and repository-wiki decisions and
gate reopening conditions remain binding throughout the program.

## Shared Planning And Closure Pattern

- Phases use `N`; sections use `N.M`; tasks use `N.M.K`; subtasks use
  `N.M.K.L` within each milestone plan.
- Every phase, section, and task begins with a description before its child
  work.
- Every task has a stable milestone-qualified anchor and declares
  `[repo: jido_code]`; dependencies name stable anchors.
- Every phase ends with a section named `Phase N Integration Tests`.
- Every section is one intentional implementation commit. Every phase is one
  implementation pull request.
- Each phase creates its own namespaced receipt in
  `docs/architecture/hypermedia-ui-milestone-<letter>-phase-NN-receipt.md`.
- The implementation PR receipt remains merge-pending. After clean-checkout CI
  passes and the PR merges, a documentation-only closure PR records the full
  merge SHA/date, changes the receipt and phase gate to
  accepted-at-merged-candidate, and checks the phase, final integration
  section, receipt task, and candidate-pinning subtask.
- The next phase starts only from that pinned closure. Any invariant or listed
  reopening condition failing reopens the gate regardless of checkbox state.

## Parallel Work Rule

The factory may run many repositories, attempts, agents, browser sessions,
and human sessions concurrently. Phase implementation may also use parallel
development sessions only when their file/module/contract ownership is
explicitly disjoint and their integration baseline is the same pinned receipt.
Parallel work never bypasses the declared phase dependency chain, one-current-
edition wiki fence, command compare-and-set semantics, scope isolation, or the
one-PR-per-phase closure rule.

## Program-Wide Invariants

1. TripleStore remains the only application-owned durable semantic authority.
2. Product code uses reviewed Product/Factory projections and governed
   gateways, never raw Knowledge internals or unrestricted SPARQL.
3. Browser state, signals, DOM, URLs, streams, caches, tab IDs, and processes
   never grant authority or become durable truth.
4. Pages, fields, queries, streams, patches, commands, approvals, exports, and
   incident operations are independently authorized and redacted.
5. Project initially aliases conceptual repository scope; task, attempt,
   `InteractionSession`, candidate, browser session, provider thread, runtime,
   and process remain distinct.
6. ShadcnUI, Dstar, Datastar, assets, browser profiles, and production
   configurations are pinned, locally served, licensed, and qualified.
7. Only accepted semantic commands may appear as controls, with exact state,
   revision, fence, profile, idempotency, assurance, and receipt bindings.
8. Conversation is a bounded authorized projection over exact attempt/
   `InteractionSession`/audience identity; it exposes only admitted answer/steer
   actions and never substitutes browser/provider chat state for graph facts.
9. Every graph family appears only through a reviewed bounded lens with safe
   provenance, projection state, truncation, and accessible alternatives.
10. Repository wiki generation remains opt-in; generation mode, maintainer
   activity, tokens, attributable cost, reservations, and budgets remain
   visible and governed per repository.
11. Disabled, unconfigured, evaluation-only, or contract-only capabilities are
    never presented as production-ready.
12. LiveView/LiveVue/SaladUI removal occurs only after qualified parity and a
    successful rollback rehearsal; Vite may remain as the asset compiler.
13. Existing accepted gate reopening conditions are never weakened or deleted.

## Program Completion

The program completes only when the final Milestone H phase is accepted at its
merged candidate, all 37 phase receipts are pinned, HUI1 through HUI8 remain
closed, superseded product runtime consumers are removed or explicitly
qualified as retained exceptions, the observation window is reconciled, and
the final control plane passes clean installation, real-adapter, security,
accessibility, usability, load, recovery, and clean-checkout CI evidence.
