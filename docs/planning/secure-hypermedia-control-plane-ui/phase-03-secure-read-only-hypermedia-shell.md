---
id: plan.jido_code_secure_hypermedia_control_plane_ui_phase_03
parent_plan: plan.jido_code_secure_hypermedia_control_plane_ui
status: proposed
intent: feature
---

# Secure Hypermedia Control Plane UI Phase 3 — Secure Read-Only Hypermedia Shell

This phase implements Milestone C and closes HUI3 by introducing named human
identity, one trusted authority builder, controller-rendered HEEx routes,
ShadcnUI application composites, and read-only attention/fleet/project/attempt
projections with native fallback.

Back to plan: [README](./README.md)

- [ ] 3 Phase — Deliver the authorized read-only control-plane shell.

  This phase establishes multi-user scope and useful factory visibility before
  Datastar live delivery or semantic controls are enabled.

  - [ ] 3.1 Section — Implement named identity and trusted product authority.

    This section replaces the shared operator as the identity foundation for
    new routes without widening existing grants.

    - [ ] 3.1.1 Task {#hui-p03-identity} [repo: jido_code] [after: {#hui-p02-phase-receipt}] — Implement named accounts, authenticators, and session lifecycle.

      This task creates the minimum secure and accessible authentication
      substrate required for role-scoped read routes.

      - [ ] 3.1.1.1 Subtask — Add named account/session status, nonce, generation, assurance, idle/absolute lifetime, inventory, revoke, and recovery contracts.
      - [ ] 3.1.1.2 Subtask — Integrate the selected phishing-resistant/accessibility-qualified authenticator and preserve password-manager/paste/passkey behavior.
      - [ ] 3.1.1.3 Subtask — Implement accessible expiry warning, reauthentication, safe unsent-form preservation, sign-out, and session-generation invalidation.
      - [ ] 3.1.1.4 Subtask — Retain the configured operator only as an explicitly isolated compatibility posture unavailable to multi-user production routes.

    - [ ] 3.1.2 Task {#hui-p03-authority} [repo: jido_code] [after: {#hui-p03-identity}] — Implement the shared trusted scope/identity/authority builder.

      This task gives controllers, fragments, future streams, APIs, and
      commands one server-derived authorization context.

      - [ ] 3.1.2.1 Subtask — Resolve current account, assurance, memberships, exact grants/delegations, route object/action, environment, and obligations on every request.
      - [ ] 3.1.2.2 Subtask — Replace fixed-nil delegation construction only with current trusted graph mappings and reject browser authority fields.
      - [ ] 3.1.2.3 Subtask — Map initial roles/navigation to exact capabilities and field classifications without implicit grant unions.
      - [ ] 3.1.2.4 Subtask — Prove controller/API identity parity, concealed unknown/unauthorized behavior, and field-level redaction.

  - [ ] 3.2 Section — Build the authenticated HEEx shell and route vocabulary.

    This section adds durable ordinary routes and responsive navigation while
    keeping every new page read-only.

    - [ ] 3.2.1 Task {#hui-p03-shell} [repo: jido_code] [after: {#hui-p03-authority}] — Implement `FactoryShell` and authorized navigation.

      This task composes identity, scope, health, attention counts, search,
      navigation, focus, and projection status through the JidoCode UI facade.

      - [ ] 3.2.1.1 Subtask — Implement landmarks, skip link, heading, focus target, identity/assurance, factory/project context, health/freshness, and sign-out.
      - [ ] 3.2.1.2 Subtask — Implement authorized global navigation for factory, projects, work, attempts, reviews, knowledge, operations, and restricted governance.
      - [ ] 3.2.1.3 Subtask — Implement responsive desktop/narrow layouts with native drawers and no hover-only essential state/action.
      - [ ] 3.2.1.4 Subtask — Clear stale project/attempt/candidate/preview/lens/filter selection on scope change and prove back/forward/bookmark behavior.

    - [ ] 3.2.2 Task {#hui-p03-routes} [repo: jido_code] [after: {#hui-p03-shell}] — Implement the read-only controller and HEEx route set.

      This task creates stable product URLs with independent containment and
      authorization checks.

      - [ ] 3.2.2.1 Subtask — Add `/factory`, `/projects`, project overview/work/attempt catalog, and per-attempt workspace routes.
      - [ ] 3.2.2.2 Subtask — Add read-only review, knowledge-lens placeholders, wiki navigation, operations, and separately authorized governance routes.
      - [ ] 3.2.2.3 Subtask — Use opaque bounded refs and prove project ref never authorizes an attempt/session/candidate/preview/lens underneath it.
      - [ ] 3.2.2.4 Subtask — Add native GET/form behavior, no-store/referrer policy where required, and unique stable DOM IDs for key roots/forms/rows.

  - [ ] 3.3 Section — Deliver truthful bounded factory and attempt read projections.

    This section makes the shell useful without claiming live delivery or
    command authority.

    - [ ] 3.3.1 Task {#hui-p03-attention-fleet} [repo: jido_code] [after: {#hui-p03-routes}] — Implement reviewed attention, health, and fleet projections.

      This task presents durable exceptions and meaningful progress rather
      than browser notifications or process liveness.

      - [ ] 3.3.1.1 Subtask — Add closed reviewed attention query/view model for approvals, questions, failed checks, stalled leases, recovery, budgets, stale critical projections, and security incidents.
      - [ ] 3.3.1.2 Subtask — Add health/readiness view models that explicitly show disabled, unconfigured, evaluation, contract-only, maintenance, recovery, and unavailable posture.
      - [ ] 3.3.1.3 Subtask — Add stable server-filtered/sorted/cursor-paginated fleet table with last meaningful effect, wait, lease/fence, budget, evidence, outcome, and owner.
      - [ ] 3.3.1.4 Subtask — Keep acknowledgement/snooze/saved durable views/batch commands unavailable and prevent row reordering during reading.

    - [ ] 3.3.2 Task {#hui-p03-project-attempt} [repo: jido_code] [after: {#hui-p03-attention-fleet}] — Implement project and attempt read-only workspaces.

      This task correlates current repository, task, attempt, interaction,
      candidate, evidence, wiki, and cost facts without controls.

      - [ ] 3.3.2.1 Subtask — Add project overview/work/attempt grouping, source/dependency, wiki enrollment/freshness/cost, budget, evidence, and incident summaries.
      - [ ] 3.3.2.2 Subtask — Add attempt trust header, lifecycle/outcome rails, bounded timeline, interactions, artifacts, checks, costs, authority, and receipt panels.
      - [ ] 3.3.2.3 Subtask — Preserve `InteractionSession` as a distinct related resource and test audience/preview containment.
      - [ ] 3.3.2.4 Subtask — Render all ten projection states; clear unavailable rows; label stale data; conceal unknown/unauthorized resources.

    - [ ] 3.3.3 Task {#hui-p03-components} [repo: jido_code] [after: {#hui-p03-project-attempt}] — Implement the P0 read-only application composites.

      This task establishes stable semantic components before live patching or
      commands depend on them.

      - [ ] 3.3.3.1 Subtask — Implement ProjectionStatusStrip, AttentionQueue, AgentFleetTable, filters/pagination, and project summary components.
      - [ ] 3.3.3.2 Subtask — Implement AgentAttemptWorkspace, StageRail, AttemptTimeline, ProvenancePanel, EvidenceMatrix, and CostBudgetMeter in read-only mode.
      - [ ] 3.3.3.3 Subtask — Add rendered-contract, escaping, ID, state, responsive, native fallback, keyboard, and screen-reader tests for every composition.

  - [ ] 3.4 Section — Phase 3 Integration Tests.

    This final section proves named humans can safely navigate and understand
    the factory through complete read-only HEEx pages.

    - [ ] 3.4.1 Task {#hui-p03-integration} [repo: jido_code] [after: {#hui-p03-components}] — Execute the HUI3 identity, route, projection, and accessibility matrix.

      This task closes read-only product evidence before any live transport or
      command adapter is enabled.

      - [ ] 3.4.1.1 Subtask — Exercise account/session/assurance/revocation, role/grant/delegation mapping, controller/API parity, IDOR, field redaction, and concealment.
      - [ ] 3.4.1.2 Subtask — Exercise every route, scope switch, back/forward/bookmark, several tabs, opaque-ref containment, search/filter/page bounds, and native form path.
      - [ ] 3.4.1.3 Subtask — Exercise all projection states, truthful unconfigured posture, large collections, hostile content, responsive, keyboard, screen reader, zoom, touch, RTL, forced colors, and reduced motion.
      - [ ] 3.4.1.4 Subtask — Run prior suites, architecture checks, security tests, `mix precommit`, and clean-checkout CI.

    - [ ] 3.4.2 Task {#hui-p03-phase-receipt} [repo: jido_code] [after: {#hui-p03-integration}] — Publish and pin the Phase 3 receipt.

      This task records Gate HUI3 evidence and authorizes Datastar delivery only
      from the merged read-only identity/shell baseline.

      - [ ] 3.4.2.1 Subtask — Keep HUI3 merge-pending on any identity/scope/concealment/route/projection/readiness/native/accessibility blocker or unintended command effect.
      - [ ] 3.4.2.2 Subtask — Record the full merge SHA/date, identity adapter, query/component/browser evidence, and limitations without weakening reopening conditions.
      - [ ] 3.4.2.3 Subtask — Pin the merged candidate commit and check the phase, Phase 3 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 4.
