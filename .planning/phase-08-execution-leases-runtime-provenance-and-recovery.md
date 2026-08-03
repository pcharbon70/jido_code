---
id: plan.jido_code_graph_factory_phase_08
intent: feature
source:
  - docs/research/graph-native-managed-repository-factory.md
---

# Phase 8 - Execution Leases, Runtime Provenance, And Recovery

This phase implements fenced execution attempts over leased tasks, bounded
Jido/runtime context, disposable sandbox and tool adapters, complete workflow
provenance, patch/artifact identities, lifecycle transitions, cancellation,
retry, and restart recovery whose durable truth remains entirely in the graph.

Back to plan: [README](./README.md)

- [ ] 8 Phase - Execute governed work without making runtime topology, process state, or tool output authoritative.

  This phase connects the control plane to effectful agents and tools while
  ensuring every operation is scoped by one current lease, exact source
  revision, explicit constraints, and graph-visible attempt history.

  - [x] 8.1 Section - Define runtime, agent, and execution-context boundaries.

    This section creates a product-owned facade over Jido and other runtime
    implementations without encoding kernels, pods, process IDs, or snapshots
    as domain identity.

    - [x] 8.1.1 Task {#jcf-p08-runtime-dependencies} [repo: jido_code] [after: {#jcf-p07-phase-receipt}] - Select and pin the execution runtime dependency set.

      This task admits Jido and related runtime/tool libraries only after their
      lifecycle, persistence, supervision, and version contracts fit the
      graph-only architecture.

      - [x] 8.1.1.1 Subtask {#jcf-p08-8-1-1-1} - Evaluate current Jido runtime APIs, agent/action contracts, supervision requirements, optional persistence behavior, and compatibility with the accepted Elixir/OTP toolchain.
      - [x] 8.1.1.2 Subtask {#jcf-p08-8-1-1-2} - Pin exact versions/revisions and disable or replace any runtime snapshot, memory, queue, or checkpoint persistence outside `TripleStore`.
      - [x] 8.1.1.3 Subtask {#jcf-p08-8-1-1-3} - Record adapter boundaries for model providers, tools, sandboxes, clocks, secrets, and cancellation without granting them graph handles.
      - [x] 8.1.1.4 Subtask {#jcf-p08-8-1-1-4} - Add dependency/namespace checks preventing Jido internals from entering ontology, command, query, or web contracts.
      - [x] 8.1.1.5 Subtask {#jcf-p08-8-1-1-5} - Define upgrade compatibility and mixed-attempt behavior for agent/runtime versions.

    - [x] 8.1.2 Task {#jcf-p08-runtime-port} [repo: jido_code] [after: {#jcf-p08-runtime-dependencies}] - Implement the product-owned execution runtime port.

      This task exposes capability-oriented attempt operations while hiding
      concrete runtime topology and provider payloads from factory services.

      - [x] 8.1.2.1 Subtask {#jcf-p08-8-1-2-1} - Define prepare, start, signal, cancel, status, and terminate operations keyed by attempt/lease/task IRIs plus fencing token.
      - [x] 8.1.2.2 Subtask {#jcf-p08-8-1-2-2} - Define bounded runtime events and outputs containing attempt/tool refs, sequence, times, outcome class, usage, and safe diagnostics.
      - [x] 8.1.2.3 Subtask {#jcf-p08-8-1-2-3} - Keep runtime process IDs, kernel/pod names, provider sessions, model structs, and sandbox handles private to adapters.
      - [x] 8.1.2.4 Subtask {#jcf-p08-8-1-2-4} - Require every runtime callback to validate current fence/cancellation state through bounded factory services before effects.
      - [x] 8.1.2.5 Subtask {#jcf-p08-8-1-2-5} - Supply deterministic fake runtime behavior for success, tool use, timeout, cancellation, crash, lost response, duplicate event, and stale lease.

    - [x] 8.1.3 Task {#jcf-p08-context-package} [repo: jido_code] [after: {#jcf-p08-runtime-port}] - Implement bounded execution context assembly.

      This task builds a reproducible least-privilege package from reviewed
      graph projections instead of dumping repository or memory graphs into an
      agent prompt.

      - [x] 8.1.3.1 Subtask {#jcf-p08-8-1-3-1} - Include enrollment, goal/task/plan, lease/fence, exact repository snapshot, constraints, allowed effects, expected artifacts/evidence, applicable policy, and actor/agent refs.
      - [x] 8.1.3.2 Subtask {#jcf-p08-8-1-3-2} - Select bounded source neighborhoods and accepted knowledge using versioned query/projection contracts with exact source graph revisions.
      - [x] 8.1.3.3 Subtask {#jcf-p08-8-1-3-3} - Apply token/byte/item budgets, redaction, visibility, freshness, contradiction, and truncation policy and preserve what was omitted.
      - [x] 8.1.3.4 Subtask {#jcf-p08-8-1-3-4} - Fingerprint the normalized context and persist its durable instruction/context entities only through the attempt-start change set.
      - [x] 8.1.3.5 Subtask {#jcf-p08-8-1-3-5} - Reject stale leases, mismatched snapshots, unaccepted plans, incomplete strict inputs, secret-bearing projections, and authority widening.

    - [x] 8.1.4 Task {#jcf-p08-runtime-supervision} [repo: jido_code] [after: {#jcf-p08-context-package}] - Implement execution supervision by attempt identity.

      This task manages ephemeral workers while allowing every process to be
      recreated or abandoned from graph-visible lifecycle state.

      - [x] 8.1.4.1 Subtask {#jcf-p08-8-1-4-1} - Add a registry and `DynamicSupervisor` for active attempts with names derived from opaque attempt IRIs through a bounded mapping.
      - [x] 8.1.4.2 Subtask {#jcf-p08-8-1-4-2} - Start at most one local worker per active attempt/fence and reject duplicate stale workers.
      - [x] 8.1.4.3 Subtask {#jcf-p08-8-1-4-3} - Permit optional warm repository runtime processes only as caches and prove they can be recreated without domain changes.
      - [x] 8.1.4.4 Subtask {#jcf-p08-8-1-4-4} - Define restart intensity, isolation, admission, shutdown, and orphan cleanup so one failing attempt cannot destabilize the store or endpoint.

    - [x] 8.1.5 Task {#jcf-p08-interaction-session} [repo: jido_code] [after: {#jcf-p08-runtime-supervision}] - Implement graph-native interaction and instruction sessions.

      This task makes durable human/agent interaction auditable without turning
      chat state or prompt memory into a parallel source of truth.

      - [x] 8.1.5.1 Subtask {#jcf-p08-8-1-5-1} - Scope each interaction session to repository enrollment, goal, task, or attempt IRIs and record participants, audiences, authority, purpose, lifecycle, and provenance.
      - [x] 8.1.5.2 Subtask {#jcf-p08-8-1-5-2} - Persist durable messages as graph resources with sender, audience, sequence, reply references, content classification, timestamps, and provenance while keeping unsent UI drafts ephemeral.
      - [x] 8.1.5.3 Subtask {#jcf-p08-8-1-5-3} - Interpret message intent only as a proposal, clarification, steering request, or cancellation request that invokes a separately authorized semantic command and never mutates goals, tasks, leases, or attempts directly.
      - [x] 8.1.5.4 Subtask {#jcf-p08-8-1-5-4} - Persist instructions and assembled context only when required for durability, replay, or audit, with redaction and size bounds; keep transient prompt assembly disposable.
      - [x] 8.1.5.5 Subtask {#jcf-p08-8-1-5-5} - Provide authorized, paginated interaction projections that preserve chronology, reply relationships, redaction state, and links to resulting commands, evidence, and decisions.

  - [ ] 8.2 Section - Implement execution-attempt and lease-fencing lifecycle.

    This section binds runtime work to one graph-visible attempt, task, lease,
    actor, capability, snapshot, and transition chain.

    - [ ] 8.2.1 Task {#jcf-p08-attempt-start} [repo: jido_code] [after: {#jcf-p08-interaction-session}] - Implement guarded execution-attempt creation and start.

      This task creates durable execution identity before any effectful runtime
      operation can occur.

      - [ ] 8.2.1.1 Subtask {#jcf-p08-8-2-1-1} - Implement `RecordExecutionAttempt` start semantics with attempt, task/goal/plan, lease/fence, actor/agent/capability, exact snapshot, context digest, runtime version, constraints, and idempotency.
      - [ ] 8.2.1.2 Subtask {#jcf-p08-8-2-1-2} - Atomically transition task/lease to executing and create the run graph metadata plus attempt genesis transition.
      - [ ] 8.2.1.3 Subtask {#jcf-p08-8-2-1-3} - Reject expired/superseded leases, stale fences, changed task/plan/snapshot, unauthorized agents, duplicate active attempts, and incompatible runtime versions.
      - [ ] 8.2.1.4 Subtask {#jcf-p08-8-2-1-4} - Start the runtime only after the attempt-start receipt commits and recover response loss by attempt/idempotency identity.
      - [ ] 8.2.1.5 Subtask {#jcf-p08-8-2-1-5} - If runtime start fails, record a governed failed-to-start transition rather than deleting the attempt.

    - [ ] 8.2.2 Task {#jcf-p08-attempt-transitions} [repo: jido_code] [after: {#jcf-p08-attempt-start}] - Implement heartbeat, progress, completion, failure, and cancellation transitions.

      This task records bounded operational state causally while preventing
      runtime events from mutating goals or decisions directly.

      - [ ] 8.2.2.1 Subtask {#jcf-p08-8-2-2-1} - Define attempt states for prepared, starting, running, waiting-tool, cancelling, cancelled, completed, failed, timed-out, abandoned, recovered, and superseded.
      - [ ] 8.2.2.2 Subtask {#jcf-p08-8-2-2-2} - Require current attempt predecessor/revision and lease fence on every runtime-origin transition.
      - [ ] 8.2.2.3 Subtask {#jcf-p08-8-2-2-3} - Record bounded heartbeats/progress as transitions or summarized activities according to retention policy without high-frequency hidden state.
      - [ ] 8.2.2.4 Subtask {#jcf-p08-8-2-2-4} - Make cancellation a control command, propagate it to runtime/tool/sandbox adapters, and record acknowledged, forced, timed-out, or ineffective outcomes.
      - [ ] 8.2.2.5 Subtask {#jcf-p08-8-2-2-5} - Treat completion as an execution outcome only; never transition a goal to satisfied in this command.

    - [ ] 8.2.3 Task {#jcf-p08-attempt-retry} [repo: jido_code] [after: {#jcf-p08-attempt-transitions}] - Implement retry and follow-up attempt semantics.

      This task ensures a retry is a new attributable activity rather than a
      mutable reset of prior execution history.

      - [ ] 8.2.3.1 Subtask {#jcf-p08-8-2-3-1} - Evaluate retry policy from task/plan, failure classification, attempt count, budget, source/plan freshness, lease state, and cancellation.
      - [ ] 8.2.3.2 Subtask {#jcf-p08-8-2-3-2} - Create a new attempt and lease/fence where required, link it to the prior attempt, and preserve all prior run graphs.
      - [ ] 8.2.3.3 Subtask {#jcf-p08-8-2-3-3} - Require replanning/reconciliation instead of retry when source snapshot, constraints, policy, or required capability changed materially.
      - [ ] 8.2.3.4 Subtask {#jcf-p08-8-2-3-4} - Bound automated attempts and require an explicit decision for exhausted, unsafe, repeated, or ambiguous failure.

  - [ ] 8.3 Section - Implement sandbox, tool, and patch provenance.

    This section performs bounded effects and captures their operational
    history without promoting raw output into evidence or durable knowledge.

    - [ ] 8.3.1 Task {#jcf-p08-sandbox-port} [repo: jido_code] [after: {#jcf-p08-attempt-retry}] - Define and implement the disposable sandbox boundary.

      This task isolates repository work and external commands under explicit
      resource, network, filesystem, and lifecycle constraints.

      - [ ] 8.3.1.1 Subtask {#jcf-p08-8-3-1-1} - Define provision, materialize snapshot, execute, inspect, cancel, collect, and destroy operations keyed by attempt/lease/fence.
      - [ ] 8.3.1.2 Subtask {#jcf-p08-8-3-1-2} - Enforce base snapshot, allowed write scope, command/tool allowlist, environment allowlist, secret injection scope, CPU/memory/disk/time/network limits, and output bounds.
      - [ ] 8.3.1.3 Subtask {#jcf-p08-8-3-1-3} - Keep sandbox IDs/paths private and represent durable identity through attempt, snapshot, artifact digests, and provider refs only.
      - [ ] 8.3.1.4 Subtask {#jcf-p08-8-3-1-4} - Destroy or quarantine work material after collection and prove its loss does not remove committed attempt history.
      - [ ] 8.3.1.5 Subtask {#jcf-p08-8-3-1-5} - Handle sandbox unavailable, partial provisioning, network denial, resource exhaustion, cleanup failure, and orphan discovery explicitly.

    - [ ] 8.3.2 Task {#jcf-p08-tool-invocation} [repo: jido_code] [after: {#jcf-p08-sandbox-port}] - Implement governed tool invocation and event capture.

      This task records which capability performed which bounded effect with
      which inputs and outputs while treating all tool results as untrusted.

      - [ ] 8.3.2.1 Subtask {#jcf-p08-8-3-2-1} - Create tool invocation activity IRIs with attempt, tool/capability/version, actor/agent, lease/fence, input refs/digests, sequence, deadline, and expected effect class.
      - [ ] 8.3.2.2 Subtask {#jcf-p08-8-3-2-2} - Authorize each invocation against task constraints and current fence immediately before effect.
      - [ ] 8.3.2.3 Subtask {#jcf-p08-8-3-2-3} - Record start/outcome, timing, exit/status class, bounded stdout/stderr or external refs, resource usage, generated artifact refs, and redaction result.
      - [ ] 8.3.2.4 Subtask {#jcf-p08-8-3-2-4} - Make duplicate provider/runtime events idempotent by invocation/sequence identity and reject divergent replay.
      - [ ] 8.3.2.5 Subtask {#jcf-p08-8-3-2-5} - Prohibit a tool adapter from issuing semantic commands beyond its declared observation/execution result capability.

    - [ ] 8.3.3 Task {#jcf-p08-patch-artifacts} [repo: jido_code] [after: {#jcf-p08-tool-invocation}] - Implement patch and generated-artifact identity.

      This task makes proposed changes reproducible against an exact base
      snapshot without introducing an application-owned blob database.

      - [ ] 8.3.3.1 Subtask {#jcf-p08-8-3-3-1} - Identify patches by base snapshot, normalized diff/content digest, media type, size, generator activity, and affected path/symbol scope.
      - [ ] 8.3.3.2 Subtask {#jcf-p08-8-3-3-2} - Store bounded textual artifacts as graph literals only under accepted size/sensitivity policy; otherwise store provider-owned immutable URI plus digest/verification metadata.
      - [ ] 8.3.3.3 Subtask {#jcf-p08-8-3-3-3} - Record proposed commit/tree identity when materialized and link source semantic entities affected by the patch.
      - [ ] 8.3.3.4 Subtask {#jcf-p08-8-3-3-4} - Preserve patch conflicts, partial output, rejected paths, and cleanup failures as attempt findings without accepting them as evidence.
      - [ ] 8.3.3.5 Subtask {#jcf-p08-8-3-3-5} - Verify artifact content/digest on every later use and fail closed on unavailable or mismatched external content.

  - [ ] 8.4 Section - Implement execution provenance projection and restart recovery.

    This section makes active and historical attempts inspectable and allows
    runtime state to be rebuilt after process or host failure.

    - [ ] 8.4.1 Task {#jcf-p08-provenance-capture} [repo: jido_code] [after: {#jcf-p08-patch-artifacts}] - Finalize immutable run graph capture.

      This task closes one attempt's operational history with complete inputs,
      activities, outputs, limitations, and outcome while leaving evaluation
      to Phase 9.

      - [ ] 8.4.1.1 Subtask {#jcf-p08-8-4-1-1} - Link attempt to enrollment, goal/task/plan, lease/fence, exact snapshot, context/instruction, actor/agent/runtime, tool invocations, sandbox activity, patches/artifacts, and transitions.
      - [ ] 8.4.1.2 Subtask {#jcf-p08-8-4-1-2} - Record terminal outcome, bounded diagnostics, usage, cancellation/retry refs, missing outputs, and provenance completeness.
      - [ ] 8.4.1.3 Subtask {#jcf-p08-8-4-1-3} - Validate and close the run graph immutable only after all accepted invocation/activity events through the terminal sequence are present.
      - [ ] 8.4.1.4 Subtask {#jcf-p08-8-4-1-4} - Mark incomplete/abandoned run graphs explicitly and permit later recovery additions only through the defined open lifecycle before closure.

    - [ ] 8.4.2 Task {#jcf-p08-attempt-projections} [repo: jido_code] [after: {#jcf-p08-provenance-capture}] - Implement attempt status, timeline, and artifact projections.

      This task exposes bounded execution state and history to product,
      recovery, and later evaluation services.

      - [ ] 8.4.2.1 Subtask {#jcf-p08-8-4-2-1} - Add active-attempt, attempt-by-task, transition timeline, tool invocation, patch/artifact, cancellation, retry lineage, and run completeness queries.
      - [ ] 8.4.2.2 Subtask {#jcf-p08-8-4-2-2} - Include current fence, runtime/agent versions, source snapshot, graph revisions, last bounded activity, terminal state, warnings, and redacted diagnostics.
      - [ ] 8.4.2.3 Subtask {#jcf-p08-8-4-2-3} - Bound timeline pages, tool output summaries, artifacts, source links, and retained context without exposing secret-bearing prompts or raw runtime internals.
      - [ ] 8.4.2.4 Subtask {#jcf-p08-8-4-2-4} - Distinguish runtime completion from verification/evidence/decision state explicitly.

    - [ ] 8.4.3 Task {#jcf-p08-runtime-recovery} [repo: jido_code] [after: {#jcf-p08-attempt-projections}] - Implement startup and periodic attempt recovery.

      This task reconciles graph-visible attempts and leases with disposable
      runtime/sandbox state after crashes or lost callbacks.

      - [ ] 8.4.3.1 Subtask {#jcf-p08-8-4-3-1} - Query non-terminal attempts and valid/expired leases at startup before admitting new execution.
      - [ ] 8.4.3.2 Subtask {#jcf-p08-8-4-3-2} - Inspect provider/runtime/sandbox status through opaque refs and current fence without trusting process registry alone.
      - [ ] 8.4.3.3 Subtask {#jcf-p08-8-4-3-3} - Resume only when runtime/version/snapshot/lease policy permits; otherwise cancel, abandon, fail, or supersede through semantic transitions.
      - [ ] 8.4.3.4 Subtask {#jcf-p08-8-4-3-4} - Recover missing terminal callbacks idempotently and reject stale provider events after lease/attempt supersession.
      - [ ] 8.4.3.5 Subtask {#jcf-p08-8-4-3-5} - Discover and clean orphaned runtime/sandbox resources without inventing completed graph state.

  - [ ] 8.5 Section - Phase 8 Integration Tests.

    This final section proves only currently leased and fenced attempts can
    produce effects, all execution remains attributable, and complete behavior
    can recover from graph after runtime, sandbox, scheduler, store, or host
    interruption.

    - [ ] 8.5.1 Task {#jcf-p08-execution-integration} [repo: jido_code] [after: {#jcf-p08-runtime-recovery}] - Execute one leased task through runtime, tools, patch output, and immutable provenance.

      This task validates the complete control-to-execution seam with a
      deterministic runtime and controlled real sandbox/tool fixture.

      - [ ] 8.5.1.1 Subtask {#jcf-p08-8-5-1-1} - Acquire a lease, create/start an attempt, build exact context, invoke tools, produce a patch, complete, close the run graph, and project the timeline.
      - [ ] 8.5.1.2 Subtask {#jcf-p08-8-5-1-2} - Verify every effect cites current task/lease/fence, actor/agent/capability, snapshot, constraint, invocation, and graph revision.
      - [ ] 8.5.1.3 Subtask {#jcf-p08-8-5-1-3} - Race duplicate starts/events, stale fences, lease expiry/renewal, cancellation, tool timeout, and retry creation.
      - [ ] 8.5.1.4 Subtask {#jcf-p08-8-5-1-4} - Prove completed runtime output does not satisfy the goal or become accepted evidence/knowledge before Phase 9 decisions.

    - [ ] 8.5.2 Task {#jcf-p08-recovery-security-integration} [repo: jido_code] [after: {#jcf-p08-execution-integration}] - Exercise crash recovery, hostile tools, redaction, and disposable-state loss.

      This task falsifies the execution boundary under process death, provider
      ambiguity, unsafe repository content, and secret exposure attempts.

      - [ ] 8.5.2.1 Subtask {#jcf-p08-8-5-2-1} - Kill runtime, attempt worker, sandbox adapter, scheduler, store process, and BEAM at prepared/running/tool/commit/completed boundaries and reconcile each outcome.
      - [ ] 8.5.2.2 Subtask {#jcf-p08-8-5-2-2} - Delete process registries, in-memory queues/caches, and local worktrees, restart, and rebuild active/historical attempt behavior from graph plus external provider status.
      - [ ] 8.5.2.3 Subtask {#jcf-p08-8-5-2-3} - Attempt path escape, hook/config abuse, unauthorized network/tool use, resource exhaustion, output flooding, artifact substitution, and stale provider callbacks.
      - [ ] 8.5.2.4 Subtask {#jcf-p08-8-5-2-4} - Inject fixture secrets and verify graph, run exports, logs, telemetry, events, errors, prompts/context projections, and artifacts honor redaction policy.
      - [ ] 8.5.2.5 Subtask {#jcf-p08-8-5-2-5} - Backup/restore during supported attempt states and verify recovery/abandonment semantics at the restored dataset lineage.
      - [ ] 8.5.2.6 Subtask {#jcf-p08-8-5-2-6} - Rerun Phases 1-7 suites and `mix precommit`.

    - [ ] 8.5.3 Task {#jcf-p08-phase-receipt} [repo: jido_code] [after: {#jcf-p08-recovery-security-integration}] - Publish the Phase 8 governed-execution receipt.

      This task binds G7 to exact runtime, agent, context, lease/fence, sandbox,
      tool, artifact, provenance, retry, cancellation, recovery, security, and
      restart evidence.

      - [ ] 8.5.3.1 Subtask {#jcf-p08-8-5-3-1} - Record runtime/tool/sandbox versions, context/query/ontology versions, scenario/snapshot/artifact digests, limits, and candidate commit.
      - [ ] 8.5.3.2 Subtask {#jcf-p08-8-5-3-2} - Attach lease/start races, attempt timelines, tool/patch provenance, cancellation/retry, crash/restart, hostile-input, redaction, and restore results.
      - [ ] 8.5.3.3 Subtask {#jcf-p08-8-5-3-3} - Keep G7 blocked if process/runtime state is required for recovery, a stale fence can cause effects, or completion can self-satisfy a goal.
      - [ ] 8.5.3.4 Subtask {#jcf-p08-8-5-3-4} - Pin the merged candidate commit before authorizing Phase 9.
