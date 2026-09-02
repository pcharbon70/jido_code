---
id: plan.jido_code_hypermedia_ui_milestone_f_phase_02
parent_plan: plan.jido_code_hypermedia_ui_milestone_f
status: proposed
intent: feature
---

# Milestone F Phase 2 - Accessible Visualization And Export Components

This phase builds application-owned lens presentation and export primitives
that choose the smallest useful visual form and always preserve semantic access.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Deliver bounded accessible tables, trees, timelines, matrices, networks, details, and exports.

  This phase closes HUI-F2 by making visualization a reviewed view of typed
  lens results rather than a client-side raw graph explorer.

  - [ ] 2.1 Section - Implement core semantic visualization composites.

    This section covers common questions with table, tree, timeline, matrix,
    metric, and summary forms before considering node-link views.

    - [ ] 2.1.1 Task {#huif-p02-semantic-views} [repo: jido_code] [after: {#huif-p01-phase-receipt}] - Implement bounded table/tree/timeline/matrix components.

      This task consumes typed view models only and exposes provenance,
      completeness, state, and bounds consistently.

      - [ ] 2.1.1.1 Subtask - Implement accessible sortable/paged tables, disclosure trees, causal timelines, dependency matrices, metrics/small multiples, legends, summaries, and provenance/state banners.
      - [ ] 2.1.1.2 Subtask - Define task-to-view selection rules, required semantic structure, row/node/level/series limits, truncation summaries, and fallback when a view exceeds bounds.
      - [ ] 2.1.1.3 Subtask - Preserve native links/forms, deep links, selected entity, focus/reading order/scroll, paused live updates, print, and stable fragment roots.
      - [ ] 2.1.1.4 Subtask - Qualify keyboard, screen reader, zoom/reflow, touch, RTL, reduced motion, forced colors, color independence, narrow screens, and no-JS behavior.

  - [ ] 2.2 Section - Implement constrained relationship visualization.

    This section permits node-link views only for bounded path, neighborhood,
    lineage, or dependency questions with equivalent structured alternatives.

    - [ ] 2.2.1 Task {#huif-p02-network} [repo: jido_code] [after: {#huif-p02-semantic-views}] - Implement the bounded node-link composite and selection contract.

      This task prohibits a whole-factory hairball and keeps server view models,
      not client traversal, in control of nodes and edges.

      - [ ] 2.2.1.1 Subtask - Accept only typed bounded node/edge/legend/summary data with deterministic layout seed, allowed relationship types, and explicit depth/node/edge caps.
      - [ ] 2.2.1.2 Subtask - Implement keyboard selection/traversal, focus indication, textual relationship descriptions, zoom/pan/reset limits, reduced-motion behavior, and no auto-layout instability during patches.
      - [ ] 2.2.1.3 Subtask - Provide synchronized table/tree/path alternatives, current selection detail, provenance, truncation, and downloadable data only through authorized routes.
      - [ ] 2.2.1.4 Subtask - Reject client expansion/traversal, hidden offscreen protected data, arbitrary predicates, raw IRIs, force-layout denial-of-service, and color-only categories.

  - [ ] 2.3 Section - Implement detail and export workflows.

    This section keeps expanded evidence and downloads inside the exact lens,
    field, scope, bound, revocation, and audit envelope.

    - [ ] 2.3.1 Task {#huif-p02-export} [repo: jido_code] [after: {#huif-p02-network}] - Implement separately authorized detail and bounded export services.

      This task prevents a harmless view from becoming an unrestricted bulk
      extraction channel.

      - [ ] 2.3.1.1 Subtask - Add detail routes by opaque ref with exact resource/field authorization, provenance/integrity/revision/retention, safe previews, breadcrumbs, and return focus.
      - [ ] 2.3.1.2 Subtask - Add bounded synchronous export or governed asynchronous export jobs with lens/query/version/scope binding, row/byte/time/rate limits, expiry, cancellation, and audit receipt.
      - [ ] 2.3.1.3 Subtask - Defend CSV/formula, HTML, JSON, Unicode, filename/content-disposition, compression, cache, log/referrer, and protected-field risks in every format.
      - [ ] 2.3.1.4 Subtask - Reauthorize at job admission, generation, retrieval, and each page/part; terminate/conceal on session/role/delegation/project/graph revocation.

  - [ ] 2.4 Section - Phase 2 Integration Tests.

    This final section proves visualization and export remain bounded,
    equivalent, accessible, scoped, stable under patches, and safe with hostile data.

    - [ ] 2.4.1 Task {#huif-p02-integration} [repo: jido_code] [after: {#huif-p02-export}] - Execute the HUI-F2 visualization, detail, and export matrix.

      This task exercises large/truncated results, every accessibility mode,
      live refresh, hostile content, revocation, and export abuse.

      - [ ] 2.4.1.1 Subtask - Exercise each component and task-selection rule across ready/empty/stale/partial/truncated/concealed/unavailable/error states and minimum/maximum data sizes.
      - [ ] 2.4.1.2 Subtask - Exercise keyboard/screen reader/zoom/touch/RTL/reduced motion/forced colors/no-JS/print, selection/focus/scroll, live patches, and equivalent alternatives.
      - [ ] 2.4.1.3 Subtask - Exercise client traversal attempts, node/edge/series overflow, hostile labels, CSV/formula/filename/JSON/HTML attacks, export limits/expiry/cancellation, IDOR, and revocation.
      - [ ] 2.4.1.4 Subtask - Run browser/accessibility/security/load/architecture suites, `mix precommit`, and clean-checkout CI.

    - [ ] 2.4.2 Task {#huif-p02-phase-receipt} [repo: jido_code] [after: {#huif-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records HUI-F2 evidence in
      `docs/architecture/hypermedia-ui-milestone-f-phase-02-receipt.md`.

      - [ ] 2.4.2.1 Subtask - Keep HUI-F2 merge-pending on inaccessible meaning, missing equivalent view, unbounded graph/render/export, client traversal, focus instability, unsafe content/format, or export authority widening.
      - [ ] 2.4.2.2 Subtask - Record component/view-selection/limit/browser/AT/export evidence, failures, limitations, and all reopening conditions.
      - [ ] 2.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 2 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 3.
