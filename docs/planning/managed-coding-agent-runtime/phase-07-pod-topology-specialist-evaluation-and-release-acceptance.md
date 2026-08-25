---
id: plan.jido_code_managed_coding_agent_runtime_phase_07
parent_plan: plan.jido_code_managed_coding_agent_runtime
status: planned
intent: feature
---

# Managed Coding Phase 7 - Pod Topology, Specialist Evaluation, And Release Acceptance

This phase evaluates whether a graph-projected `Jido.Pod` topology of bounded
specialists materially improves the qualified single-agent runtime. It may end
with an accepted specialist profile or an evidence-backed decision to retain
the simpler runtime; either result preserves one durable authority model.

Back to plan: [README](./README.md)

- [ ] 7 Phase - Evaluate optional specialist topology and close the managed coding runtime plan.

  This phase proves MCG7 by making topology an explicitly evaluated runtime
  choice, not an assumption or a second source of durable truth.

  - [x] 7.1 Section - Define topology and compatibility contracts.

    This section specifies exactly how Pod membership, agent state, signals, and
    graph evidence coexist before any specialist workflow is implemented.

    - [x] 7.1.1 Task {#mcar-p07-topology-contract} [repo: jido_code] [after: {#mcar-p06-phase-receipt}] - Specify and test the graph-projected Jido.Pod topology contract.

      This task defines the boundary between disposable process coordination and
      durable task, attempt, delegation, artifact, and decision identity.

      - [x] 7.1.1.1 Subtask - Pin the evaluated Jido/Jido.Pod versions and probe child startup, identifiers, signal routing, restart, membership, registry, lifecycle, timeout, and shutdown semantics.
      - [x] 7.1.1.2 Subtask - Define graph entities and transitions for topology instance, specialist role, delegation, evidence packet, handoff, conflict, completion, cancellation, and reconstruction watermark.
      - [x] 7.1.1.3 Subtask - Declare the graph authoritative for topology intent and history while the Pod process tree is only a fenced projection that may be rebuilt.
      - [x] 7.1.1.4 Subtask - Define closed schemas and size/budget limits for specialist requests, replies, evidence, artifacts, errors, and terminal proposals with full attempt/fence correlation.
      - [x] 7.1.1.5 Subtask - Record compatibility fixtures and fail closed on unsupported or changed Jido/Pod behavior instead of introducing a hidden alternate runtime path.

  - [x] 7.2 Section - Implement topology reconciliation and bounded delegation.

    This section projects declared specialists into supervised processes and
    mediates every delegation through host authority and shared budgets.

    - [x] 7.2.1 Task {#mcar-p07-reconciliation} [repo: jido_code] [after: {#mcar-p07-topology-contract}] - Implement the managed Pod coordinator and reconciler.

      This task makes specialist processes recoverable execution components and
      prevents peer messages from becoming an ungoverned tool or memory plane.

      - [x] 7.2.1.1 Subtask - Reconcile desired graph topology to a named supervised Pod with deterministic child identities, monitors, deadlines, restart limits, and no dynamic atom creation.
      - [x] 7.2.1.2 Subtask - Admit each delegation through current policy, capability, context, budget, role, attempt, fence, and concurrency checks before starting or signalling a specialist.
      - [x] 7.2.1.3 Subtask - Route all specialist model/tool/context/memory effects through the same gateways, registries, workspaces, credentials, and graph accounting accepted in MCG1-MCG6.
      - [x] 7.2.1.4 Subtask - Deduct shared and per-role budgets, bound fan-out/depth/message size, reject recursive self-delegation, and prevent specialists from expanding roles or topology.
      - [x] 7.2.1.5 Subtask - Reconstruct, cancel, supersede, and quarantine Pod projections using graph facts and fences while containing duplicate, late, stale, forged, and cross-specialist signals.

  - [ ] 7.3 Section - Evaluate a minimal specialist topology.

    This section tests only narrowly motivated role separation and requires it
    to outperform the qualified single-agent baseline after added complexity.

    - [ ] 7.3.1 Task {#mcar-p07-specialists} [repo: jido_code] [after: {#mcar-p07-reconciliation}] - Implement and evaluate investigator/coder/reviewer specialist roles.

      This task determines whether independent evidence gathering or review
      improves outcomes without granting any specialist acceptance authority.

      - [ ] 7.3.1.1 Subtask - Define bounded investigator, coder, and reviewer inputs/outputs, tools, context, budgets, termination rules, and explicit unavailable authorities; instantiate only roles required by the selected experiment.
      - [ ] 7.3.1.2 Subtask - Require source-complete content-addressed evidence packets for handoffs and recompile recipient context rather than sharing opaque process memory or mutable transcripts.
      - [ ] 7.3.1.3 Subtask - Keep one candidate owner and route disagreement, missing evidence, proposed revisions, and reviewer findings through deterministic host-controlled arbitration.
      - [ ] 7.3.1.4 Subtask - Compare topology variants to the pinned Phase 6 baseline on the same blinded corpus for correctness, unsafe behavior, regressions, abstention, latency, tokens, cost, recovery, and operator burden.
      - [ ] 7.3.1.5 Subtask - Predeclare acceptance thresholds and select accept, restrict, or reject; retain the single-agent production profile when gains are insignificant, unsafe, unstable, or operationally disproportionate.

  - [ ] 7.4 Section - Decide the role of AgentOS persistence.

    This section resolves whether AgentOS contributes useful runtime services
    without permitting its Ecto state to compete with the knowledge graph.

    - [ ] 7.4.1 Task {#mcar-p07-agentos} [repo: jido_code] [after: {#mcar-p07-specialists}] - Evaluate and record the AgentOS adoption decision.

      This task either adopts a narrowly compatible integration or documents why
      the managed runtime will operate without AgentOS persistence.

      - [ ] 7.4.1.1 Subtask - Inventory candidate AgentOS lifecycle, persistence, registry, scheduling, telemetry, and operational capabilities against already accepted JidoCode services.
      - [ ] 7.4.1.2 Subtask - Reject any design in which AgentOS/Ecto becomes authoritative for task, attempt, topology, delegation, budget, candidate, verification, disposition, or recovery state.
      - [ ] 7.4.1.3 Subtask - If beneficial, implement only ephemeral services or an explicit graph-backed adapter with one-way authority, complete provenance, reconciliation, retention, and failure semantics.
      - [ ] 7.4.1.4 Subtask - Test restart, split-state, lag, duplicate, conflict, migration, backup/restore, and disable scenarios and prove graph-only reconstruction still yields the accepted outcome.
      - [ ] 7.4.1.5 Subtask - Publish an architecture decision with measured benefit, ownership, operational cost, compatibility pins, reopening conditions, and an explicit adopt/defer/reject result.

  - [ ] 7.5 Section - Finalize the managed runtime release contract.

    This section consolidates the accepted single-agent baseline and any
    approved optional topology into one supportable product boundary.

    - [ ] 7.5.1 Task {#mcar-p07-release} [repo: jido_code] [after: {#mcar-p07-agentos}] - Publish the final runtime architecture, profiles, and operating contract.

      This task makes the plan's end state explicit, including rejected options
      and the evidence required to revisit them later.

      - [ ] 7.5.1.1 Subtask - Document the final component map, ownership boundaries, durable graph schema, runtime/profile selection, gateway/tool plane, verification/publication split, and supported user workflow.
      - [ ] 7.5.1.2 Subtask - Mark each proposed specialist topology and AgentOS capability accepted, restricted, deferred, or rejected with its evidence, limitations, and reopening threshold.
      - [ ] 7.5.1.3 Subtask - Consolidate compatibility pins, profile manifests, schemas, threat model, runbooks, dashboards, evaluation procedures, rollout controls, data handling, and incident ownership.
      - [ ] 7.5.1.4 Subtask - Audit all public APIs, configuration, feature flags, migrations, dependencies, telemetry, UI language, and documentation for legacy, experimental, or contradictory authority paths.
      - [ ] 7.5.1.5 Subtask - Define post-plan SLOs, review cadence, regression gates, upgrade procedure, capacity process, security reevaluation, and future automation prerequisites while preserving human merge authority.

  - [ ] 7.6 Section - Phase 7 Integration Tests.

    This final section validates topology reconstruction, specialist evaluation,
    any AgentOS integration, baseline fallback, and the complete managed coding
    release contract.

    - [ ] 7.6.1 Task {#mcar-p07-integration} [repo: jido_code] [after: {#mcar-p07-release}] - Execute the topology and plan-wide acceptance matrix.

      This task closes MCG7 only when optional complexity is evidence justified
      and the simpler accepted baseline remains safe and operable.

      - [ ] 7.6.1.1 Subtask - Run accepted topology variants and the single-agent fallback through representative end-to-end, recovery, cancellation, ambiguity, security, capacity, verification, publication, and disable scenarios.
      - [ ] 7.6.1.2 Subtask - Inject Pod/coordinator/specialist loss, topology drift, duplicate/late/forged signals, handoff corruption, budget contention, conflicting recommendations, AgentOS unavailability, and split-state attempts.
      - [ ] 7.6.1.3 Subtask - Reproduce comparative evaluation, prove rejected/deferred features are unreachable in production, and audit graph reconstruction and human merge authority across every enabled profile.
      - [ ] 7.6.1.4 Subtask - Rerun MCG1-MCG6, all plan-wide runtime/security/recovery/evaluation suites, architecture checks, Dialyzer, clean-checkout CI, and `mix precommit`.

    - [ ] 7.6.2 Task {#mcar-p07-phase-receipt} [repo: jido_code] [after: {#mcar-p07-integration}] - Publish and pin the Phase 7 receipt and close the plan.

      This task records MCG7 evidence in
      `docs/architecture/managed-coding-phase-07-receipt.md` and closes the plan
      only from the pinned merged baseline.

      - [ ] 7.6.2.1 Subtask - Record Pod, topology, specialist, delegation, arbitration, AgentOS decision, final profile, architecture, evaluation, operations, and documentation revisions and digests.
      - [ ] 7.6.2.2 Subtask - Attach compatibility, reconstruction, fault, comparative evaluation, baseline fallback, authority audit, clean-checkout CI, and unresolved limitation evidence.
      - [ ] 7.6.2.3 Subtask - Keep MCG7 open if process state competes with the graph, specialist benefit is unproven, baseline fallback fails, enabled persistence splits authority, or any agent gains acceptance/merge authority.
      - [ ] 7.6.2.4 Subtask - Pin the merged candidate commit, tick the Phase 7 and plan-level completion checkboxes, and preserve every MCG1-MCG7 reopening condition.
