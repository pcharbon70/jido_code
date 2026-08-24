---
id: plan.jido_code_managed_coding_agent_runtime_phase_01
parent_plan: plan.jido_code_managed_coding_agent_runtime
status: planned
intent: feature
---

# Managed Coding Phase 1 - Runtime Contract, Authority, And Compatibility

This phase makes the managed coding runtime executable on paper and in
conformance code before it can call a model or mutate a workspace. It fixes the
state-ownership boundary, coding-profile schema, action/directive/signal
protocol, graph accounting, Jido compatibility baseline, and threat fixtures.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Establish a graph-authorized coding-runtime contract before enabling coding effects.

  This phase proves MCG1 by giving every runtime state, transition, effect, and
  recovery input exactly one owner and by preventing Jido or pod state from
  becoming competing product truth.

  - [ ] 1.1 Section - Ratify runtime ownership and lifecycle.

    This section defines what the graph, Factory, Runtime, agent strategy, and
    integrations own throughout one coding attempt.

    - [ ] 1.1.1 Task {#mcar-p01-runtime-boundary} [repo: jido_code] - Publish the managed coding runtime specification.

      This task turns the research boundary into an accepted, versioned
      contract that all later modules and tests consume.

      - [ ] 1.1.1.1 Subtask - Define the stable `ManagedCoding` Factory API for admission, start, steering, cancellation, status, and candidate handoff without exposing pids, pod nodes, graph handles, provider sessions, or sandbox paths.
      - [ ] 1.1.1.2 Subtask - Partition every field among graph-owned durable state, Factory command/projection state, agent working state, pod topology projection, and integration-only effect state.
      - [ ] 1.1.1.3 Subtask - Define one attempt-per-runtime identity from attempt IRI plus fencing token, including duplicate-start, supersession, terminal, and incompatible-revision behavior.
      - [ ] 1.1.1.4 Subtask - Define the supported single-agent lifecycle and explicitly keep pod specialists, AgentOS persistence, managed JidoHarness writes, and autonomous merge disabled.
      - [ ] 1.1.1.5 Subtask - Update module-boundary and architecture-enforcement specifications so Runtime can use Factory-owned ports but cannot call Knowledge internals or persist product truth through Jido storage.

  - [ ] 1.2 Section - Define coding profiles, budgets, and controlled vocabularies.

    This section makes every material component of a coding runtime an exact,
    revocable profile choice rather than ambient configuration.

    - [ ] 1.2.1 Task {#mcar-p01-profile-contract} [repo: jido_code] [after: {#mcar-p01-runtime-boundary}] - Implement the `ManagedCodingProfile` contract.

      This task binds runtime behavior, authority ceilings, and resource bounds
      into one immutable profile revision.

      - [ ] 1.2.1.1 Subtask - Define profile identity and revisions for Jido, strategy, prompt bundle, model access, context policy, memory policy, tool catalog, adapter set, sandbox, verifier, and candidate schema.
      - [ ] 1.2.1.2 Subtask - Define hard limits for turns, model calls, tokens, tool calls, input/output bytes, wall and idle time, cost, processes, memory, disk, changed files, diff bytes, and clarification rounds.
      - [ ] 1.2.1.3 Subtask - Record each limit's enforcement class (`hard`, `next_effect`, `observed_only`, or `unavailable`) and reject managed profiles with unavailable enforcement for a required safety dimension.
      - [ ] 1.2.1.4 Subtask - Define runtime phases, terminal classifications, model-result kinds, tool-result kinds, retry classes, cancellation states, and candidate-handoff states as closed vocabularies.
      - [ ] 1.2.1.5 Subtask - Require explicit enable, disable, revoke, supersede, rollout-stage, task-class, actor, tenant, repository, and capability bindings for every managed profile.

  - [ ] 1.3 Section - Extend graph accounting for the managed loop.

    This section records enough semantic state to reconstruct the loop without
    serializing Jido strategy internals or raw transcripts.

    - [ ] 1.3.1 Task {#mcar-p01-graph-protocol} [repo: jido_code] [after: {#mcar-p01-profile-contract}] - Add managed coding resources, commands, and completeness rules.

      This task makes loop progress and effect correlation durable through the
      existing semantic-command protocol.

      - [ ] 1.3.1.1 Subtask - Map `ManagedCodingProfile`, `CodingStrategyRevision`, `CodingRuntimeObservation`, `CodingBudgetSnapshot`, `CandidateCompletionProposal`, and any topology specification onto existing graph families or justify a closed-family revision.
      - [ ] 1.3.1.2 Subtask - Define shapes and bounded predicates for attempt, profile, context, invocation, tool, budget, sequence, fence, candidate, cancellation, reconstruction watermark, and terminal classification.
      - [ ] 1.3.1.3 Subtask - Extend attempt start and runtime-event commands to bind exact coding-profile and strategy revisions without persisting raw agent state.
      - [ ] 1.3.1.4 Subtask - Add semantic commands for bounded runtime observations, budget exhaustion, clarification, candidate completion proposal, and candidate handoff where existing commands cannot express them honestly.
      - [ ] 1.3.1.5 Subtask - Extend run finalization so every started context, model, tool, clarification, candidate, cancellation, and recovery activity has exactly one allowed terminal accounting state.

  - [ ] 1.4 Section - Pin Jido compatibility and threat conformance.

    This section proves the selected Jido APIs and security assumptions before
    runtime logic depends on them.

    - [ ] 1.4.1 Task {#mcar-p01-jido-conformance} [repo: jido_code] [after: {#mcar-p01-graph-protocol}] - Build Jido and trust-boundary conformance fixtures.

      This task converts upstream framework semantics and hostile-runtime
      assumptions into project-owned regression tests.

      - [ ] 1.4.1.1 Subtask - Pin and test the exact `Jido.Agent`, strategy, AgentServer, directive execution, signal routing, InstanceManager, partition, and supervision behaviors required by the plan.
      - [ ] 1.4.1.2 Subtask - Prove agent state is immutable command output, directives cannot mutate agent state, duplicated or stale signals are detectable, and strategy snapshots expose no hidden authority.
      - [ ] 1.4.1.3 Subtask - Prove ETS-only loss is supported, hibernate/thaw and alternate Jido persistence are unreachable, and no agent/pod checkpoint can satisfy semantic recovery.
      - [ ] 1.4.1.4 Subtask - Add fixtures for repository prompt injection, tool-argument smuggling, capability drift, stale fences, context substitution, secret exposure, budget exhaustion, and self-verification attempts.
      - [ ] 1.4.1.5 Subtask - Record Jido `2.3.2` compatibility gaps and require explicit evidence before consuming behavior introduced by later Jido patch releases.

  - [ ] 1.5 Section - Phase 1 Integration Tests.

    This final section proves the contract, graph protocol, Jido semantics, and
    disabled posture against a real isolated dataset.

    - [ ] 1.5.1 Task {#mcar-p01-integration} [repo: jido_code] [after: {#mcar-p01-jido-conformance}] - Execute the Phase 1 contract and conformance matrix.

      This task closes MCG1 only when the proposed runtime can be represented,
      validated, recovered, and denied without performing coding effects.

      - [ ] 1.5.1.1 Subtask - Create, enable, revoke, and supersede exact coding profiles through semantic commands and prove unauthorized or incomplete profiles never become selectable.
      - [ ] 1.5.1.2 Subtask - Start and finalize graph attempts with exact profile/strategy pins, complete event accounting, idempotent replay, stale revision rejection, and no serialized runtime internals.
      - [ ] 1.5.1.3 Subtask - Destroy the Jido runtime during every non-effecting phase and prove graph projections yield one deterministic recovery classification.
      - [ ] 1.5.1.4 Subtask - Run the threat fixtures, prior factory/harness/memory suites, architecture checks, Dialyzer, and `mix precommit`.

    - [ ] 1.5.2 Task {#mcar-p01-phase-receipt} [repo: jido_code] [after: {#mcar-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records MCG1 evidence in
      `docs/architecture/managed-coding-phase-01-receipt.md` and authorizes
      Phase 2 only from the pinned merged baseline.

      - [ ] 1.5.2.1 Subtask - Record accepted runtime, profile, graph, command, shape, Jido, strategy, and threat-fixture revisions and digests.
      - [ ] 1.5.2.2 Subtask - Attach contract, compatibility, restart, denial, and disabled-posture evidence with known limitations.
      - [ ] 1.5.2.3 Subtask - Keep MCG1 open if any runtime field has ambiguous ownership, any profile can widen authority, or any Jido state becomes required truth.
      - [ ] 1.5.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 2 and preserve every MCG1 reopening condition.
