---
id: plan.jido_code_hypermedia_ui_milestone_f_phase_04
parent_plan: plan.jido_code_hypermedia_ui_milestone_f
status: proposed
intent: feature
---

# Milestone F Phase 4 - Wiki, Dependency, Memory, Security, And Dataset Lenses

This phase implements repository-wiki/dependency experiences and the more
sensitive memory, policy/security/audit, incident, dataset, and curation lenses.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Deliver governed repository knowledge and sensitive-domain lenses.

  This phase closes HUI-F4 by preserving repository isolation, opt-out,
  preview fences, token/cost governance, data minimization, and exact grants.

  - [ ] 4.1 Section - Implement repository wiki and Mix dependency lenses.

    This section presents each enrolled repository's compiled knowledge,
    user/developer guides, project metadata, and complete resolved dependency closure.

    - [ ] 4.1.1 Task {#huif-p04-wiki} [repo: jido_code] [after: {#huif-p03-phase-receipt}] - Implement wiki overview, navigation, pages, coverage, and preview views.

      This task treats editions as provenance-bearing projections and respects
      enrollment/read/preview/review/activation boundaries.

      - [ ] 4.1.1.1 Subtask - Render overview, architecture, source map, decisions, documentation index, developer guide, user guide, provenance, known gaps, freshness, coverage, and edition history.
      - [ ] 4.1.1.2 Subtask - Render current/superseded/preview/incomplete/invalid edition state, source revision/fence, compiler/profile/digest, lint/review/activation, and maintainer trigger/status.
      - [ ] 4.1.1.3 Subtask - Enforce repository/project/read/preview grants, isolated parallel previews, one-current-edition fence, safe Markdown/HTML/links, bounded history/diffs, and source links.
      - [ ] 4.1.1.4 Subtask - Hide disabled read surfaces, show off/manual/automatic effective enrollment honestly, and ensure views never authorize compilation, activation, publication, merge, or command effects.

    - [ ] 4.1.2 Task {#huif-p04-dependencies} [repo: jido_code] [after: {#huif-p04-wiki}] - Implement Mix project and complete dependency catalog views.

      This task presents normalized `mix.exs` and resolved lock knowledge with
      source/provenance, completeness, and safe external references.

      - [ ] 4.1.2.1 Subtask - Render project app/version/elixir/start_permanent/umbrella/paths/aliases/compilers/applications metadata with extraction mode, source revision, confidence, and gaps.
      - [ ] 4.1.2.2 Subtask - Render direct/transitive/path/git/Hex/optional/missing/unresolved dependencies with requirement, resolved version/ref, checksum/source, environment/runtime flags, parent paths, and completeness.
      - [ ] 4.1.2.3 Subtask - Render approved package/source/docs/license/advisory links and metadata provenance/cache age without live browser fetch or unsafe repository-controlled URLs.
      - [ ] 4.1.2.4 Subtask - Provide table/tree/dependency matrix and bounded neighborhood alternatives with cycle handling, truncation, inaccessible transitive nodes, and export limits.

  - [ ] 4.2 Section - Implement wiki enrollment, maintainer, token, and cost governance views.

    This section makes generation opt-in and accounting observable without
    allowing a UI preference to override repository policy.

    - [ ] 4.2.1 Task {#huif-p04-wiki-governance} [repo: jido_code] [after: {#huif-p04-dependencies}] - Implement enrollment, update-stage, budget, usage, and failure projections.

      This task surfaces deterministic zero-token and synthesis accounting
      through existing reviewed wiki interfaces.

      - [ ] 4.2.1.1 Subtask - Render configured/effective enrollment, generation modes, trigger/stage, maintainer lease/health, source fence, current/preview edition, last success/failure/cancellation, stale reason, and next eligible update.
      - [ ] 4.2.1.2 Subtask - Render reservation, input/output/cache/total tokens, provider/model/profile, price revision/currency, measured/estimated/final cost, budget/threshold, attribution, and terminal accounting.
      - [ ] 4.2.1.3 Subtask - Distinguish deterministic zero-token evidence, synthesis disabled/unconfigured/denied/budget-exhausted/cancelled/late-result outcomes, and incomplete provider reporting.
      - [ ] 4.2.1.4 Subtask - Enforce knowledge/cost/admin field scopes, repository isolation, history/export bounds, privacy, and no generation or policy mutation in lens routes.

  - [ ] 4.3 Section - Implement sensitive memory, security, incident, and dataset lenses.

    This section minimizes protected content and exposes derived explanations
    rather than unrestricted memory/event/dataset dumps.

    - [ ] 4.3.1 Task {#huif-p04-sensitive} [repo: jido_code] [after: {#huif-p04-wiki-governance}] - Implement memory, policy, security/audit, and incident read lenses.

      This task reserves sensitive views for exact graph/field grants and
      preserves claim, actor, decision, effect, and evidence distinctions.

      - [ ] 4.3.1.1 Subtask - Implement memory provenance/consolidation/contradiction/retention/satisfaction summaries with content minimization, classification, confidence, and source/evidence links.
      - [ ] 4.3.1.2 Subtask - Implement current policy/grant/delegation/assurance/revocation explanations without exposing reusable credentials, hidden grants, raw policy internals, or other subjects' protected data.
      - [ ] 4.3.1.3 Subtask - Implement security/audit/incident summaries and causal timelines with named actor, detection/decision/effect/verification separation, protected evidence links, retention, and no unrestricted log viewer.
      - [ ] 4.3.1.4 Subtask - Enforce heightened assurance, separately authorized detail/export, concealment/inference controls, audit of access, and immediate live revocation.

    - [ ] 4.3.2 Task {#huif-p04-datasets} [repo: jido_code] [after: {#huif-p04-sensitive}] - Implement dataset, sample, binding, snapshot, curation, and lineage lenses.

      This task exposes dataset readiness and provenance without bypassing
      classification, license, retention, or use restrictions.

      - [ ] 4.3.2.1 Subtask - Render dataset identity/purpose/classification/license/owner, sample/binding/snapshot/curation lineage, integrity, source revisions, quality, readiness, retention, and limitations.
      - [ ] 4.3.2.2 Subtask - Provide bounded metadata/table/lineage/path views and minimized previews; prohibit arbitrary row dumps, hidden columns, and browser-controlled joins.
      - [ ] 4.3.2.3 Subtask - Enforce tenant/project/dataset/field/use-purpose grants, consent/license restrictions, download/export bounds, expiry, watermark/audit policy where accepted, and revocation.
      - [ ] 4.3.2.4 Subtask - Show unconfigured/missing/stale/incomplete/invalid/unsupported datasets honestly and never imply training/evaluation readiness from existence alone.

  - [ ] 4.4 Section - Phase 4 Integration Tests.

    This final section proves wiki/dependency and sensitive lenses preserve
    isolation, opt-out, accounting, minimization, accessibility, and provenance.

    - [ ] 4.4.1 Task {#huif-p04-integration} [repo: jido_code] [after: {#huif-p04-datasets}] - Execute the HUI-F4 repository-knowledge and sensitive-lens matrix.

      This task uses real wiki/memory/security/dataset graph fixtures, parallel
      previews, roles, hostile content, large closures, and revocation.

      - [ ] 4.4.1.1 Subtask - Exercise wiki enrollment/read/preview/edition/guide/coverage/freshness/maintainer and Mix metadata/dependency completeness/cycle/missing/source/link cases across repositories.
      - [ ] 4.4.1.2 Subtask - Exercise deterministic zero-token, synthesis disabled/unconfigured/reservation/usage/final cost/budget/cancellation/late result, opt-out during work, and concurrent preview/current-edition fences.
      - [ ] 4.4.1.3 Subtask - Exercise memory/security/audit/incident/dataset classification, minimization, IDOR/inference, hostile content, detail/export, assurance, audit, revocation, and accessible alternatives.
      - [ ] 4.4.1.4 Subtask - Run real-store/wiki/browser/accessibility/security/load/architecture suites, `mix precommit`, and clean-checkout CI.

    - [ ] 4.4.2 Task {#huif-p04-phase-receipt} [repo: jido_code] [after: {#huif-p04-integration}] - Publish and pin the Phase 4 receipt.

      This task records HUI-F4 evidence in
      `docs/architecture/hypermedia-ui-milestone-f-phase-04-receipt.md`.

      - [ ] 4.4.2.1 Subtask - Keep HUI-F4 merge-pending on repository/preview leak, unsafe wiki content/link, incomplete dependency closure mislabeled complete, opt-out/accounting failure, sensitive memory/audit/dataset disclosure, or authority-widening lens.
      - [ ] 4.4.2.2 Subtask - Record query/view/wiki/accounting/security/dataset/browser evidence, failures, limitations, and all reopening conditions.
      - [ ] 4.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 4 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 5.
