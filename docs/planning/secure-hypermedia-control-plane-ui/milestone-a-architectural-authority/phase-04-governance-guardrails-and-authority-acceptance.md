---
id: plan.jido_code_hypermedia_ui_milestone_a_phase_04
parent_plan: plan.jido_code_hypermedia_ui_milestone_a
status: proposed
intent: feature
---

# Milestone A Phase 4 - Governance Guardrails And Authority Acceptance

This phase makes the accepted architecture enforceable in contributor guidance,
static checks, test fixtures, planning governance, and merged-candidate evidence.
It closes Milestone A without implementing target product behavior.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Enforce and accept the architectural-authority baseline.

  This phase closes HUI-A4 and program Gate HUI1 only when future changes fail
  fast on forbidden runtime, authority, query, command, or evidence patterns.

  - [x] 4.1 Section - Update contributor and implementation guidance.

    This section removes LiveView-specific instructions that would recreate
    migration debt and replaces them with target-stack guardrails.

    - [x] 4.1.1 Task {#huia-p04-guidance} [repo: jido_code] [after: {#huia-p03-phase-receipt}] - Amend `AGENTS.md` and contributor documentation.

      This task gives human and agent contributors executable rules for
      controller/HEEx/Datastar product work.

      - [x] 4.1.1.1 Subtask - Remove or scope LiveView route/process/event/stream instructions away from product work while retaining valid Phoenix.Component/HEEx conventions.
      - [x] 4.1.1.2 Subtask - Add controller/template/layout/form, explicit route, CSRF/Origin, CSP, stable DOM, Datastar signal/patch/SSE, native fallback, and no-inline-script rules.
      - [x] 4.1.1.3 Subtask - Add named identity, exact scope, concealment, reauthorization, step-up, receipt, graph-lens, wiki cost, parallel-session, accessibility, and readiness rules.
      - [x] 4.1.1.4 Subtask - Update testing, dependency, asset, operations, migration, commit-per-section, PR-per-phase, receipt, and clean-checkout closure guidance.

  - [x] 4.2 Section - Implement architecture and traceability checks.

    This section turns the most important boundaries into deterministic CI
    failures with explicit exceptions rather than review-time memory.

    - [x] 4.2.1 Task {#huia-p04-fitness} [repo: jido_code] [after: {#huia-p04-guidance}] - Add forbidden-runtime and authority-boundary checks.

      This task prevents new product code from depending on superseded runtime
      constructs or bypassing trusted projections and gateways.

      - [x] 4.2.1.1 Subtask - Detect new LiveView/LiveComponent product routes/modules/processes/events/streams, LiveVue/Vue bridges, SaladUI imports, remote assets, inline scripts, and unauthorized dashboard exposure.
      - [x] 4.2.1.2 Subtask - Detect raw Knowledge internals/SPARQL, direct TripleStore writes, caller-selected graphs, browser-derived grants/revisions, GET effects, and direct runtime effects outside governed gateways.
      - [x] 4.2.1.3 Subtask - Detect routes/fragments/streams/commands/exports without trusted authority construction, exact resource/action checks, redaction/concealment, CSRF/Origin, or receipt behavior.
      - [x] 4.2.1.4 Subtask - Require narrowly reviewed exception records with owner, reason, exact path/symbol, expiry, evidence, and reopening condition.

    - [x] 4.2.2 Task {#huia-p04-traceability} [repo: jido_code] [after: {#huia-p04-fitness}] - Add document, plan, gate, and owner traceability checks.

      This task ensures later phases cannot silently drift from their accepted
      milestone plan or claim closure without the required evidence.

      - [x] 4.2.2.1 Subtask - Verify all eight milestone plan directories, 37 phase files, stable anchors/dependencies, unique receipts, source links, and final integration-test sections.
      - [x] 4.2.2.2 Subtask - Verify each requirement/gap maps to an ADR/spec owner, milestone, phase task, test/evidence class, and reopening condition.
      - [x] 4.2.2.3 Subtask - Verify proposed/accepted/superseded status consistency and reject phase authorization from merge-pending or unpinned receipts.
      - [x] 4.2.2.4 Subtask - Publish architecture-check fixtures for allowed Phoenix.Component use and each prohibited product/runtime/authority construct.

  - [ ] 4.3 Section - Assemble the accepted authority dossier.

    This section reconciles all Milestone A evidence and records residual risks
    before dependency acquisition is permitted.

    - [ ] 4.3.1 Task {#huia-p04-dossier} [repo: jido_code] [after: {#huia-p04-traceability}] - Review and sign the HUI1 authority dossier.

      This task binds decisions, contracts, guidance, checks, inventories, and
      risks to one exact candidate.

      - [ ] 4.3.1.1 Subtask - Reconcile Phase 1 inventories with accepted supersession and confirm every current consumer has a later replacement/removal/retention disposition.
      - [ ] 4.3.1.2 Subtask - Reconcile identity/security authority with route, stream, command, approval, export, incident, and revocation contracts.
      - [ ] 4.3.1.3 Subtask - Record accepted/deferred/rejected proposal items, residual risks, exceptions, owners, expiry, and explicit Milestone B blockers.
      - [ ] 4.3.1.4 Subtask - Create `hypermedia-ui-milestone-a-phase-04-receipt.md` in merge-pending state with HUI-A4/HUI1 evidence and all reopening conditions.

  - [ ] 4.4 Section - Phase 4 Integration Tests.

    This final section proves the target authority is internally consistent,
    enforceable, reproducible, and safe to use as the dependency baseline.

    - [ ] 4.4.1 Task {#huia-p04-integration} [repo: jido_code] [after: {#huia-p04-dossier}] - Execute the HUI-A4/HUI1 governance acceptance matrix.

      This task closes Milestone A only if positive and negative fixtures prove
      contributor rules and architecture checks match accepted documents.

      - [ ] 4.4.1.1 Subtask - Exercise every allowed/prohibited runtime, dependency, asset, identity, authority, query, command, stream, export, and documentation pattern.
      - [ ] 4.4.1.2 Subtask - Exercise stale/missing receipt, duplicate anchor, broken dependency, missing integration section, unowned requirement, silent supersession, expired exception, and parallel version-race failures.
      - [ ] 4.4.1.3 Subtask - Reproduce the full authority dossier and inventory from a clean checkout and verify no target implementation or unsupported readiness claim leaked into Milestone A.
      - [ ] 4.4.1.4 Subtask - Run full architecture/security/documentation suites, `mix precommit`, and clean-checkout CI.

    - [ ] 4.4.2 Task {#huia-p04-phase-receipt} [repo: jido_code] [after: {#huia-p04-integration}] - Publish and pin the Phase 4 receipt and HUI1 closure.

      This task records HUI-A4/HUI1 evidence in
      `docs/architecture/hypermedia-ui-milestone-a-phase-04-receipt.md`.

      - [ ] 4.4.2.1 Subtask - Keep HUI1 merge-pending on an unaccepted decision, contradictory contract, stale contributor rule, bypassable check, incomplete traceability, unowned risk, or unpinned evidence input.
      - [ ] 4.4.2.2 Subtask - Record exact document/check/fixture/toolchain digests, full findings, exceptions, reviewers, limitations, and every gate reopening condition.
      - [ ] 4.4.2.3 Subtask - Record the full merge SHA/date and pin the merged candidate; check the phase, Phase 4 Integration Tests section, receipt task, pinning subtask, and Milestone A completion before authorizing Milestone B Phase 1.
