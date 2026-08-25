---
id: plan.jido_code_managed_coding_agent_runtime_phase_04
parent_plan: plan.jido_code_managed_coding_agent_runtime
status: in_progress
intent: feature
---

# Managed Coding Phase 4 - Managed Candidate Workflow And Verification Handoff

This phase embeds the bounded coding loop in the Factory workflow, turns its
terminal proposal into an immutable candidate, and hands that candidate to an
independent verifier. The coding runtime may prepare evidence, but it cannot
accept, publish, merge, or redefine the work it performed.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Deliver one managed task from admission through independently verified candidate disposition.

  This phase proves MCG4 by connecting the accepted runtime to orchestration,
  projections, verification, and publication boundaries without combining
  incompatible authorities.

  - [x] 4.1 Section - Admit and coordinate managed coding attempts.

    This section creates one Factory-owned entry point that resolves authority,
    commits identity, and starts the runtime from an attributable baseline.

    - [x] 4.1.1 Task {#mcar-p04-admission} [repo: jido_code] [after: {#mcar-p03-phase-receipt}] - Implement the managed coding service and admission transaction.

      This task establishes a single host-controlled path from an authorized
      task request to a fenced, supervised coding attempt.

      - [x] 4.1.1.1 Subtask - Define the public Factory command and response contracts for starting, inspecting, steering, cancelling, and awaiting a managed coding attempt.
      - [x] 4.1.1.2 Subtask - Resolve tenant, repository, task, actor, policy, runtime profile, snapshot, budget, credential, and capability revisions before admitting work.
      - [x] 4.1.1.3 Subtask - Atomically commit attempt identity, lease/fence, resolved inputs, initial lifecycle state, and admission evidence before starting a Jido process or external effect.
      - [x] 4.1.1.4 Subtask - Reject duplicate, conflicting, stale, unauthorized, unsupported, or over-capacity admissions with closed reasons and no partial workspace or process.
      - [x] 4.1.1.5 Subtask - Start and monitor the runtime through the accepted supervisor path and reconcile start failure without inventing graph state from process state.

  - [x] 4.2 Section - Coordinate the end-to-end attempt lifecycle.

    This section makes graph transitions the durable spine around disposable
    process execution, workspaces, model turns, tools, and candidate capture.

    - [x] 4.2.1 Task {#mcar-p04-lifecycle} [repo: jido_code] [after: {#mcar-p04-admission}] - Implement attempt coordination and durable lifecycle accounting.

      This task connects each runtime milestone to explicit graph facts and
      keeps projections reproducible after process loss.

      - [x] 4.2.1.1 Subtask - Define the admitted, preparing, running, awaiting actor, assembling candidate, candidate ready, verifying, dispositioned, cancelled, and failed lifecycle transitions with legal predecessor sets.
      - [x] 4.2.1.2 Subtask - Record workspace, invocation, interaction, tool effect, check, artifact, budget, terminal proposal, and candidate relationships using current attempt/fence identity.
      - [x] 4.2.1.3 Subtask - Project status, current wait reason, progress observations, budget use, and evidence links from graph facts without treating UI/cache state as authority.
      - [x] 4.2.1.4 Subtask - Make repeated commands and lifecycle callbacks idempotent and reject stale coordinators, agents, workspaces, or directive results.
      - [x] 4.2.1.5 Subtask - Preserve causal ordering and attributable timestamps while allowing explicitly marked observations to arrive after their originating effect.

  - [ ] 4.3 Section - Close immutable candidate artifacts.

    This section converts mutable workspace output into a content-addressed,
    reviewable handoff whose exact provenance can be independently reproduced.

    - [ ] 4.3.1 Task {#mcar-p04-candidate} [repo: jido_code] [after: {#mcar-p04-lifecycle}] - Implement candidate assembly and closure.

      This task freezes all material needed to understand and verify the
      proposed repository change without trusting the live agent process.

      - [ ] 4.3.1.1 Subtask - Capture base revision, repository identity, normalized patch/tree digest, changed-file manifest, generated artifacts, check observations, model/tool lineage, and terminal summary.
      - [ ] 4.3.1.2 Subtask - Validate path scope, candidate size, file modes, binary policy, forbidden content, secret scanning outcome, and absence of untracked material outside the manifest.
      - [ ] 4.3.1.3 Subtask - Close the candidate atomically as immutable content-addressed evidence and prevent the workspace or agent from mutating the closed object.
      - [ ] 4.3.1.4 Subtask - Represent empty, partial, conflicting, oversized, policy-blocked, and capture-failed outcomes explicitly instead of coercing them into a successful candidate.
      - [ ] 4.3.1.5 Subtask - Prove candidate identity changes for every material input change and remains stable across equivalent deterministic captures.

  - [ ] 4.4 Section - Separate verification, disposition, and publication authority.

    This section evaluates the candidate from a fresh environment and prevents
    the producer's claims or local state from becoming acceptance evidence.

    - [ ] 4.4.1 Task {#mcar-p04-verification} [repo: jido_code] [after: {#mcar-p04-candidate}] - Implement independent verification handoff and disposition.

      This task gives a distinct verifier exact inputs and returns an
      attributable result without granting it publication or merge authority.

      - [ ] 4.4.1.1 Subtask - Materialize the exact base and candidate in a fresh isolated checkout using no mutable producer workspace state, caches, credentials, or unpinned dependencies beyond the accepted profile.
      - [ ] 4.4.1.2 Subtask - Run required deterministic checks with independent logs, artifacts, resource observations, deadlines, and closed classifications for unavailable or indeterminate checks.
      - [ ] 4.4.1.3 Subtask - Bind the verification result to candidate digest, verifier profile, toolchain/environment revisions, policy revision, and evidence digests.
      - [ ] 4.4.1.4 Subtask - Implement accept, reject, indeterminate, expired, and superseded dispositions through authorized policy/actor decisions; never infer acceptance from producer success text.
      - [ ] 4.4.1.5 Subtask - Keep branch push, pull-request creation, approval, and merge in separately authorized publication workflows with human merge as the initial production rule.

  - [ ] 4.5 Section - Expose operator and product projections.

    This section makes runtime progress and evidence understandable without
    creating a second control plane in the interface.

    - [ ] 4.5.1 Task {#mcar-p04-projections} [repo: jido_code] [after: {#mcar-p04-verification}] - Implement managed coding attempt projections and controls.

      This task surfaces durable state, bounded interactions, and candidate
      evidence through existing authenticated product boundaries.

      - [ ] 4.5.1.1 Subtask - Project task, attempt, runtime phase, wait reason, budgets, interactions, tool/check summaries, candidate identity, verification, disposition, and audit evidence from graph queries.
      - [ ] 4.5.1.2 Subtask - Add authenticated steer, answer, cancel, and retry controls that submit Factory commands with current attempt/fence and explicit confirmation where policy requires it.
      - [ ] 4.5.1.3 Subtask - Represent delayed, unavailable, indeterminate, cancelled, superseded, and policy-blocked states distinctly from failure or success.
      - [ ] 4.5.1.4 Subtask - Prevent logs, model output, patches, secrets, and cross-tenant identifiers from leaking through summaries, events, URLs, DOM identifiers, or telemetry.
      - [ ] 4.5.1.5 Subtask - Verify refresh, reconnect, duplicate submission, and process restart preserve the same graph-derived view and do not repeat effects.

  - [ ] 4.6 Section - Phase 4 Integration Tests.

    This final section exercises admission, a real bounded agent, candidate
    closure, fresh-checkout verification, disposition, and projections as one
    production-shaped workflow.

    - [ ] 4.6.1 Task {#mcar-p04-integration} [repo: jido_code] [after: {#mcar-p04-projections}] - Execute the managed candidate workflow matrix.

      This task closes MCG4 only when a candidate can cross every boundary with
      complete evidence and no producer-controlled acceptance path.

      - [ ] 4.6.1.1 Subtask - Run successful, rejected, indeterminate, empty, policy-blocked, clarification, cancellation, and supersession fixtures from admission through final disposition.
      - [ ] 4.6.1.2 Subtask - Inject process loss, duplicate commands, stale fences, graph contention, capture failure, verifier timeout, corrupt artifacts, checkout mismatch, and UI reconnect at every lifecycle boundary.
      - [ ] 4.6.1.3 Subtask - Prove verification uses the exact immutable candidate in a fresh checkout, all views reconstruct from graph state, and no runtime/verifier can publish, approve, or merge.
      - [ ] 4.6.1.4 Subtask - Rerun MCG1-MCG3, complete Factory/Knowledge/runtime/tool/model/verifier/UI suites, architecture checks, Dialyzer, and `mix precommit`.

    - [ ] 4.6.2 Task {#mcar-p04-phase-receipt} [repo: jido_code] [after: {#mcar-p04-integration}] - Publish and pin the Phase 4 receipt.

      This task records MCG4 evidence in
      `docs/architecture/managed-coding-phase-04-receipt.md` and authorizes
      Phase 5 only from the pinned merged baseline.

      - [ ] 4.6.2.1 Subtask - Record service, lifecycle, candidate, verifier, disposition, publication, projection, policy, and environment revisions and digests.
      - [ ] 4.6.2.2 Subtask - Attach end-to-end, fresh-checkout, mutation, replay, failure-injection, authorization, and data-isolation evidence with known limitations.
      - [ ] 4.6.2.3 Subtask - Keep MCG4 open if candidate material is mutable, producer evidence can self-verify, graph state is incomplete, or any runtime path can publish/merge.
      - [ ] 4.6.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 5 and preserve every MCG1-MCG4 reopening condition.
