---
id: plan.jido_code_secure_hypermedia_control_plane_ui_phase_06
parent_plan: plan.jido_code_secure_hypermedia_control_plane_ui
status: proposed
intent: feature
---

# Secure Hypermedia Control Plane UI Phase 6 — Knowledge And Wiki Lenses

This phase implements Milestone F and closes HUI6 by exposing every enabled
graph family through an explicit, reviewed, bounded, provenance-rich lens. It
adds useful tables, trees, timelines, matrices, and selective node-link views
without exposing unrestricted graph traversal, raw SPARQL, or hidden memory.

Back to plan: [README](./README.md)

- [ ] 6 Phase — Deliver authorized knowledge, dependency, memory, and wiki lenses.

  This phase turns graph truth into task-oriented human views while preserving
  graph-family isolation, exact grants, concealment, and truthful readiness.

  - [ ] 6.1 Section — Implement the closed lens catalog and query envelopes.

    This section converts the approved mapping of graph families to product
    lenses into explicit public queries, view models, limits, and provenance.

    - [ ] 6.1.1 Task {#hui-p06-catalog} [repo: jido_code] [after: {#hui-p05-phase-receipt}] — Implement the reviewed lens registry.

      This task registers only named product questions and authorized graph-family
      combinations; absence from the registry means no product query or route.

      - [ ] 6.1.1.1 Subtask — Register the ten approved lenses and map all seventeen graph families to owner, route, question, audience, sensitivity, and readiness.
      - [ ] 6.1.1.2 Subtask — Declare per-lens resource/scope inputs, allowed joins, sort/filter/search fields, page/depth/node/edge/time/byte limits, and timeout/cancellation policy.
      - [ ] 6.1.1.3 Subtask — Declare field redaction, inference controls, provenance, revision/freshness, truncation, export, cache, and telemetry behavior.
      - [ ] 6.1.1.4 Subtask — Add architecture checks that reject unregistered lens routes, raw SPARQL/Knowledge internals, unrestricted traversal, and cross-family joins.

    - [ ] 6.1.2 Task {#hui-p06-queries} [repo: jido_code] [after: {#hui-p06-catalog}] — Implement public bounded lens query adapters.

      This task evaluates every lens through trusted scope and Product/Factory
      boundaries and returns explicit projection states rather than partial truth.

      - [ ] 6.1.2.1 Subtask — Implement prepared query templates and typed view models for repository health, source, domain, execution, evidence, cost, dependency, wiki, memory, security, and dataset concerns.
      - [ ] 6.1.2.2 Subtask — Enforce graph/field/resource authorization before query, after shaping, on pagination/export, and after live refresh or revocation.
      - [ ] 6.1.2.3 Subtask — Return loading, ready, empty, stale, partial, truncated, denied/concealed, unavailable, unconfigured, and error states with safe retry posture.
      - [ ] 6.1.2.4 Subtask — Prove deterministic bounds, cancellation, timeout, cache isolation, hostile-label safety, and no cross-project or cross-tenant inference.

  - [ ] 6.2 Section — Build task-appropriate and accessible visual components.

    This section chooses the smallest visualization that answers the user's
    question and always provides a semantic non-visual equivalent.

    - [ ] 6.2.1 Task {#hui-p06-visuals} [repo: jido_code] [after: {#hui-p06-queries}] — Implement reusable lens presentation components.

      This task adds JidoCode-owned table, tree, timeline, matrix, metric, and
      constrained node-link composites on top of the qualified primitive layer.

      - [ ] 6.2.1.1 Subtask — Implement sortable/paged tables, disclosure trees, causal timelines, dependency matrices, metrics, state/provenance banners, and truncation summaries.
      - [ ] 6.2.1.2 Subtask — Implement node-link diagrams only for bounded relationship questions with explicit legend, deterministic layout, zoom/pan limits, selection, and textual/table alternative.
      - [ ] 6.2.1.3 Subtask — Preserve selected entity, focus, reading order, route/deep-link context, native fallback, and live-update pause across fragment refresh.
      - [ ] 6.2.1.4 Subtask — Qualify keyboard, screen reader, zoom/reflow, touch, reduced motion, forced colors, color independence, RTL, print, and responsive layouts.

    - [ ] 6.2.2 Task {#hui-p06-export} [repo: jido_code] [after: {#hui-p06-visuals}] — Implement authorized lens detail and export workflows.

      This task keeps expanded detail and downloads inside the same scope,
      redaction, provenance, limit, audit, and revocation boundaries as the view.

      - [ ] 6.2.2.1 Subtask — Add separately authorized detail routes with stable opaque references, breadcrumbs, provenance, integrity, source revision, and return focus.
      - [ ] 6.2.2.2 Subtask — Add bounded synchronous exports or governed asynchronous export jobs with exact scope, format, row/byte/time limits, expiry, and audit receipts.
      - [ ] 6.2.2.3 Subtask — Apply CSV/formula, HTML, JSON, filename, content-disposition, cache, and protected-field defenses to every format.
      - [ ] 6.2.2.4 Subtask — Terminate or conceal detail/export access on role, delegation, graph, project, tenant, or session revocation.

  - [ ] 6.3 Section — Deliver domain, dependency, wiki, memory, and governance experiences.

    This section composes the registered lenses into developer workflows and
    keeps sensitive, disabled, and contract-only domains explicitly qualified.

    - [ ] 6.3.1 Task {#hui-p06-wiki-dependencies} [repo: jido_code] [after: {#hui-p06-export}] — Implement repository wiki and dependency lenses.

      This task presents each project's generated knowledge and Mix dependency
      context without crossing repository scopes or overstating freshness.

      - [ ] 6.3.1.1 Subtask — Render wiki overview, architecture, developer/user guides, decisions, provenance, coverage, generation status, freshness, review state, and links to source artifacts.
      - [ ] 6.3.1.2 Subtask — Render normalized `mix.exs` project metadata and dependency name, requirement, source, lock/version, environment/runtime flags, license/advisory posture, relationship, and approved external links.
      - [ ] 6.3.1.3 Subtask — Render wiki opt-in/opt-out/effective policy, updater health, last update cause/stage/attempt, token usage/cost, budget, failure, and stale/unavailable posture.
      - [ ] 6.3.1.4 Subtask — Enforce project isolation, safe Markdown/HTML, link policy, source provenance, bounded diffs/history, and no automatic disclosure of secrets or hidden memory.

    - [ ] 6.3.2 Task {#hui-p06-sensitive-lenses} [repo: jido_code] [after: {#hui-p06-wiki-dependencies}] — Implement memory, security, policy, dataset, and audit lenses.

      This task reserves sensitive lenses for exact grants and favors derived,
      minimized explanations over unrestricted event or memory browsing.

      - [ ] 6.3.2.1 Subtask — Implement safe memory provenance, consolidation, contradiction, retention, and satisfaction summaries with protected-content minimization.
      - [ ] 6.3.2.2 Subtask — Implement policy/security/incident/audit summaries with named identity, decision/effect separation, concealment, and separately authorized evidence.
      - [ ] 6.3.2.3 Subtask — Implement dataset/sample/binding/snapshot/curation views with lineage, integrity, licensing, readiness, and boundary posture.
      - [ ] 6.3.2.4 Subtask — Create `hypermedia-ui-phase-06-receipt.md` in merge-pending state with Gate HUI6 catalog coverage, graph isolation, accessibility, and reopening conditions.

  - [ ] 6.4 Section — Phase 6 Integration Tests.

    This final section proves every enabled graph domain is useful only through
    its reviewed envelope and remains bounded, accessible, isolated, and honest.

    - [ ] 6.4.1 Task {#hui-p06-integration} [repo: jido_code] [after: {#hui-p06-sensitive-lenses}] — Execute the HUI6 lens, visualization, wiki, and isolation matrix.

      This task closes knowledge delivery only across real graph adapters,
      sensitive grants, hostile content, large datasets, and revoked scopes.

      - [ ] 6.4.1.1 Subtask — Prove all enabled graph families have an approved lens or explicit unavailable posture and no unregistered/raw query path exists.
      - [ ] 6.4.1.2 Subtask — Exercise every query/field/join/page/depth/node/edge/time/byte/export bound plus truncation, timeout, cancellation, stale, error, and revocation behavior.
      - [ ] 6.4.1.3 Subtask — Exercise cross-project/tenant/graph IDOR and inference, hostile labels/Markdown/CSV, sensitive memory/evidence, wiki opt-out/cost, dependency metadata, and export expiry.
      - [ ] 6.4.1.4 Subtask — Run visual/browser/accessibility, real-adapter, load/resource, security, prior regression, `mix precommit`, and clean-checkout CI suites.

    - [ ] 6.4.2 Task {#hui-p06-phase-receipt} [repo: jido_code] [after: {#hui-p06-integration}] — Publish and pin the Phase 6 receipt.

      This task records Gate HUI6 evidence and authorizes release qualification
      only from the merged reviewed-lens baseline.

      - [ ] 6.4.2.1 Subtask — Keep HUI6 merge-pending on missing catalog coverage, unrestricted queries, cross-scope inference, unbounded visualization/export, inaccessible graph meaning, unsafe wiki content, or hidden-memory disclosure.
      - [ ] 6.4.2.2 Subtask — Record the full merge SHA/date, graph/lens matrix, exact limits, browser/accessibility/security/load evidence, failures, and limitations.
      - [ ] 6.4.2.3 Subtask — Pin the merged candidate commit and check the phase, Phase 6 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 7.
