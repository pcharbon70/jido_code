---
id: plan.jido_code_delegated_coding_agents_phase_02
parent_plan: plan.jido_code_delegated_coding_agents
status: approved
intent: feature
---

# Delegated Coding Agents Phase 2 - Exact Codex Runtime And Protected JidoHarness Launch

This phase preserves JidoHarness as the process controller and Codex as the
coding agent while replacing the unsafe built-in argument construction with a
closed JidoCode launch policy.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Implement one exact Codex runtime behind the existing execution facade.

  This phase proves DCG2 by running a revision-pinned Codex process through the
  protected JidoHarness Process API with protected context transport, bounded
  interactions, exact event adoption, and process-tree cancellation.

  - [x] 2.1 Section - Define the adapter release, runtime profile, and resolver.

    This section ensures graph data selects reviewed keys and digests, never
    executable paths, modules, arguments, or provider options.

    - [x] 2.1.1 Task {#dca-p02-release} [repo: jido_code] [after: {#dca-p01-phase-receipt}] - Register the initial Codex adapter and profile candidates.

      This task pins every component needed to reproduce one DGA1 run while
      leaving the profile disabled.

      - [x] 2.1.1.1 Subtask - Pin JidoHarness revision `e41fc1651282469f2db4219a48d9f7feef1b0dbc` and its accepted source archive digest.
      - [x] 2.1.1.2 Subtask - Pin Codex CLI `0.144.6`, model `gpt-5.3-codex`, JSONL protocol, executable digest, and controller-owned output schema.
      - [x] 2.1.1.3 Subtask - Define the `developer_local`, `jido_code`, `workspace_write_registered_checks` profile as disabled until DCG3-DCG6 close.
      - [x] 2.1.1.4 Subtask - Add runtime and adapter fields to managed-coding release contract `8.0.0` while retaining the accepted native profile and historical `7.0.0` interpretation.

    - [x] 2.1.2 Task {#dca-p02-resolver} [repo: jido_code] [after: {#dca-p02-release}] - Implement closed runtime and executable resolution.

      This task prevents RDF, task input, repository content, and caller input
      from selecting code or launch flags.

      - [x] 2.1.2.1 Subtask - Map accepted runtime, adapter, and executable registry keys to compiled modules and exact absolute executable paths.
      - [x] 2.1.2.2 Subtask - Verify executable ownership, regular-file type, digest, version, and approved installation root before `prepare` succeeds.
      - [x] 2.1.2.3 Subtask - Reject unknown, changed, symlinked, writable, out-of-registry, or version-incompatible executables and adapters.
      - [x] 2.1.2.4 Subtask - Preserve `JidoCode.Factory.Ports.ExecutionRuntime` and reauthorize `prepare`, `start`, `signal`, `status`, `cancel`, and `terminate` before dispatch.

  - [x] 2.2 Section - Implement the protected Codex process runner.

    This section launches Codex through JidoHarness without leaking compiled
    context through process arguments, environment, or ambient configuration.

    - [x] 2.2.1 Task {#dca-p02-runner} [repo: jido_code] [after: {#dca-p02-resolver}] - Add the JidoCode-owned Codex runner.

      This task retains the pinned JidoHarness lifecycle and Codex JSONL
      semantics while enforcing a fixed launch envelope.

      - [x] 2.2.1.1 Subtask - Construct a fixed launch equivalent to `codex exec --json --ephemeral --ignore-user-config --ignore-rules --strict-config --model gpt-5.3-codex --sandbox workspace-write --output-schema <controller-owned-file> -`.
      - [x] 2.2.1.2 Subtask - Send the bounded compiled task/context manifest through stdin, close the prompt stream correctly, and prove prompt absence from argv, environment, metadata, diagnostics, and process titles.
      - [x] 2.2.1.3 Subtask - Forbid `--add-dir`, unrestricted sandboxing, arbitrary configuration, MCP, skills, project rules, web search, dangerous bypass flags, caller-provided environment, and caller-provided endpoints.
      - [x] 2.2.1.4 Subtask - Reuse the pinned JidoHarness managed-process lifecycle and normalized Codex JSONL mappings without enabling the upstream built-in adapter.
      - [x] 2.2.1.5 Subtask - Classify the controller-enforced final output as candidate, clarification, checkpoint, or failure and treat all CLI file and check claims as observations.

  - [x] 2.3 Section - Implement bounded turns, steering, clarification, and cancellation.

    This section supports developer interaction without relying on provider
    sessions as durable state or accepting unsupported live stdin semantics.

    - [x] 2.3.1 Task {#dca-p02-turns} [repo: jido_code] [after: {#dca-p02-runner}] - Implement controller-reconstructed Codex turns.

      This task provides one initial turn and one bounded follow-up turn while
      keeping provider-session resume disabled.

      - [x] 2.3.1.1 Subtask - Declare `controller_reconstructed_turns` as the DGA1 session protocol with hard `run_count=2` and `session_turns=2`.
      - [x] 2.3.1.2 Subtask - Transition a clarification or checkpoint result to `awaiting_actor`; validate `answer` or `steer`, create a new delegated-input manifest, and launch a fresh Codex process in the same fenced workspace.
      - [x] 2.3.1.3 Subtask - Allow steering only at an accepted turn boundary, return a state conflict while Codex is actively running, and keep cancellation available.
      - [x] 2.3.1.4 Subtask - Account each turn as a separate outer invocation under the same attempt, lease, fence, profile, workspace, and total budgets.
      - [x] 2.3.1.5 Subtask - Commit cancellation before JidoHarness cancellation and independent process-namespace termination and reject every late event or result.

  - [ ] 2.4 Section - Phase 2 Integration Tests.

    This final section proves exact launch behavior, protected context
    transport, bounded interactions, event normalization, and process
    containment.

    - [ ] 2.4.1 Task {#dca-p02-integration} [repo: jido_code] [after: {#dca-p02-turns}] - Execute the Codex runtime conformance matrix.

      This task closes DCG2 only when the real JidoHarness process path
      satisfies the accepted Codex launch contract.

      - [x] 2.4.1.1 Subtask - Inspect spawned process arguments, environments, metadata, diagnostics, and process titles with prompt, memory, repository, and credential canaries.
      - [x] 2.4.1.2 Subtask - Test positive JSONL streams plus malformed, oversized, partial, duplicate, out-of-order, secret-bearing, and unknown events.
      - [x] 2.4.1.3 Subtask - Test clarification, follow-up steering, turn exhaustion, cooperative cancellation, stalled processes, resistant descendants, timeouts, and late output.
      - [x] 2.4.1.4 Subtask - Prove the upstream built-in Codex adapter, arbitrary flags, user configuration, provider-session resume, and unsafe sandbox modes remain unreachable.
      - [ ] 2.4.1.5 Subtask - Rerun DCG1, harness compatibility, architecture checks, Dialyzer, `mix precommit`, and clean-checkout CI.

    - [ ] 2.4.2 Task {#dca-p02-phase-receipt} [repo: jido_code] [after: {#dca-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records DCG2 evidence in
      `docs/architecture/delegated-agent-phase-02-receipt.md`.

      - [x] 2.4.2.1 Subtask - Record adapter, JidoHarness, Codex, model, executable, output-schema, runner, session-protocol, and event-mapper revisions and digests.
      - [x] 2.4.2.2 Subtask - Keep DCG2 open if context enters argv, arbitrary configuration is reachable, runtime selection can fall back, or cancellation leaves descendants.
      - [ ] 2.4.2.3 Subtask - Attach launch, prompt privacy, event, interaction, cancellation, architecture, Dialyzer, precommit, and clean-checkout evidence.
      - [ ] 2.4.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, integration, receipt, and pinning checkboxes before authorizing Phase 3.
