---
id: plan.jido_code_managed_coding_agent_runtime_phase_05
parent_plan: plan.jido_code_managed_coding_agent_runtime
status: planned
intent: feature
---

# Managed Coding Phase 5 - Recovery, Cancellation, Security, And Capacity

This phase hardens the managed workflow for process loss, ambiguous effects,
hostile inputs, cancellation races, and finite production capacity. Recovery is
derived from durable evidence; it never assumes that a crashed process either
completed or did not complete an external effect.

Back to plan: [README](./README.md)

- [ ] 5 Phase - Make managed coding safely recoverable, cancellable, isolated, and capacity bounded.

  This phase proves MCG5 by preserving the accepted authority model throughout
  operational faults and adversarial conditions.

  - [x] 5.1 Section - Reconstruct attempts from durable evidence.

    This section treats Jido processes and workspaces as replaceable execution
    material while preserving graph identity and committed progress.

    - [x] 5.1.1 Task {#mcar-p05-recovery} [repo: jido_code] [after: {#mcar-p04-phase-receipt}] - Implement graph-driven recovery and reconciliation.

      This task resumes only from facts that can be proven and fences every
      abandoned runtime before a replacement can act.

      - [x] 5.1.1.1 Subtask - Discover admitted nonterminal attempts, acquire a new lease/fence, and reconstruct strategy state from ordered graph facts plus validated immutable artifacts.
      - [x] 5.1.1.2 Subtask - Define recovery behavior for every lifecycle point from pre-workspace admission through candidate verification and final disposition.
      - [x] 5.1.1.3 Subtask - Recreate disposable workspaces and agent processes from pinned inputs rather than relying on process snapshots or orphaned filesystem state.
      - [x] 5.1.1.4 Subtask - Compare reconstruction watermarks, invocation identities, budgets, candidate digests, and terminal facts before resuming any continuation.
      - [x] 5.1.1.5 Subtask - Quarantine contradictory, incomplete, unverifiable, or future-version evidence and require an authorized resolution instead of guessing.

  - [x] 5.2 Section - Reconcile retries and ambiguous effects.

    This section distinguishes safe replay from effects whose outcome is
    unknown, preventing a restart from duplicating or fabricating work.

    - [x] 5.2.1 Task {#mcar-p05-reconciliation} [repo: jido_code] [after: {#mcar-p05-recovery}] - Implement effect-specific retry and ambiguity handling.

      This task assigns each external operation an explicit idempotency and
      reconciliation contract before automatic retry is permitted.

      - [x] 5.2.1.1 Subtask - Classify context, model, tool, filesystem, credential, artifact, verifier, interaction, and publication operations as replayable, query-reconcilable, compensatable, or manual-resolution-only.
      - [x] 5.2.1.2 Subtask - Persist intent before dispatch and outcome after completion using stable invocation/idempotency keys and current fence identity.
      - [x] 5.2.1.3 Subtask - Query authoritative adapters or compare content-addressed state when an outcome is ambiguous; never interpret timeout or caller death as non-execution.
      - [x] 5.2.1.4 Subtask - Bound retry count, elapsed time, backoff, jitter, and resource consumption by the admitted profile and record every retry decision.
      - [x] 5.2.1.5 Subtask - Route irreconcilable ambiguity to a closed operator interaction that cannot widen capability or erase prior evidence.

  - [x] 5.3 Section - Make cancellation race safe.

    This section defines cancellation as a durable protocol spanning the graph,
    process, directive, workspace, credential, and verifier boundaries.

    - [x] 5.3.1 Task {#mcar-p05-cancellation} [repo: jido_code] [after: {#mcar-p05-reconciliation}] - Implement cancellation and late-output containment.

      This task ensures a cancellation request converges to a terminal outcome
      without allowing stale work to regain authority.

      - [x] 5.3.1.1 Subtask - Commit cancellation request identity, actor, reason, time, and target fence before signalling runtime components.
      - [x] 5.3.1.2 Subtask - Stop new dispatch, revoke credentials/capabilities, cancel queued work, terminate supervised effects after bounded grace, and release capacity deterministically.
      - [x] 5.3.1.3 Subtask - Record late or uninterruptible results as non-authoritative observations and prevent them from advancing state, closing candidates, or changing disposition.
      - [x] 5.3.1.4 Subtask - Resolve races among completion, cancellation, lease expiry, restart, verification, and disposition through explicit compare-and-commit rules.
      - [x] 5.3.1.5 Subtask - Clean or quarantine workspaces and secrets according to retention policy while preserving immutable audit evidence.

  - [x] 5.4 Section - Enforce hostile-input and tenant isolation controls.

    This section assumes repositories, task text, model output, tool output, and
    dependencies may be malicious and keeps them below host policy authority.

    - [x] 5.4.1 Task {#mcar-p05-security} [repo: jido_code] [after: {#mcar-p05-cancellation}] - Implement runtime security and adversarial controls.

      This task validates isolation across data, credentials, network, process,
      filesystem, logs, artifacts, and control messages.

      - [x] 5.4.1.1 Subtask - Enforce tenant/repository scoping on every lookup, command, signal, artifact, cache key, workspace, credential request, projection, and telemetry dimension.
      - [x] 5.4.1.2 Subtask - Treat repository instructions, generated code, dependency hooks, tool output, model text, and retrieved memory as untrusted data that cannot alter host policy or adapter selection.
      - [x] 5.4.1.3 Subtask - Apply sandbox process, filesystem, network, environment, resource, child-process, and symlink boundaries to both coding tools and independent verification.
      - [x] 5.4.1.4 Subtask - Redact and classify secrets and sensitive source in prompts, tool results, logs, signals, errors, artifacts, metrics, and operator views while retaining auditable digests.
      - [x] 5.4.1.5 Subtask - Add adversarial fixtures for prompt injection, path traversal, symlink escape, fork bombs, output floods, secret exfiltration, cross-tenant references, forged signals, and dependency lifecycle scripts.

  - [ ] 5.5 Section - Bound capacity and expose operational health.

    This section prevents managed coding workloads from exhausting the host and
    gives operators evidence to shed load before safety degrades.

    - [ ] 5.5.1 Task {#mcar-p05-capacity} [repo: jido_code] [after: {#mcar-p05-security}] - Implement admission back-pressure, quotas, and runtime observability.

      This task connects resource ceilings to admission and scheduling without
      creating unbounded internal queues.

      - [ ] 5.5.1.1 Subtask - Define global, tenant, repository, provider, sandbox, verifier, and adapter concurrency/queue limits with fair scheduling and explicit reserved capacity.
      - [ ] 5.5.1.2 Subtask - Reject or defer work before durable admission when capacity is unavailable and expire admitted queue positions under bounded policy.
      - [ ] 5.5.1.3 Subtask - Measure queue age, active attempts, directive latency, budget burn, crashes, retries, ambiguity, cancellation lag, verifier lag, and resource saturation without high-cardinality leaks.
      - [ ] 5.5.1.4 Subtask - Implement health checks and alerts for stuck attempts, orphaned leases/workspaces, missing outcomes, fence conflicts, evidence gaps, and sustained capacity pressure.
      - [ ] 5.5.1.5 Subtask - Document operational limits, degradation modes, safe drain, restart, reconciliation, quarantine, and emergency-disable procedures.

  - [ ] 5.6 Section - Phase 5 Integration Tests.

    This final section subjects the complete workflow to fault injection,
    cancellation races, adversarial repositories, and sustained bounded load.

    - [ ] 5.6.1 Task {#mcar-p05-integration} [repo: jido_code] [after: {#mcar-p05-capacity}] - Execute the resilience, security, and capacity matrix.

      This task closes MCG5 only when faults and hostile inputs fail closed while
      healthy work continues within declared capacity.

      - [ ] 5.6.1.1 Subtask - Kill and restart coordinators, agents, dispatchers, adapters, workspaces, providers, and verifiers before dispatch, during effects, after outcomes, and at every terminal race.
      - [ ] 5.6.1.2 Subtask - Run ambiguity, duplicate, late-output, cancellation, lease expiry, graph contention, corrupt evidence, tenant-isolation, sandbox-escape, secret-leak, and output-flood fixtures.
      - [ ] 5.6.1.3 Subtask - Sustain work above configured capacity and prove bounded queues/mailboxes, fair admission, correct rejection/defer semantics, complete cleanup, and useful alerts.
      - [ ] 5.6.1.4 Subtask - Rerun MCG1-MCG4, complete recovery/security/load/runtime/verifier/UI suites, architecture checks, Dialyzer, and `mix precommit`.

    - [ ] 5.6.2 Task {#mcar-p05-phase-receipt} [repo: jido_code] [after: {#mcar-p05-integration}] - Publish and pin the Phase 5 receipt.

      This task records MCG5 evidence in
      `docs/architecture/managed-coding-phase-05-receipt.md` and authorizes
      Phase 6 only from the pinned merged baseline.

      - [ ] 5.6.2.1 Subtask - Record recovery, retry, cancellation, sandbox, redaction, quota, scheduler, telemetry, alert, and runbook revisions and digests.
      - [ ] 5.6.2.2 Subtask - Attach crash-point, ambiguity, race, adversarial, cross-tenant, saturation, cleanup, and restart evidence with measured limits and known limitations.
      - [ ] 5.6.2.3 Subtask - Keep MCG5 open if recovery guesses effect outcomes, cancellation permits late authority, isolation can be crossed, or capacity is not fail-closed and bounded.
      - [ ] 5.6.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 6 and preserve every MCG1-MCG5 reopening condition.
