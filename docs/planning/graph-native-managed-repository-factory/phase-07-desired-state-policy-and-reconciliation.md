---
id: plan.jido_code_graph_factory_phase_07
intent: control_plane_change
source:
  - docs/research/01-graph-native-managed-repository-factory.md
---

# Phase 7 - Desired State, Policy, And Reconciliation

This phase implements the managed-repository factory control loop: declarative
desired outcomes, graph-native goals/tasks/plans, applicable policies and
obligations, versioned reconciliation over exact observed-state revisions,
explainable work eligibility, capability matching, and fenced graph-visible
leases.

Back to plan: [README](./README.md)

- [ ] 7 Phase - Derive and schedule governed work from the difference between desired and observed repository state.

  This phase makes work a connected semantic graph rather than a persisted
  `WorkItem` aggregate or queue row and keeps policy, proposal, authorization,
  and execution admission as distinct decisions.

  - [x] 7.1 Section - Implement desired outcomes and graph-native work structure.

    This section introduces repository intent and executable decomposition
    without flattening goals, findings, constraints, dependencies, and plans
    into one object.

    - [x] 7.1.1 Task {#jcf-p07-desired-outcomes} [repo: jido_code] [after: {#jcf-p06-phase-receipt}] - Implement desired-outcome and constraint commands.

      This task records what should become true and under which scope,
      evidence, and policy without immediately creating executable work.

      - [x] 7.1.1.1 Subtask {#jcf-p07-7-1-1-1} - Implement `AssertDesiredOutcome` with actor, enrollment/cohort scope, proposition or capability target, priority concept, validity, policy refs, evidence requirement, and expected control revision.
      - [x] 7.1.1.2 Subtask {#jcf-p07-7-1-1-2} - Model constraints for allowed branches/paths, change/risk bounds, required checks, approvals, time/budget, tools, sandboxes, and prohibited effects.
      - [x] 7.1.1.3 Subtask {#jcf-p07-7-1-1-3} - Add proposal, active, suspended, satisfied, waived, superseded, and retired transition concepts without a mutable status literal.
      - [x] 7.1.1.4 Subtask {#jcf-p07-7-1-1-4} - Require explicit supersession or decision when desired outcomes conflict and preserve both authored intents.
      - [x] 7.1.1.5 Subtask {#jcf-p07-7-1-1-5} - Keep desired state distinct from observed/inferred claims even when they use the same subject/predicate/object proposition.

    - [x] 7.1.2 Task {#jcf-p07-goal-task-graph} [repo: jido_code] [after: {#jcf-p07-desired-outcomes}] - Implement goal, task, and dependency graph commands.

      This task creates bounded units of intent and execution whose
      relationships remain directly queryable across findings, repositories,
      artifacts, and policies.

      - [x] 7.1.2.1 Subtask {#jcf-p07-7-1-2-1} - Implement `ProposeGoal` with scope, addressed outcome/finding/claim, governing policies, constraints, expected evidence, origin activity, and semantic deduplication key.
      - [x] 7.1.2.2 Subtask {#jcf-p07-7-1-2-2} - Model task decomposition, dependency, blocking, ordering, alternative paths, required input artifacts, required capabilities, and verification tasks as edges.
      - [x] 7.1.2.3 Subtask {#jcf-p07-7-1-2-3} - Define goal/task transitions for proposed, approved, eligible, blocked, leased, executing, awaiting evidence/decision, satisfied, rejected, cancelled, and superseded.
      - [x] 7.1.2.4 Subtask {#jcf-p07-7-1-2-4} - Permit a goal to address multiple findings and a task/evidence artifact to serve multiple goals without duplicated records.
      - [x] 7.1.2.5 Subtask {#jcf-p07-7-1-2-5} - Treat any UI `WorkItem` as a bounded projection anchored at a goal/task neighborhood, never a separate persisted resource family.

    - [x] 7.1.3 Task {#jcf-p07-plan-adoption} [repo: jido_code] [after: {#jcf-p07-goal-task-graph}] - Implement plan proposal, validation, and adoption.

      This task separates a proposed decomposition from the governed act that
      makes tasks eligible for scheduling.

      - [x] 7.1.3.1 Subtask {#jcf-p07-7-1-3-1} - Define plan resources with goal, task/dependency graph, source claims/snapshot, planner actor/version, assumptions, expected effects, verification strategy, and bounds.
      - [x] 7.1.3.2 Subtask {#jcf-p07-7-1-3-2} - Validate acyclic or explicitly iterative dependency structure, scope compatibility, capability availability, constraint coverage, and mandatory verification/approval tasks.
      - [x] 7.1.3.3 Subtask {#jcf-p07-7-1-3-3} - Implement `AdoptPlan` as an authorized decision/transition with exact plan and source graph revisions.
      - [x] 7.1.3.4 Subtask {#jcf-p07-7-1-3-4} - Preserve rejected/superseded plan proposals and prevent stale plans from becoming current after source, policy, or goal changes.
      - [x] 7.1.3.5 Subtask {#jcf-p07-7-1-3-5} - Require explicit replanning when observed reality invalidates assumptions or dependency inputs.

    - [x] 7.1.4 Task {#jcf-p07-work-projections} [repo: jido_code] [after: {#jcf-p07-plan-adoption}] - Implement goal, plan, task, and dependency projections.

      This task provides human and runtime consumers with bounded work views
      while retaining graph identity and explanation paths.

      - [x] 7.1.4.1 Subtask {#jcf-p07-7-1-4-1} - Add goal neighborhood, task DAG, blocker, dependency, addressed finding/outcome, governing policy, required capability, and transition-history queries.
      - [x] 7.1.4.2 Subtask {#jcf-p07-7-1-4-2} - Project exact source/observation/policy/control revisions, current state chain, contradictions, stale assumptions, and missing evidence.
      - [x] 7.1.4.3 Subtask {#jcf-p07-7-1-4-3} - Add list/lens projections for proposed, active, eligible, blocked, executing, and awaiting-decision work without status fields.
      - [x] 7.1.4.4 Subtask {#jcf-p07-7-1-4-4} - Bound graph depth, task count, history, labels, and cross-repository expansion with explicit truncation.

  - [x] 7.2 Section - Implement policies, cohorts, obligations, and capabilities.

    This section expresses factory governance as queryable graph resources and
    versioned evaluation rules that can explain applicability and required
    action.

    - [x] 7.2.1 Task {#jcf-p07-policy-contract} [repo: jido_code] [after: {#jcf-p07-work-projections}] - Implement policy definition and lifecycle commands.

      This task gives policy authors a bounded semantic contract without
      embedding arbitrary executable code or opaque inference authority in RDF.

      - [x] 7.2.1.1 Subtask {#jcf-p07-7-2-1-1} - Define policy identity/version, owner, applicability query/rule ref, desired outcomes, constraints, obligation template, evidence/decision requirements, effective interval, priority, and conflict posture.
      - [x] 7.2.1.2 Subtask {#jcf-p07-7-2-1-2} - Validate policy queries/rules against allowlisted versioned evaluators and declared closed-world inputs.
      - [x] 7.2.1.3 Subtask {#jcf-p07-7-2-1-3} - Implement proposed, active, suspended, superseded, and retired policy transitions with no retroactive reinterpretation of prior decisions.
      - [x] 7.2.1.4 Subtask {#jcf-p07-7-2-1-4} - Define deterministic priority/conflict handling and require an explicit decision when applicable policies cannot be jointly satisfied.
      - [x] 7.2.1.5 Subtask {#jcf-p07-7-2-1-5} - Keep authorization policy evaluation separate from desired-posture and acceptance policy evaluation.

    - [x] 7.2.2 Task {#jcf-p07-cohort-applicability} [repo: jido_code] [after: {#jcf-p07-policy-contract}] - Implement graph-defined repository cohorts and policy applicability.

      This task exploits cross-repository graph relationships so one policy can
      govern a selected fleet without copying object records into every repo.

      - [x] 7.2.2.1 Subtask {#jcf-p07-7-2-2-1} - Define static membership and reviewed query-derived cohorts over enrollment, organization, provider, language, dependency, risk, ownership, or capability relationships.
      - [x] 7.2.2.2 Subtask {#jcf-p07-7-2-2-2} - Materialize cohort membership only in a derived graph bound to source revisions and policy evaluator version.
      - [x] 7.2.2.3 Subtask {#jcf-p07-7-2-2-3} - Return applicability explanations citing policy, cohort/membership path, input graph revisions, validity, and any incomplete knowledge.
      - [x] 7.2.2.4 Subtask {#jcf-p07-7-2-2-4} - Reevaluate and invalidate derived membership after relevant catalog, observation, source, or policy commits.
      - [x] 7.2.2.5 Subtask {#jcf-p07-7-2-2-5} - Prohibit unauthorized cohort enumeration and cross-tenant/repository side channels.

    - [x] 7.2.3 Task {#jcf-p07-obligation-derivation} [repo: jido_code] [after: {#jcf-p07-cohort-applicability}] - Implement policy obligation derivation.

      This task records why a policy requires action for a repository while
      avoiding duplicate obligations on every reconciliation pass.

      - [x] 7.2.3.1 Subtask {#jcf-p07-7-2-3-1} - Derive obligation identity from policy version, applicable scope, desired outcome/dimension, and relevant source revision.
      - [x] 7.2.3.2 Subtask {#jcf-p07-7-2-3-2} - Record policy/applicability evidence, triggering finding/gap, required outcome, constraints, due/valid interval, and acceptance requirements.
      - [x] 7.2.3.3 Subtask {#jcf-p07-7-2-3-3} - Reuse, supersede, waive, or satisfy obligations through governed transitions rather than recreating rows.
      - [x] 7.2.3.4 Subtask {#jcf-p07-7-2-3-4} - Preserve the distinction between a derived obligation, an approved goal, and executable tasks.

    - [x] 7.2.4 Task {#jcf-p07-capability-registry} [repo: jido_code] [after: {#jcf-p07-obligation-derivation}] - Implement actor, agent, tool, and sandbox capability projections.

      This task supplies scheduling with versioned capability facts and
      constraints without binding domain semantics to process names or pods.

      - [x] 7.2.4.1 Subtask {#jcf-p07-7-2-4-1} - Represent declared and observed capabilities, provider/agent/tool version, supported scopes/effects, availability, limits, and evidence source.
      - [x] 7.2.4.2 Subtask {#jcf-p07-7-2-4-2} - Distinguish capability possession from authorization to apply it in one enrollment/task scope.
      - [x] 7.2.4.3 Subtask {#jcf-p07-7-2-4-3} - Add capability hierarchy/classification through rebuildable inference with explicit source and rule versions.
      - [x] 7.2.4.4 Subtask {#jcf-p07-7-2-4-4} - Mark stale/unavailable capability observations and prohibit scheduling from an incomplete strict capability view.

  - [x] 7.3 Section - Implement desired/observed-state reconciliation.

    This section compares exact graph revisions, derives explainable gaps and
    proposals, and converges idempotently without letting an inference engine
    grant execution authority.

    - [x] 7.3.1 Task {#jcf-p07-reconciliation-input} [repo: jido_code] [after: {#jcf-p07-capability-registry}] - Build bounded reconciliation input packages.

      This task selects one coherent desired/observed/policy/knowledge context
      for an enrollment or cohort.

      - [x] 7.3.1.1 Subtask {#jcf-p07-7-3-1-1} - Select active enrollment, exact/latest complete observations, exact source snapshot, applicable policy versions, desired outcomes, accepted knowledge, active goals/obligations, and current control revision.
      - [x] 7.3.1.2 Subtask {#jcf-p07-7-3-1-2} - Require explicit completeness for every negative/absence conclusion and retain unknown/contradictory input state.
      - [x] 7.3.1.3 Subtask {#jcf-p07-7-3-1-3} - Bind input graph/revision set, query/rule versions, actor, budget, deadline, and reconciliation identity.
      - [x] 7.3.1.4 Subtask {#jcf-p07-7-3-1-4} - Reject stale, mixed-snapshot, unauthorized, over-budget, or ontology-incompatible packages before deriving control changes.

    - [x] 7.3.2 Task {#jcf-p07-gap-reconciliation} [repo: jido_code] [after: {#jcf-p07-reconciliation-input}] - Derive gaps, contradictions, obligations, and goal proposals.

      This task compares graph-native propositions and policy requirements and
      records proposals with complete explanations.

      - [x] 7.3.2.1 Subtask {#jcf-p07-7-3-2-1} - Detect unsatisfied desired outcomes, applicable unsatisfied policy obligations, stale evidence, invalid assumptions, contradictions, and goals made obsolete by current observations.
      - [x] 7.3.2.2 Subtask {#jcf-p07-7-3-2-2} - Produce proposed finding/obligation/goal/supersession change sets with source graph refs, rule version, confidence, explanation, and no automatic execution lease.
      - [x] 7.3.2.3 Subtask {#jcf-p07-7-3-2-3} - Reuse semantic gap/goal identities across identical reconciliation input and supersede stale proposals after meaningful source/policy change.
      - [x] 7.3.2.4 Subtask {#jcf-p07-7-3-2-4} - Require human or policy-authorized adoption where risk, ambiguity, contradiction, or incomplete knowledge exceeds accepted bounds.
      - [x] 7.3.2.5 Subtask {#jcf-p07-7-3-2-5} - Never treat derived cohort, inferred capability, or high-confidence claim as accepted control truth without the declared command/decision path.

    - [x] 7.3.3 Task {#jcf-p07-reconciler-process} [repo: jido_code] [after: {#jcf-p07-gap-reconciliation}] - Implement the restart-safe reconciler coordinator.

      This task uses graph state to discover work, coalesce triggers, and run
      bounded reconciliation without persisting a second queue.

      - [x] 7.3.3.1 Subtask {#jcf-p07-7-3-3-1} - Discover active/stale enrollment scopes by query at startup and after relevant change notifications.
      - [x] 7.3.3.2 Subtask {#jcf-p07-7-3-3-2} - Coalesce duplicate triggers while recording durable reconciliation activity and input revisions through semantic commands.
      - [x] 7.3.3.3 Subtask {#jcf-p07-7-3-3-3} - Enforce per-factory/repository concurrency, budgets, timeouts, backoff, and cancellation without durable process snapshots.
      - [x] 7.3.3.4 Subtask {#jcf-p07-7-3-3-4} - On restart, query incomplete reconciliation activities and recover, supersede, or retry according to graph-visible state.

    - [x] 7.3.4 Task {#jcf-p07-reconciliation-explanation} [repo: jido_code] [after: {#jcf-p07-reconciler-process}] - Implement gap and work-selection explanations.

      This task makes every proposed, reused, superseded, blocked, or omitted
      goal traceable without exposing hidden model reasoning.

      - [x] 7.3.4.1 Subtask {#jcf-p07-7-3-4-1} - Project desired proposition, observed/unknown state, policy/applicability path, source revisions, rule/query versions, constraints, and resulting proposal.
      - [x] 7.3.4.2 Subtask {#jcf-p07-7-3-4-2} - Distinguish no gap, unknown due to incomplete input, contradiction, policy conflict, proposal pending, existing work reused, and work superseded.
      - [x] 7.3.4.3 Subtask {#jcf-p07-7-3-4-3} - Bound explanation size and cite graph resources instead of persisting or exposing chain-of-thought.
      - [x] 7.3.4.4 Subtask {#jcf-p07-7-3-4-4} - Add exact-context reconstruction for authorized audit and later evidence evaluation.

  - [x] 7.4 Section - Implement eligibility, scheduling, and fenced leases.

    This section turns approved task graphs into explainable execution
    candidates while keeping scheduler memory disposable and lease authority
    durable in the graph.

    - [x] 7.4.1 Task {#jcf-p07-eligibility-query} [repo: jido_code] [after: {#jcf-p07-reconciliation-explanation}] - Implement the closed-world eligible-work query.

      This task selects tasks only when every declared prerequisite,
      authorization, capability, freshness, and capacity condition is known to
      hold.

      - [x] 7.4.1.1 Subtask {#jcf-p07-7-4-1-1} - Require active enrollment/goal/plan, approved task, satisfied dependencies, available required artifacts, fresh source snapshot, applicable authorization, capability match, and no valid conflicting lease.
      - [x] 7.4.1.2 Subtask {#jcf-p07-7-4-1-2} - Require complete graph boundaries for dependency, lease, cancellation, capability, and policy checks.
      - [x] 7.4.1.3 Subtask {#jcf-p07-7-4-1-3} - Return candidate priority/fairness inputs plus an explanation of every satisfied and blocking condition.
      - [x] 7.4.1.4 Subtask {#jcf-p07-7-4-1-4} - Treat unknown, stale, contradictory, unauthorized, over-capacity, and incomplete states as blocked with machine-readable reasons.

    - [x] 7.4.2 Task {#jcf-p07-lease-command} [repo: jido_code] [after: {#jcf-p07-eligibility-query}] - Implement lease acquisition, renewal, release, and expiry transitions.

      This task creates exclusive, fenced execution authority that survives
      scheduler/runtime process loss.

      - [x] 7.4.2.1 Subtask {#jcf-p07-7-4-2-1} - Implement `AcquireExecutionLease` with task, actor/agent, capability, expected task/control revisions, acquisition/expiry, fencing token, and eligibility receipt.
      - [x] 7.4.2.2 Subtask {#jcf-p07-7-4-2-2} - Atomically transition task and lease state, reject competing acquisitions, and advance monotonic fencing per task.
      - [x] 7.4.2.3 Subtask {#jcf-p07-7-4-2-3} - Implement bounded renewal with current fence, liveness evidence, maximum duration, policy, and no silent owner/capability widening.
      - [x] 7.4.2.4 Subtask {#jcf-p07-7-4-2-4} - Implement release, cancellation, expiry observation, supersession, and recovery decisions without erasing prior leases.
      - [x] 7.4.2.5 Subtask {#jcf-p07-7-4-2-5} - Require every execution-side mutation to present the current lease IRI and fencing token.

    - [x] 7.4.3 Task {#jcf-p07-scheduler} [repo: jido_code] [after: {#jcf-p07-lease-command}] - Implement the graph-rebuildable scheduler.

      This task orders eligible candidates and grants leases while retaining no
      durable queue or hidden work ownership.

      - [x] 7.4.3.1 Subtask {#jcf-p07-7-4-3-1} - Query eligible candidates by bounded factory/repository pages and apply deterministic priority, fairness, risk, and capacity policy.
      - [x] 7.4.3.2 Subtask {#jcf-p07-7-4-3-2} - Match candidate requirements to currently authorized capability providers and issue guarded lease commands.
      - [x] 7.4.3.3 Subtask {#jcf-p07-7-4-3-3} - Recover on restart from valid/expired leases, task transition chains, and available capability projections.
      - [x] 7.4.3.4 Subtask {#jcf-p07-7-4-3-4} - Enforce global, cohort, repository, capability, and risk admission limits and expose bounded reasons for deferred work.
      - [x] 7.4.3.5 Subtask {#jcf-p07-7-4-3-5} - Treat PubSub as a wake-up hint and periodically reconcile from graph revisions to prevent missed work.

  - [x] 7.5 Section - Phase 7 Integration Tests.

    This final section proves desired-state reconciliation and work scheduling
    remain deterministic, explainable, idempotent, closed-world safe, and
    fenced under policy changes, conflicting observations, concurrency, and
    restart.

    - [x] 7.5.1 Task {#jcf-p07-reconciliation-integration} [repo: jido_code] [after: {#jcf-p07-scheduler}] - Execute observation-to-goal reconciliation scenarios.

      This task validates the full control-plane derivation using exact
      repository observations, desired outcomes, policies, and graph-native
      work neighborhoods.

      - [x] 7.5.1.1 Subtask {#jcf-p07-7-5-1-1} - Assert a desired protected-main outcome, observe a contradictory repository claim, derive one obligation/goal, adopt a task plan, and explain every edge and revision.
      - [x] 7.5.1.2 Subtask {#jcf-p07-7-5-1-2} - Replay identical reconciliation, reorder observation events, update policy/source revisions, and prove goal reuse or explicit supersession without duplicates.
      - [x] 7.5.1.3 Subtask {#jcf-p07-7-5-1-3} - Exercise incomplete observations, contradictory claims, policy conflicts, stale source graphs, missing capabilities, suspended enrollment, and human-approval requirements.
      - [x] 7.5.1.4 Subtask {#jcf-p07-7-5-1-4} - Apply one policy to a graph-derived multi-repository cohort and verify applicability/obligation explanations preserve authorization boundaries.

    - [x] 7.5.2 Task {#jcf-p07-scheduling-integration} [repo: jido_code] [after: {#jcf-p07-reconciliation-integration}] - Exercise eligibility, lease races, expiry, and scheduler rebuild.

      This task proves no task executes without one current fenced lease and no
      process-local queue is needed for recovery.

      - [x] 7.5.2.1 Subtask {#jcf-p07-7-5-2-1} - Race multiple compatible agents for one task and prove one lease/fence wins with deterministic losing receipts.
      - [x] 7.5.2.2 Subtask {#jcf-p07-7-5-2-2} - Renew, release, cancel, expire, supersede, and reacquire leases while stale fences are rejected.
      - [x] 7.5.2.3 Subtask {#jcf-p07-7-5-2-3} - Kill/restart reconciler and scheduler with eligible, blocked, and leased work and compare rebuilt decisions to pre-crash graph state.
      - [x] 7.5.2.4 Subtask {#jcf-p07-7-5-2-4} - Drop notifications and prove periodic revision-based reconciliation discovers work without duplicate semantic effects.
      - [x] 7.5.2.5 Subtask {#jcf-p07-7-5-2-5} - Verify missing data never satisfies eligibility and every blocked/selected result has an exact explanation path.
      - [x] 7.5.2.6 Subtask {#jcf-p07-7-5-2-6} - Rerun Phases 1-6 suites and `mix precommit`.

    - [x] 7.5.3 Task {#jcf-p07-phase-receipt} [repo: jido_code] [after: {#jcf-p07-scheduling-integration}] - Publish the Phase 7 factory-control-loop receipt.

      This task binds G6 to exact desired-state, policy, cohort, obligation,
      reconciliation, goal/task/plan, eligibility, capability, lease, and
      restart evidence.

      - [x] 7.5.3.1 Subtask {#jcf-p07-7-5-3-1} - Record policy/rule/query/ontology versions, scenario and cohort fixture digests, capability providers, scheduler settings, and candidate commit.
      - [x] 7.5.3.2 Subtask {#jcf-p07-7-5-3-2} - Attach reconciliation replay, contradiction/incomplete cases, cohort applicability, lease races, expiry/fencing, notification loss, restart, and explanation results.
      - [x] 7.5.3.3 Subtask {#jcf-p07-7-5-3-3} - Keep G6 blocked if work can exist only in a queue/struct, absence can satisfy eligibility without completeness, or an inference can grant a lease directly.
      - [ ] 7.5.3.4 Subtask {#jcf-p07-7-5-3-4} - Pin the merged candidate commit before authorizing Phase 8.
