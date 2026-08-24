---
id: plan.jido_code_managed_coding_agent_runtime_phase_03
parent_plan: plan.jido_code_managed_coding_agent_runtime
status: planned
intent: feature
---

# Managed Coding Phase 3 - Single-Agent Coding Strategy And Loop

This phase implements the first real host-controlled coding agent. One
disposable `Jido.Agent` uses a custom strategy, typed actions, runtime-owned
directives, and closed signals to alternate between exact context, one model
interaction, one governed tool effect, and bounded continuation.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Run one bounded Jido agent through a complete inspect-plan-edit-check loop.

  This phase proves MCG3 by connecting the accepted model and tool seams without
  allowing the agent strategy to call graph internals, effects, or providers
  directly.

  - [x] 3.1 Section - Implement agent state and the coding strategy.

    This section gives the runtime an explicit, inspectable behavioral state
    machine rather than an effectful recursive loop.

    - [x] 3.1.1 Task {#mcar-p03-strategy} [repo: jido_code] [after: {#mcar-p02-phase-receipt}] - Implement `ManagedCodingAgent` and `ManagedCodingStrategy`.

      This task defines the pure state transitions that select the next bounded
      effect or terminal proposal.

      - [x] 3.1.1.1 Subtask - Define validated agent state for attempt/fence identity, phase, sequence, exact profile/context/tool/model digests, current invocation references, budgets, candidate digests, cancellation, terminal classification, and reconstruction watermark.
      - [x] 3.1.1.2 Subtask - Implement strategy initialization, action specifications, command handling, continuation ticks, stable snapshots, and closed signal routes.
      - [x] 3.1.1.3 Subtask - Implement pure actions for begin, context result, model result, tool result, actor response, candidate result, cancellation, budget exhaustion, and recovery.
      - [x] 3.1.1.4 Subtask - Enforce legal transitions across preparing, awaiting model, awaiting tool, awaiting actor, assembling candidate, candidate ready, cancelling, completed, cancelled, and failed states.
      - [x] 3.1.1.5 Subtask - Reject unknown, stale, duplicate, cross-attempt, wrong-invocation, wrong-fence, and post-terminal actions without reopening or silently advancing the loop.

  - [x] 3.2 Section - Implement directives and result routing.

    This section moves all external work out of strategy code and returns typed
    correlated results through the AgentServer boundary.

    - [x] 3.2.1 Task {#mcar-p03-directives} [repo: jido_code] [after: {#mcar-p03-strategy}] - Implement the managed coding directive executor and dispatcher.

      This task owns asynchronous effect execution, back-pressure, correlation,
      and safe result delivery while keeping strategy decisions pure.

      - [x] 3.2.1.1 Subtask - Define closed directive structs for context compilation, model dispatch, governed tool execution, actor clarification, candidate capture, runtime observation, and bounded continuation.
      - [x] 3.2.1.2 Subtask - Implement one supervised dispatcher with per-attempt queues, concurrency ceilings, deadlines, monitors, cancellation, and no unbounded mailbox growth.
      - [x] 3.2.1.3 Subtask - Correlate every directive and result by attempt, fence, strategy sequence, effect type, and invocation IRI and deliver only to the current runtime identity.
      - [x] 3.2.1.4 Subtask - Convert crashes, exits, timeouts, corrupt returns, missing adapters, and late completions into closed bounded result signals without leaking implementation errors.
      - [x] 3.2.1.5 Subtask - Prove directive executors call only Factory facades/ports, never Knowledge internals, raw adapters selected by the model, or the store.

  - [x] 3.3 Section - Connect exact context and model interactions.

    This section compiles the task's attributable input and treats every model
    turn as one separately governed interaction.

    - [x] 3.3.1 Task {#mcar-p03-context-model} [repo: jido_code] [after: {#mcar-p03-directives}] - Integrate `ContextCompiler`, memory packets, and `ModelGateway` with the strategy.

      This task gives the agent useful context and structured model output
      without granting the provider control of the loop or tool plane.

      - [x] 3.3.1.1 Subtask - Build the first context manifest from exact task, policy, snapshot, graph, prompt, tool, profile, and authority revisions with deterministic ordering, budgets, omissions, and classifications.
      - [x] 3.3.1.2 Subtask - Append only separately authorized, temporally eligible, source-complete memory evidence packets as non-instructional context and preserve no-memory equivalence when disabled.
      - [x] 3.3.1.3 Subtask - Define a strict model response union for tool proposal, completion proposal, clarification, and abstention/failure with closed schemas and no legacy coercion or repair fallback.
      - [x] 3.3.1.4 Subtask - Commit invocation start before dispatch, use the sole ModelGateway with explicit credential release and no provider fallback, and record one bounded outcome before continuation.
      - [x] 3.3.1.5 Subtask - Recompile context after relevant source, workspace, policy, lease, capability, prompt, tool, memory partition, or erasure-generation changes rather than silently reusing stale context.

  - [x] 3.4 Section - Enforce loop budgets, steering, and terminal proposals.

    This section prevents a useful loop from becoming an unbounded autonomous
    process and keeps operator input inside the accepted interaction boundary.

    - [x] 3.4.1 Task {#mcar-p03-loop-control} [repo: jido_code] [after: {#mcar-p03-context-model}] - Implement bounded continuation and actor steering.

      This task makes every next turn an explicit policy decision and ensures
      terminal model text remains a proposal rather than an accepted outcome.

      - [x] 3.4.1.1 Subtask - Decrement and persist bounded observations for turns, model calls, tokens, tool calls, bytes, time, cost, changed files, diff size, checks, and clarification rounds at their enforcement points.
      - [x] 3.4.1.2 Subtask - Stop before the next effect when any hard or next-effect budget is exhausted and record which dimensions were unavailable or observed-only.
      - [x] 3.4.1.3 Subtask - Route clarification through an authenticated actor session with purpose, audience, expiry, size bounds, and no capability widening through response text.
      - [x] 3.4.1.4 Subtask - Support bounded operator steer, pause, resume, and cancellation only through graph-authorized interactions and current attempt/fence validation.
      - [x] 3.4.1.5 Subtask - Treat completion as a candidate proposal requiring deterministic candidate capture and later verification; reject model claims of test success, evidence sufficiency, acceptance, publication, or merge.

  - [ ] 3.5 Section - Phase 3 Integration Tests.

    This final section exercises the real Jido AgentServer, deterministic model
    fixtures, governed tools, and graph accounting as one loop.

    - [ ] 3.5.1 Task {#mcar-p03-integration} [repo: jido_code] [after: {#mcar-p03-loop-control}] - Execute the single-agent loop matrix.

      This task closes MCG3 only when the agent can produce a bounded candidate
      proposal without bypassing host authority.

      - [ ] 3.5.1.1 Subtask - Run inspect-only, edit, create/delete, registered-check, clarification, abstention, and candidate-completion fixtures through a real AgentServer and isolated workspace.
      - [ ] 3.5.1.2 Subtask - Inject malformed model output, invalid tools, prompt injection, duplicate/late signals, stale context, budget exhaustion, provider timeout, adapter crash, and cancellation at every phase.
      - [ ] 3.5.1.3 Subtask - Prove the strategy never calls Knowledge or effects directly, every external action has complete graph accounting, and terminal proposals have no verification/publication authority.
      - [ ] 3.5.1.4 Subtask - Rerun MCG1-MCG2, complete harness/model/tool/memory suites, architecture checks, Dialyzer, and `mix precommit`.

    - [ ] 3.5.2 Task {#mcar-p03-phase-receipt} [repo: jido_code] [after: {#mcar-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records MCG3 evidence in
      `docs/architecture/managed-coding-phase-03-receipt.md` and authorizes
      Phase 4 only from the pinned merged baseline.

      - [ ] 3.5.2.1 Subtask - Record agent, strategy, action, directive, signal, dispatcher, context, prompt, model, tool, and budget revisions and digests.
      - [ ] 3.5.2.2 Subtask - Attach loop, malformed-result, budget, steering, cancellation, and authority-separation evidence with known limitations.
      - [ ] 3.5.2.3 Subtask - Keep MCG3 open if any model can choose an adapter/sink, any effect bypasses a directive, or any terminal claim gains authority.
      - [ ] 3.5.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 4 and preserve every MCG1-MCG3 reopening condition.
