---
id: plan.jido_code_hypermedia_ui_milestone_a_phase_03
parent_plan: plan.jido_code_hypermedia_ui_milestone_a
status: completed
intent: feature
---

# Milestone A Phase 3 - Runtime Contract Supersession And Interface Freeze

This phase translates the target runtime decision into every affected product,
security, wiki, testing, operations, and contributor contract. It freezes the
interfaces Milestones B–H must implement without prematurely changing runtime.

Back to plan: [README](./README.md)

- [x] 3 Phase - Supersede conflicting runtime ownership and freeze target interfaces.

  This phase closes HUI-A3 by making controller/HEEx/Datastar ownership
  coherent across accepted documentation while preserving durable authority.

  - [x] 3.1 Section - Accept the product runtime and component decisions.

    This section decides the allowed and prohibited runtime constructs,
    dependency exceptions, product component boundary, and rollback posture.

    - [x] 3.1.1 Task {#huia-p03-runtime-adr} [repo: jido_code] [after: {#huia-p02-phase-receipt}] - Accept or narrow ADRs 0008 and 0010.

      This task gives ordinary controllers, HEEx, Datastar/Dstar, and ShadcnUI
      precise ownership without granting them application authority.

      - [x] 3.1.1.1 Subtask - Decide full-page, fragment, request, SSE, native-fallback, browser-state, asset, and server-process ownership.
      - [x] 3.1.1.2 Subtask - Prohibit LiveView product routes/processes/events/streams/state, LiveVue islands, remote CDN assets, client-authoritative revisions, and browser-granted authority.
      - [x] 3.1.1.3 Subtask - Define the narrowly allowed `phoenix_live_view` package use for Phoenix.Component/HEEx if still required and the evidence needed to remove or retain it.
      - [x] 3.1.1.4 Subtask - Decide the ShadcnUI facade, JidoCode-owned composite boundary, Vite posture, LiveDashboard disposition, migration order, and rollback obligations.

    - [x] 3.1.2 Task {#huia-p03-product-adr} [repo: jido_code] [after: {#huia-p03-runtime-adr}] - Accept or narrow ADR 0011 and product vocabulary.

      This task establishes the attention-oriented factory, durable attempt
      workspace, and reviewed knowledge-lens mental model.

      - [x] 3.1.2.1 Subtask - Decide the factory/repository-backed-project/task/attempt/interaction/evidence navigation hierarchy and durable URL rules.
      - [x] 3.1.2.2 Subtask - Decide attention derivation, acknowledgement limits, lifecycle/outcome separation, readiness language, and current capability honesty.
      - [x] 3.1.2.3 Subtask - Decide the ten lens groups, graph-family mapping, reviewed-query-only rule, visualization selection, bounds, provenance, and accessible alternatives.
      - [x] 3.1.2.4 Subtask - Prohibit raw SPARQL, unrestricted graph browsing, a universal node-link hairball, chat-as-record-of-truth, and process heartbeat as semantic progress.

  - [x] 3.2 Section - Amend all affected architecture and product contracts.

    This section removes contradictory ownership clauses and installs explicit
    page, request, stream, command, receipt, revocation, and projection rules.

    - [x] 3.2.1 Task {#huia-p03-contracts} [repo: jido_code] [after: {#huia-p03-product-adr}] - Reconcile product, wiki, security, testing, and operations specifications.

      This task makes the proposed hypermedia specifications the complete
      replacement for presentation-specific clauses they supersede.

      - [x] 3.2.1.1 Subtask - Amend product-surface, repository-wiki product, delegated-agent product, security/privacy, projection delivery, command recovery, fleet operations, install/rollback, and contributor fitness contracts.
      - [x] 3.2.1.2 Subtask - Freeze explicit full-page/fragment/action/stream routes, HTTP methods, request classes, signal namespaces, projection states, patch roots, error outcomes, and native fallback expectations.
      - [x] 3.2.1.3 Subtask - Freeze trusted identity/authority builder, reauthorization points, stream lifetime/revocation, command preview/receipt, export, incident, and audit interfaces.
      - [x] 3.2.1.4 Subtask - Preserve accepted wiki enrollment, per-repository isolation, maintainer, token reservation/usage/cost, budget, and deterministic-release semantics in the new product contract.

    - [x] 3.2.2 Task {#huia-p03-versioning} [repo: jido_code] [after: {#huia-p03-contracts}] - Assign interface versions, owners, compatibility, and migration fences.

      This task prevents parallel sessions and later milestones from racing
      shared contracts or inventing incompatible protocol meanings.

      - [x] 3.2.2.1 Subtask - Assign owners and versions for identity/session, product projection, signal/fragment, stream, component facade, command adapter, lens registry, incident, and migration protocols.
      - [x] 3.2.2.2 Subtask - Define additive/compatible/breaking change rules, old-reader behavior, feature flags, dual-read/write prohibitions, and deprecation windows.
      - [x] 3.2.2.3 Subtask - Define which phase owns every shared file/module/route/schema and how parallel worktrees reconcile without concurrent version assignment.
      - [x] 3.2.2.4 Subtask - Bind removal and rollback decisions to an exact consumer manifest and accepted evidence rather than milestone completion labels alone.

  - [x] 3.3 Section - Freeze validation and release evidence contracts.

    This section defines what later phases must prove and which evidence cannot
    be replaced by mocks, screenshots, or unchecked prose.

    - [x] 3.3.1 Task {#huia-p03-evidence} [repo: jido_code] [after: {#huia-p03-versioning}] - Publish the program test, evidence, and receipt schema.

      This task makes every HUI gate reproducible at a clean merged candidate.

      - [x] 3.3.1.1 Subtask - Define unit, integration, browser, accessibility, security, usability, load, fault, real-adapter, install, upgrade, rollback, and observation evidence classes.
      - [x] 3.3.1.2 Subtask - Define immutable candidate/dependency/asset/config/browser/proxy/fixture digests, fixed clocks/IDs, evidence manifests, reviewers, and retention.
      - [x] 3.3.1.3 Subtask - Define which seams require real TripleStore, identity, filesystem, command, network adapter, browser, assistive technology, and proxy evidence.
      - [x] 3.3.1.4 Subtask - Define merge-pending and accepted-at-merged-candidate receipt states, reopening conditions, and the exact checkboxes required for phase closure.

  - [x] 3.4 Section - Phase 3 Integration Tests.

    This final section proves every affected contract tells one coherent story
    and every target interface is owned, versioned, testable, and reversible.

    - [x] 3.4.1 Task {#huia-p03-integration} [repo: jido_code] [after: {#huia-p03-evidence}] - Execute the HUI-A3 supersession and interface matrix.

      This task detects stale ownership, unversioned interfaces, unauthorized
      semantics, and evidence gaps before implementation begins.

      - [x] 3.4.1.1 Subtask - Trace every preserved/superseded/deferred clause from old document through new owner, interface, phase, test class, rollback dependency, and removal condition.
      - [x] 3.4.1.2 Subtask - Verify no accepted document requires LiveView/LiveVue/SaladUI product use or contradicts the named-human, graph-only, reviewed-query, or governed-command model.
      - [x] 3.4.1.3 Subtask - Verify all interfaces, versions, ownership, compatibility, parallel-edit boundaries, evidence classes, and receipt rules are complete and link-valid.
      - [x] 3.4.1.4 Subtask - Run architecture/spec drift checks, docs validation, `mix precommit`, and clean-checkout CI.

    - [x] 3.4.2 Task {#huia-p03-phase-receipt} [repo: jido_code] [after: {#huia-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records HUI-A3 evidence in
      `docs/architecture/hypermedia-ui-milestone-a-phase-03-receipt.md`.

      - [x] 3.4.2.1 Subtask - Keep HUI-A3 merge-pending on contradictory ownership, silent supersession, unowned/unversioned interface, weakened invariant, missing rollback dependency, or mock-only required evidence.
      - [x] 3.4.2.2 Subtask - Record accepted ADR/spec revisions, supersession matrix, interface/version manifest, evidence schema, limitations, and all reopening conditions.
      - [x] 3.4.2.3 Subtask - Record the full merge SHA/date and pin the merged candidate; check the phase, Phase 3 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 4.
