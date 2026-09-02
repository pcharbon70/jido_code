---
id: plan.jido_code_hypermedia_ui_milestone_f_phase_03
parent_plan: plan.jido_code_hypermedia_ui_milestone_f
status: proposed
intent: feature
---

# Milestone F Phase 3 - Source, Domain, Execution, And Evidence Lenses

This phase delivers the developer-facing operational lenses for repository
source, project domain, planned/current work, execution, evidence, costs, and
derived diagnostics.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Implement the core development and execution knowledge lenses.

  This phase closes HUI-F3 by answering common developer questions through
  reviewed projections and task-appropriate views rather than raw graph data.

  - [ ] 3.1 Section - Implement source and project-domain lenses.

    This section makes repository structure, symbols, relationships, concepts,
    and coverage navigable with safe provenance and bounded relationships.

    - [ ] 3.1.1 Task {#huif-p03-source} [repo: jido_code] [after: {#huif-p02-phase-receipt}] - Implement source structure, symbol, relation, and provenance pages.

      This task exposes accepted source analysis only and remains honest when a
      repository has not been observed or indexed.

      - [ ] 3.1.1.1 Subtask - Implement source overview/tree, module/file/symbol lookup, incoming/outgoing relations, diagnostics, observation revision, coverage/gaps, and source provenance.
      - [ ] 3.1.1.2 Subtask - Use table/tree and small bounded neighborhood/path views with typed relation legends, depth/node/edge limits, and textual alternatives.
      - [ ] 3.1.1.3 Subtask - Link source locations through registered repository roots/revisions with path traversal/symlink/secret/generated/oversized protections and no arbitrary filesystem browse.
      - [ ] 3.1.1.4 Subtask - Represent unobserved/stale/partial/contradictory/unsupported language or relation data explicitly and never infer complete code understanding.

    - [ ] 3.1.2 Task {#huif-p03-domain} [repo: jido_code] [after: {#huif-p03-source}] - Implement project-domain concept and source-alignment lenses.

      This task connects accepted domain knowledge to source and work evidence
      without collapsing propositions, claims, documentation, and code symbols.

      - [ ] 3.1.2.1 Subtask - Implement concept/entity/relation, glossary, domain boundary, accepted proposition, source alignment, contradiction, provenance, and freshness views.
      - [ ] 3.1.2.2 Subtask - Distinguish authored documentation, inferred/derived claims, accepted knowledge, source observation, and unresolved ambiguity/conflict.
      - [ ] 3.1.2.3 Subtask - Use bounded tables/trees/matrices/path views with exact allowed joins and separately authorized source/evidence details.
      - [ ] 3.1.2.4 Subtask - Prevent labels, inferred links, or project alias from widening repository/tenant/graph authority or manufacturing multi-repository domain scope.

  - [ ] 3.2 Section - Implement work, execution, and evidence lenses.

    This section provides cross-attempt analysis while preserving task,
    attempt, interaction, effect, evidence, decision, and outcome identities.

    - [ ] 3.2.1 Task {#huif-p03-execution} [repo: jido_code] [after: {#huif-p03-domain}] - Implement work and execution overview lenses.

      This task complements the per-attempt workspace with bounded comparisons,
      timelines, handoff/recovery, and lifecycle/outcome analysis.

      - [ ] 3.2.1.1 Subtask - Implement task/attempt queue, lifecycle/outcome matrix, agent/profile/runtime usage, lease/fence, handoff/recovery, candidate/publication/application, and satisfaction summaries.
      - [ ] 3.2.1.2 Subtask - Provide authorized filter/sort/page/time windows and table/timeline/matrix/small-multiple views across repositories/attempts without cross-scope joins.
      - [ ] 3.2.1.3 Subtask - Show process/runtime availability separately from semantic progress and distinguish requested/admitted/dispatched/effected/verified/decided/applied states.
      - [ ] 3.2.1.4 Subtask - Link to attempt workspaces and receipts using opaque refs, current authorization, bounded related counts, and explicit truncated/partial states.

    - [ ] 3.2.2 Task {#huif-p03-evidence} [repo: jido_code] [after: {#huif-p03-execution}] - Implement evidence, review, outcome, and cost-efficiency lenses.

      This task lets humans trace claims to independent proof and compare cost
      only where attribution/completeness is trustworthy.

      - [ ] 3.2.2.1 Subtask - Implement claim/effect/artifact/verification/decision/receipt/publication/application/re-observation/satisfaction provenance chains and coverage/gap views.
      - [ ] 3.2.2.2 Subtask - Implement review state, verifier independence, stale evidence, contradiction, policy/risk, accepted/rejected/deferred outcome, and follow-up views.
      - [ ] 3.2.2.3 Subtask - Implement bounded tokens/cost/budget per provider/model/profile/repository/attempt/outcome/wiki edition with estimate/final/completeness/currency/price revision labels.
      - [ ] 3.2.2.4 Subtask - Provide table/timeline/matrix/path alternatives and separately authorized evidence/export without leaking protected content or implying unsupported causation.

  - [ ] 3.3 Section - Implement derived diagnostic and fleet knowledge lenses.

    This section surfaces safe derived health, inconsistency, and coverage views
    while keeping derivation identity and source revisions visible.

    - [ ] 3.3.1 Task {#huif-p03-derived} [repo: jido_code] [after: {#huif-p03-evidence}] - Implement diagnostics, drift, coverage, and attention-analysis lenses.

      This task treats derived graphs as rebuildable projections, not a new
      authority or opaque scoring system.

      - [ ] 3.3.1.1 Subtask - Implement stale/contradictory/missing coverage, desired/current drift, repeated failure, verification gap, cost anomaly, wiki staleness, and attention-quality summaries.
      - [ ] 3.3.1.2 Subtask - Show derivation/query/profile version, input graph revisions, evaluated-at/freshness, completeness, thresholds, explanation, and rebuild state.
      - [ ] 3.3.1.3 Subtask - Bound rankings/scores, prohibit sensitive cross-scope comparison, expose uncertainty/false-positive posture, and link to source projections.
      - [ ] 3.3.1.4 Subtask - Register live fragments/subscriptions with safe coalescing, paused updates, current re-query, revocation, and convergence.

  - [ ] 3.4 Section - Phase 3 Integration Tests.

    This final section proves core development lenses are useful, bounded,
    provenance-rich, scoped, accessible, and honest across incomplete data.

    - [ ] 3.4.1 Task {#huif-p03-integration} [repo: jido_code] [after: {#huif-p03-derived}] - Execute the HUI-F3 source, domain, execution, evidence, and diagnostics matrix.

      This task exercises real graph adapters, large repositories/attempt sets,
      hostile content, joins, revocation, and live updates.

      - [ ] 3.4.1.1 Subtask - Exercise every registered source/domain/work/execution/evidence/cost/derived query, view, filter/page/bound, state, provenance, and detail/export path.
      - [ ] 3.4.1.2 Subtask - Exercise unobserved/stale/partial/contradictory data, hostile paths/labels, unsupported language, high-volume relations/events, derived drift, rebuild, and false-positive explanations.
      - [ ] 3.4.1.3 Subtask - Exercise cross-tenant/project/repository/attempt/interaction/evidence/graph IDOR/inference, cache/export/revocation, live convergence, and accessible alternatives.
      - [ ] 3.4.1.4 Subtask - Run real-store/browser/accessibility/security/load/architecture suites, `mix precommit`, and clean-checkout CI.

    - [ ] 3.4.2 Task {#huif-p03-phase-receipt} [repo: jido_code] [after: {#huif-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records HUI-F3 evidence in
      `docs/architecture/hypermedia-ui-milestone-f-phase-03-receipt.md`.

      - [ ] 3.4.2.1 Subtask - Keep HUI-F3 merge-pending on unreviewed/unbounded query, identity/claim/evidence conflation, cross-scope join, unsafe source path, unexplained derived score, inaccessible view, or provenance gap.
      - [ ] 3.4.2.2 Subtask - Record query/view/bound/graph/browser/load evidence, failures, limitations, and all reopening conditions.
      - [ ] 3.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 3 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 4.
