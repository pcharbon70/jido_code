---
id: plan.jido_code_hypermedia_ui_milestone_c_phase_04
parent_plan: plan.jido_code_hypermedia_ui_milestone_c
status: proposed
intent: feature
---

# Milestone C Phase 4 - Attention, Fleet, Project, And Attempt Projections

This phase connects the native shell to reviewed, bounded, authorized read
projections for parallel factory oversight without adding semantic controls.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Deliver truthful read-only factory, project, and attempt oversight.

  This phase closes HUI-C4 by answering what needs attention, what each project
  is doing, and what an attempt currently means using durable graph truth.

  - [ ] 4.1 Section - Implement attention and factory-fleet projections.

    This section provides exception-oriented entry points and bounded fleet
    scanning rather than requiring humans to open every running agent.

    - [ ] 4.1.1 Task {#huic-p04-attention} [repo: jido_code] [after: {#huic-p03-phase-receipt}] - Implement reviewed attention and health projections.

      This task derives actionable attention with provenance and no hidden
      durable acknowledgement semantics.

      - [ ] 4.1.1.1 Subtask - Define reviewed queries/view models for blocked, failed, stale, budget-near, verification-needed, approval-needed, incident, and unavailable attention families.
      - [ ] 4.1.1.2 Subtask - Include resource/scope, severity, reason, lifecycle/outcome, freshness/revision, owner, evidence, readiness, and authorized durable destination.
      - [ ] 4.1.1.3 Subtask - Bound family counts, rows, sort/filter/page, query time/bytes, and derived explanations; make partial/truncated/contradictory data explicit.
      - [ ] 4.1.1.4 Subtask - Distinguish derived current attention from any future user acknowledgement resource and never infer semantic progress from process liveness alone.

    - [ ] 4.1.2 Task {#huic-p04-fleet} [repo: jido_code] [after: {#huic-p04-attention}] - Implement fleet and project-summary projections.

      This task lets developers scan many parallel repositories/attempts while
      retaining exact scope isolation and honest composition readiness.

      - [ ] 4.1.2.1 Subtask - Query bounded repository/project identity, enrollment, desired/current state, health, attempts, agent/runtime posture, verification, wiki, cost/budget, and incident summaries.
      - [ ] 4.1.2.2 Subtask - Implement authorized filter/sort/page/search fields, safe labels, opaque links, server-known totals/unknown totals, and current source/as-of revisions.
      - [ ] 4.1.2.3 Subtask - Render composed, disabled, evaluation-only, unconfigured, unavailable, stale, partial, and error capability states without fabricated runnable controls.
      - [ ] 4.1.2.4 Subtask - Prove rows/fields disappear or redact on current graph/role/project grants and never leak counts through totals, facets, errors, timing, or cache keys.

  - [ ] 4.2 Section - Implement project and attempt read workspaces.

    This section composes scoped project knowledge and durable attempt summaries
    while keeping interaction sessions, candidates, and runtimes distinct.

    - [ ] 4.2.1 Task {#huic-p04-project} [repo: jido_code] [after: {#huic-p04-fleet}] - Implement project overview, attempts, wiki, dependency, and cost summaries.

      This task gives one repository-backed project a useful native dashboard
      from already reviewed projections.

      - [ ] 4.2.1.1 Subtask - Render repository/source identity, desired/current state, branch/worktree policy, active/recent attempts, evidence/review posture, wiki enrollment/freshness, dependency summary, and budget/cost.
      - [ ] 4.2.1.2 Subtask - Link to separately authorized attempts, wiki/dependency pages, reviews, costs, and knowledge placeholders without querying unapproved graph lenses.
      - [ ] 4.2.1.3 Subtask - Apply field-level redaction, bounded history, projection states, source provenance, current revisions, and truthful unsupported capability notices.
      - [ ] 4.2.1.4 Subtask - Keep project alias semantics explicit and reject inferred multi-repository grouping or cross-repository aggregation not accepted by contract.

    - [ ] 4.2.2 Task {#huic-p04-attempt} [repo: jido_code] [after: {#huic-p04-project}] - Implement the read-only attempt workspace skeleton.

      This task creates the durable route and trust summary that Milestone E
      later enriches with causal timelines and commands.

      - [ ] 4.2.2.1 Subtask - Render attempt identity, task/repository, agent/profile/runtime, branch/worktree, owner, lifecycle and outcome rails, current revision/fence, freshness, and budget posture.
      - [ ] 4.2.2.2 Subtask - Render bounded interaction/artifact/effect/verification/decision/receipt/cost summary counts and recent items with separately authorized detail links.
      - [ ] 4.2.2.3 Subtask - Label plan versus observed state, claimed versus independently verified evidence, candidate versus externally applied source, and running versus semantically progressing.
      - [ ] 4.2.2.4 Subtask - Render controls as unavailable until Milestone E; do not add pause, stop, retry, approve, or other decorative buttons.

  - [ ] 4.3 Section - Complete projection-state and cache isolation behavior.

    This section ensures errors, stale data, authorization change, and cache
    reuse cannot preserve rows or imply truth that is no longer available.

    - [ ] 4.3.1 Task {#huic-p04-states} [repo: jido_code] [after: {#huic-p04-attempt}] - Implement all projection states and safe refresh semantics.

      This task gives every page a coherent state envelope independent of
      transport connection status.

      - [ ] 4.3.1.1 Subtask - Implement loading, ready, empty, stale, partial, truncated, denied/concealed, unavailable, unconfigured, and error outcomes for every projection family.
      - [ ] 4.3.1.2 Subtask - Clear previously visible data on concealment/unavailability, bound stale retention, distinguish retryable/terminal errors, and provide safe native retry.
      - [ ] 4.3.1.3 Subtask - Key caches by exact principal/session generation/scope/grants/query/version and prevent protected shared/browser/proxy caching.
      - [ ] 4.3.1.4 Subtask - Add safe query latency/row/truncation/cache telemetry without protected values, raw IRIs, user input, or cross-scope dimensions.

  - [ ] 4.4 Section - Phase 4 Integration Tests.

    This final section proves read-only factory oversight is bounded,
    authorized, truthful, and effect-free across parallel scopes.

    - [ ] 4.4.1 Task {#huic-p04-integration} [repo: jido_code] [after: {#huic-p04-states}] - Execute the HUI-C4 projection and isolation matrix.

      This task uses real TripleStore projections and several repositories,
      attempts, users, roles, and readiness states.

      - [ ] 4.4.1.1 Subtask - Exercise attention, fleet, project, and attempt queries across all lifecycle/outcome/readiness/projection states, bounds, pagination, search, stale, contradiction, timeout, and error cases.
      - [ ] 4.4.1.2 Subtask - Exercise field/row/query authorization, copied refs, totals/facets/timing inference, cache isolation, role/delegation/project/graph revocation, and concealed/unavailable replacement.
      - [ ] 4.4.1.3 Subtask - Exercise large fleets, parallel repositories/attempts, unsupported capabilities, wiki opt-out, zero/nonzero costs, hostile labels, and no semantic write effects.
      - [ ] 4.4.1.4 Subtask - Run real-store/controller/browser/accessibility/security/load smoke suites, `mix precommit`, and clean-checkout CI.

    - [ ] 4.4.2 Task {#huic-p04-phase-receipt} [repo: jido_code] [after: {#huic-p04-integration}] - Publish and pin the Phase 4 receipt.

      This task records HUI-C4 evidence in
      `docs/architecture/hypermedia-ui-milestone-c-phase-04-receipt.md`.

      - [ ] 4.4.2.1 Subtask - Keep HUI-C4 merge-pending on unreviewed query, unbounded read, cross-scope disclosure/inference, stale hidden rows, fabricated readiness, identity conflation, or read-side effect.
      - [ ] 4.4.2.2 Subtask - Record query/view-model/fixture/limit/cache evidence, failures, limitations, and all reopening conditions.
      - [ ] 4.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 4 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 5.
