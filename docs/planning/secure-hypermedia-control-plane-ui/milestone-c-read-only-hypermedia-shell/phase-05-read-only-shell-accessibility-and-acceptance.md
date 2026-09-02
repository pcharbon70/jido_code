---
id: plan.jido_code_hypermedia_ui_milestone_c_phase_05
parent_plan: plan.jido_code_hypermedia_ui_milestone_c
status: proposed
intent: feature
---

# Milestone C Phase 5 - Read-Only Shell Accessibility And Acceptance

This phase qualifies the complete native read-only product with real adapters,
supported browsers, assistive technology, responsive layouts, hostile scopes,
and production-like operations before live delivery is allowed.

Back to plan: [README](./README.md)

- [ ] 5 Phase - Accept the secure native read-only shell at a merged candidate.

  This phase closes HUI-C5 and HUI3 by proving identity, routes, components,
  and projections work together without JavaScript or semantic side effects.

  - [ ] 5.1 Section - Complete native browser and accessibility qualification.

    This section validates full user journeys rather than isolated components
    and treats essential workflow failures as release blockers.

    - [ ] 5.1.1 Task {#huic-p05-accessibility} [repo: jido_code] [after: {#huic-p04-phase-receipt}] - Run WCAG 2.2 AA and assistive-technology qualification.

      This task proves named users can navigate, understand, and recover across
      the complete read-only shell.

      - [ ] 5.1.1.1 Subtask - Audit semantics, landmarks/headings, labels/descriptions/errors, names/roles/values, focus order/visibility, status messages, link purpose, and target size.
      - [ ] 5.1.1.2 Subtask - Exercise keyboard-only, supported screen readers, 200/400 percent zoom/reflow, touch, RTL, reduced motion, forced colors/high contrast, themes, print, and narrow widths.
      - [ ] 5.1.1.3 Subtask - Exercise sign-in/session, factory triage, project switching, project/attempt drill-down, filtering/pagination, errors, stale/unavailable states, and restricted-area denial.
      - [ ] 5.1.1.4 Subtask - Remediate violations and record exact browser/AT/version evidence, known limitations, owners, expiry, and reopening conditions.

  - [ ] 5.2 Section - Qualify real adapters, capacity, privacy, and operations.

    This section proves shell behavior under production-sized data, outages,
    revocation, and cache/log/referrer constraints.

    - [ ] 5.2.1 Task {#huic-p05-operations} [repo: jido_code] [after: {#huic-p05-accessibility}] - Execute production-like read-path and failure qualification.

      This task establishes latency/resource ceilings and honest degraded
      behavior before automatic live refresh can add load.

      - [ ] 5.2.1.1 Subtask - Test real identity, TripleStore, filesystem/readiness, and asset adapters with supported browser/OS/proxy/TLS profiles and production builds.
      - [ ] 5.2.1.2 Subtask - Measure page/query/render latency, memory, rows/bytes, cache behavior, large fleet pagination, several users/tabs, and rate/resource bounds against declared thresholds.
      - [ ] 5.2.1.3 Subtask - Exercise identity/store/asset outage, graph lag, timeout, deploy restart, stale cache, revocation, clock skew, malformed/hostile content, and maintenance/read-only fallback.
      - [ ] 5.2.1.4 Subtask - Verify no protected response caching, referrer/log/telemetry leakage, raw IRI exposure, secret rendering, or cross-scope diagnostic detail.

  - [ ] 5.3 Section - Assemble the HUI3 product baseline.

    This section reconciles route, component, projection, security, and human
    evidence and freezes the stable roots Milestone D may enhance.

    - [ ] 5.3.1 Task {#huic-p05-baseline} [repo: jido_code] [after: {#huic-p05-operations}] - Publish the accepted native shell and fragment-candidate manifest.

      This task defines the exact pages, projection roots, DOM IDs, focus
      targets, and state envelopes live delivery must preserve.

      - [ ] 5.3.1.1 Subtask - Inventory every accepted route/view model/component/root/state/focus target, authorization owner, query/limit, native interaction, and unsupported placeholder.
      - [ ] 5.3.1.2 Subtask - Reconcile identity/session/revocation, component/design, projection/cache, readiness, wiki opt-out/cost, and accessibility evidence.
      - [ ] 5.3.1.3 Subtask - Define Milestone D enhancement candidates and prohibit changes that break native behavior, stable identity, field authorization, or truthful state.
      - [ ] 5.3.1.4 Subtask - Create `hypermedia-ui-milestone-c-phase-05-receipt.md` in merge-pending state with HUI-C5/HUI3 evidence and reopening conditions.

  - [ ] 5.4 Section - Phase 5 Integration Tests.

    This final section reruns the complete read-only shell from clean checkout
    across native browsers, real adapters, several scopes, and failure modes.

    - [ ] 5.4.1 Task {#huic-p05-integration} [repo: jido_code] [after: {#huic-p05-baseline}] - Execute the HUI-C5/HUI3 release acceptance matrix.

      This task closes Milestone C only when all prior C gates remain true in
      one production-like candidate.

      - [ ] 5.4.1.1 Subtask - Run end-to-end identity/session/scope/revocation, route/navigation, attention/fleet/project/attempt, projection-state, and no-effect scenarios.
      - [ ] 5.4.1.2 Subtask - Run cross-scope IDOR/inference, hostile content, privacy/cache/log, large fleet, parallel users/tabs, adapter outage, restart, and unconfigured capability scenarios.
      - [ ] 5.4.1.3 Subtask - Run complete native supported-browser and manual accessibility journeys with production assets and exact candidate configuration.
      - [ ] 5.4.1.4 Subtask - Run all Milestone C and prior regression suites, architecture/security/a11y checks, `mix precommit`, and clean-checkout CI.

    - [ ] 5.4.2 Task {#huic-p05-phase-receipt} [repo: jido_code] [after: {#huic-p05-integration}] - Publish and pin the Phase 5 receipt and HUI3 closure.

      This task records HUI-C5/HUI3 evidence in
      `docs/architecture/hypermedia-ui-milestone-c-phase-05-receipt.md`.

      - [ ] 5.4.2.1 Subtask - Keep HUI3 merge-pending on identity/scope leak, route/projection gap, broken native path, inaccessible critical journey, unbounded read, false readiness, effectful read, or non-reproducible adapter evidence.
      - [ ] 5.4.2.2 Subtask - Record exact candidate/config/route/query/component/browser/AT/adapter evidence, exceptions, limitations, and every reopening condition.
      - [ ] 5.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 5 Integration Tests section, receipt task, pinning subtask, and Milestone C completion before authorizing Milestone D Phase 1.
