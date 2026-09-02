---
id: plan.jido_code_hypermedia_ui_milestone_a_phase_01
parent_plan: plan.jido_code_hypermedia_ui_milestone_a
status: completed
intent: feature
---

# Milestone A Phase 1 - Current-State Authority And Gap Baseline

This phase pins the exact current product architecture and assigns ownership to
every contract affected by the migration. It produces evidence, not target
implementation, and prevents later phases from erasing still-active consumers.

Back to plan: [README](./README.md)

- [x] 1 Phase - Establish the accountable current-state and authority baseline.

  This phase closes HUI-A1 by replacing assumptions with reproducible route,
  runtime, dependency, identity, graph, command, test, documentation, and
  operational inventories.

  - [x] 1.1 Section - Pin the candidate and governing document set.

    This section identifies the exact Git and accepted-document baseline from
    which every inventory and supersession claim is evaluated.

    - [x] 1.1.1 Task {#huia-p01-baseline} [repo: jido_code] - Record candidate provenance and accepted authority.

      This task creates one immutable baseline manifest for the program.

      - [x] 1.1.1.1 Subtask - Record the full starting commit, merge ancestry, dependency locks, asset manifests, Elixir/OTP/Node toolchain, and production configuration profile.
      - [x] 1.1.1.2 Subtask - Inventory accepted ADRs, architecture specifications, phase receipts, plans, research, operations guides, contributor rules, and explicit exceptions that affect product delivery.
      - [x] 1.1.1.3 Subtask - Record status, owner, supersession rules, gate reopening conditions, and current implementation evidence for every governing document.
      - [x] 1.1.1.4 Subtask - Hash the inventory and define the update procedure for facts that change before HUI1 closes.

  - [x] 1.2 Section - Inventory product runtime and consumer surfaces.

    This section traces every current route and user-visible behavior through
    its runtime, assets, dependencies, state owner, tests, and operations.

    - [x] 1.2.1 Task {#huia-p01-runtime-inventory} [repo: jido_code] [after: {#huia-p01-baseline}] - Build the route, module, process, and asset inventory.

      This task proves which LiveView, LiveVue, SaladUI, Vite, dashboard, and
      Phoenix.Component consumers actually exist.

      - [x] 1.2.1.1 Subtask - Enumerate browser/admin/health/dashboard routes, pipelines, `live_session` blocks, controllers, templates, LiveViews, components, sockets, supervised processes, and endpoint hooks.
      - [x] 1.2.1.2 Subtask - Trace JavaScript/CSS entry points, LiveView client/hooks, Vue/LiveVue bridges, SaladUI imports, ShadcnUI candidates, fonts/icons, CSP allowances, and production asset outputs.
      - [x] 1.2.1.3 Subtask - Trace Hex/npm dependencies and transitive consumers, including `phoenix_live_view`, LiveDashboard, Vite, test helpers, and deployment tooling.
      - [x] 1.2.1.4 Subtask - Map each current product capability, deep link, browser test, monitoring signal, runbook, and rollback procedure to its implementation owner.

    - [x] 1.2.2 Task {#huia-p01-authority-inventory} [repo: jido_code] [after: {#huia-p01-runtime-inventory}] - Inventory identity, graph, projection, command, and readiness ownership.

      This task identifies every authority boundary the new web runtime must
      preserve and every capability that is not production-composed today.

      - [x] 1.2.2.1 Subtask - Trace current operator/session identity construction through browser/API paths, scope/delegation defaults, CSRF/session generation, authorization, audit, and revocation.
      - [x] 1.2.2.2 Subtask - Inventory all graph families, reviewed queries, projection states, subscriptions, semantic commands, approvals, receipts, exports, incidents, and product exposure gaps.
      - [x] 1.2.2.3 Subtask - Record scheduler, managed service, coding loader, delegated-agent rollout, publication, wiki gateway, identity provider, and incident-resource readiness as composed, disabled, evaluation-only, or contract-only.
      - [x] 1.2.2.4 Subtask - Record exact owners and blockers for every P0/P1/P2 research gap, including parallel-session and concurrent-human failure modes.

  - [x] 1.3 Section - Reconcile vocabulary, identity, and supersession scope.

    This section prevents ambiguous words and partial replacements from
    propagating into later specifications and user interfaces.

    - [x] 1.3.1 Task {#huia-p01-vocabulary} [repo: jido_code] [after: {#huia-p01-authority-inventory}] - Publish the canonical product/runtime vocabulary.

      This task gives each durable and ephemeral identity one unambiguous name.

      - [x] 1.3.1.1 Subtask - Define factory, tenant, conceptual repository, project alias, task, attempt, `InteractionSession`, candidate, edition, preview, browser session, tab, provider thread, runtime, process, and agent identities.
      - [x] 1.3.1.2 Subtask - Define page, fragment, projection, signal, stream, hint, patch, command, effect, receipt, evidence, decision, freshness, readiness, and satisfaction terms.
      - [x] 1.3.1.3 Subtask - Identify every accepted clause that assigns product authority to LiveView/LiveVue/SaladUI or the shared operator and classify it as preserve, supersede, amend, or defer.
      - [x] 1.3.1.4 Subtask - Publish a no-silent-supersession matrix with old owner, proposed owner, migration evidence, rollback dependency, and removal phase.

  - [x] 1.4 Section - Phase 1 Integration Tests.

    This final section proves the baseline is complete, reproducible, and
    sufficient to prevent an accidental legacy consumer or authority gap.

    - [x] 1.4.1 Task {#huia-p01-integration} [repo: jido_code] [after: {#huia-p01-vocabulary}] - Execute the HUI-A1 inventory and traceability matrix.

      This task validates inventory claims against source, configuration,
      compiled dependencies, router/supervision output, tests, and documents.

      - [x] 1.4.1.1 Subtask - Reproduce route, dependency, supervision, asset, identity, graph/query/command, test, operations, and documentation inventories from a clean checkout.
      - [x] 1.4.1.2 Subtask - Verify every current route/capability and each research gap has an owner, evidence source, readiness state, replacement disposition, and rollback consequence.
      - [x] 1.4.1.3 Subtask - Verify vocabulary collisions and orphaned supersession clauses fail architecture validation.
      - [x] 1.4.1.4 Subtask - Run architecture checks, documentation link/anchor checks, `mix precommit`, and clean-checkout CI.

    - [x] 1.4.2 Task {#huia-p01-phase-receipt} [repo: jido_code] [after: {#huia-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records HUI-A1 evidence in
      `docs/architecture/hypermedia-ui-milestone-a-phase-01-receipt.md`.

      - [x] 1.4.2.1 Subtask - Keep HUI-A1 merge-pending on an unowned route, dependency, identity path, graph/command surface, capability, document, operation, or supersession clause.
      - [x] 1.4.2.2 Subtask - Record exact inventory digests, commands, fixtures, discrepancies, accepted limitations, and every reopening condition.
      - [x] 1.4.2.3 Subtask - Record the full merge SHA/date and pin the merged candidate; check the phase, Phase 1 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 2.
