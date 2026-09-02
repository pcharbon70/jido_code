---
id: plan.jido_code_hypermedia_ui_milestone_g_phase_03
parent_plan: plan.jido_code_hypermedia_ui_milestone_g
status: proposed
intent: feature
---

# Milestone G Phase 3 - Accessibility And Assistive-Technology Qualification

This phase performs whole-product WCAG 2.2 AA and supported assistive-
technology qualification across native and enhanced modes.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Prove equivalent access to every critical control-plane workflow.

  This phase closes HUI-G3 with manual and automated evidence for pages,
  dynamic updates, forms, overlays, timelines, graphs, commands, and incidents.

  - [ ] 3.1 Section - Audit semantics, input, navigation, and status behavior.

    This section validates perceivability, operability, understandability, and
    robustness at the complete composition and workflow level.

    - [ ] 3.1.1 Task {#huig-p03-audit} [repo: jido_code] [after: {#huig-p02-phase-receipt}] - Execute the WCAG 2.2 AA conformance audit.

      This task maps each applicable success criterion to exact product
      surfaces, tests, manual evidence, findings, and owners.

      - [ ] 3.1.1.1 Subtask - Audit document language/title, landmarks/headings, reading order, labels/instructions/help/errors, names/roles/values, tables/lists, links, and status semantics.
      - [ ] 3.1.1.2 Subtask - Audit keyboard access, focus order/visibility/not-obscured/return, skip navigation, no traps, target size, pointer gestures, drag alternatives, timing, reauthentication, and error prevention.
      - [ ] 3.1.1.3 Subtask - Audit contrast/non-color meaning, text spacing, zoom/reflow, orientation, reduced motion/flashing, forced colors/high contrast, RTL, touch, responsive, and print behavior.
      - [ ] 3.1.1.4 Subtask - Audit live status/freshness/reconnect/updates, paused updates, loading/error/denial, dialogs/disclosures/menus/tooltips, commands/confirmations, and session expiry announcements.

  - [ ] 3.2 Section - Qualify data-rich and security-sensitive workflows.

    This section focuses on timelines, graph views, diffs/evidence, costs,
    approvals, and incidents where visual density and dynamic state create risk.

    - [ ] 3.2.1 Task {#huig-p03-complex} [repo: jido_code] [after: {#huig-p03-audit}] - Validate accessible alternatives and critical action understanding.

      This task ensures equivalent meaning and consequence are available
      without vision, color, fine pointer control, animation, or wide layout.

      - [ ] 3.2.1.1 Subtask - Verify every chart/network/matrix/timeline/diff/log/evidence view has semantic summary, structured table/tree/text alternative, legend, truncation/freshness/provenance, and bounded keyboard navigation.
      - [ ] 3.2.1.2 Subtask - Verify command/review/incident previews identify exact target/scope/consequence/current state/assurance/reason and errors/conflicts/receipts are announced and recoverable.
      - [ ] 3.2.1.3 Subtask - Verify cost/budget/wiki-token values include units, estimate/final/completeness status, thresholds, and non-color warnings understandable to assistive technology.
      - [ ] 3.2.1.4 Subtask - Verify protected/concealed/revoked/expired content is replaced safely without focus loss, repeated announcements, stale accessible names, or hidden DOM disclosure.

  - [ ] 3.3 Section - Complete supported browser and assistive-technology evidence.

    This section runs critical journeys with named browser/OS/screen-reader
    combinations and remediates all release-blocking findings.

    - [ ] 3.3.1 Task {#huig-p03-at} [repo: jido_code] [after: {#huig-p03-complex}] - Execute manual AT and alternate-input journey tests.

      This task records actual behavior, not a claim inferred from component
      semantics or automated scanner results.

      - [ ] 3.3.1.1 Subtask - Run sign-in/session, attention/fleet/project, attempt/timeline, command/recovery, review, cost/wiki, lens/export, incident, and error/degraded journeys with supported screen readers.
      - [ ] 3.3.1.2 Subtask - Run the same critical journeys keyboard-only, at 200/400 percent zoom/reflow, narrow/touch, RTL, reduced motion, forced colors/high contrast, no-JS, and Datastar modes.
      - [ ] 3.3.1.3 Subtask - Test reconnect/live updates, rapid status changes, validation/conflicts, step-up/session expiry, revocation, long/hostile content, large tables/graphs, and concurrent tabs.
      - [ ] 3.3.1.4 Subtask - Remediate failures, rerun affected journeys, and record exact browser/OS/AT/assets/config, evidence, remaining limitations, owners, and expiry.

  - [ ] 3.4 Section - Phase 3 Integration Tests.

    This final section proves conformance evidence is complete, reproducible,
    candidate-specific, and covers all critical product workflows.

    - [ ] 3.4.1 Task {#huig-p03-integration} [repo: jido_code] [after: {#huig-p03-at}] - Execute the HUI-G3 accessibility acceptance matrix.

      This task combines automated rules, component tests, keyboard/manual AT,
      responsive modes, native/enhanced behavior, and regression coverage.

      - [ ] 3.4.1.1 Subtask - Run automated accessibility scans and semantic/DOM/focus/status tests on every route/state/component/overlay/visualization at production assets/config.
      - [ ] 3.4.1.2 Subtask - Complete manual keyboard, screen-reader, zoom/reflow, touch, RTL, reduced-motion, forced-colors, no-JS, and enhanced journeys with zero critical blockers.
      - [ ] 3.4.1.3 Subtask - Verify every finding maps to fix/rerun or accepted noncritical exception with impact, workaround, owner, expiry, and reopening condition.
      - [ ] 3.4.1.4 Subtask - Run all accessibility/browser regressions, `mix precommit`, and clean-checkout CI against the exact candidate.

    - [ ] 3.4.2 Task {#huig-p03-phase-receipt} [repo: jido_code] [after: {#huig-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records HUI-G3 evidence in
      `docs/architecture/hypermedia-ui-milestone-g-phase-03-receipt.md`.

      - [ ] 3.4.2.1 Subtask - Keep HUI-G3 merge-pending on inaccessible critical workflow, missing graph alternative, keyboard/focus/status failure, unsupported required browser/AT, incomplete rerun, or unowned exception.
      - [ ] 3.4.2.2 Subtask - Record criterion/surface/test/browser/OS/AT evidence, findings/remediation, exceptions, owners, expiry, and all reopening conditions.
      - [ ] 3.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 3 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 4.
