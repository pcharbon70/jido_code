---
id: plan.jido_code_secure_effective_agent_harness_phase_01
parent_plan: plan.jido_code_secure_effective_agent_harness
status: planned
intent: feature
---

# Harness Phase 1 - Harness Contract And Threat Model

This phase turns the harness research into executable contracts: graph
resources and shapes, the model/tool invocation command protocol, context
manifest bounds, and the trust and threat model with conformance fixtures,
before any provider call or tool effect exists.

Back to plan: [README](./README.md)

- [x] 1 Phase - Make harness authority and threats executable before model effects.

  This phase proves capability, context, invocation, tool, approval, and
  publication semantics against the accepted graph boundary so unsafe
  behavior never becomes the compatibility baseline.

  - [x] 1.1 Section - Define harness graph resources and access-profile contracts.

    This section maps every proposed harness resource onto the closed
    GraphRegistry with shapes, graph-family write rules, and lifecycle
    semantics, without adding a new graph family.

    - [x] 1.1.1 Task {#sah-p01-graph-resources} [repo: jido_code] - Map harness resources into existing graph families.

      This task gives each harness concept a governed durable home and
      rejects any unmapped term at the validation boundary.

      - [x] 1.1.1.1 Subtask {#sah-p01-1-1-1-1} - Map `ModelAccessProfile`, `HarnessProfile`, and `ToolDefinitionRevision` into `factory/policy` with append, disable, revoke, and supersede writers.
      - [x] 1.1.1.2 Subtask {#sah-p01-1-1-1-2} - Map `ContextManifest`, `ModelInvocation`, `ActionProposal`, delegated-runtime attempt metadata, and `SandboxInstance` into `run/{attempt}` with immutable-after-commit and append-only lifecycle.
      - [x] 1.1.1.3 Subtask {#sah-p01-1-1-1-3} - Map `ApprovalRequest` into `repo/{repo}/control` with append, consume, expire, and supersede writers, reusing existing `Policy`, `VerificationMethod`, and `VerificationActivity` terms where the research names them.
      - [x] 1.1.1.4 Subtask {#sah-p01-1-1-1-4} - Define shapes for every mapped resource covering required types, cardinalities, controlled concepts, IRI scope, provenance, and bounded literals, and register them in the closed vocabulary registry.

    - [x] 1.1.2 Task {#sah-p01-access-profiles} [repo: jido_code] [after: {#sah-p01-graph-resources}] - Define the `ModelAccessProfile` and credential-source contracts.

      This task makes access mode, credential class, billing, readiness, and
      revocation explicit and queryable for every future dispatch.

      - [x] 1.1.2.1 Subtask {#sah-p01-1-1-2-1} - Define the three access modes (`host_api`, `host_subscription`, `delegated_cli`), backend capability negotiation, and per-profile provider, model, endpoint, and modality constraints.
      - [x] 1.1.2.2 Subtask {#sah-p01-1-1-2-2} - Define credential classes (`static_reusable`, `short_lived_bearer`, `workload_exchange`, `attaching_proxy`), external `CredentialReference` linkage, and which audience, scope, actor, expiry, attempt, fence, and single-use restrictions the provider or proxy actually enforces.
      - [x] 1.1.2.3 Subtask {#sah-p01-1-1-2-3} - Define billing classification (`metered_api`, `subscription`, `unknown`), budget-dimension enforcement classes (`hard`, `next_effect`, `observed_only`, `unavailable`), and readiness states with their evidence kinds, including consent-gated live verification.
      - [x] 1.1.2.4 Subtask {#sah-p01-1-1-2-4} - Define revocation generations and the credential-release linearization point so a revocation committed before release yields a recorded no-dispatch outcome and one committed after blocks every later dispatch.
      - [x] 1.1.2.5 Subtask {#sah-p01-1-1-2-5} - Keep initial profiles single-operator and shadow-only, and record the independently authenticated and granted decision-actor prerequisite for any later stage.

  - [x] 1.2 Section - Extend the semantic command protocol for harness invocations.

    This section makes every model and tool interaction a graph-visible,
    sequence-guarded activity before it can occur.

    - [x] 1.2.1 Task {#sah-p01-command-protocol} [repo: jido_code] [after: {#sah-p01-access-profiles}] - Implement the invocation command protocol.

      This task extends the accepted execution protocol without weakening
      its completeness and recovery guarantees.

      - [x] 1.2.1.1 Subtask {#sah-p01-1-2-1-1} - Revise `RecordExecutionAttempt` so the first immutable `ContextManifest` is created atomically with the attempt, prepared and starting transitions, task and lease transitions, and graph metadata, with the attempt's context digest identifying that manifest.
      - [x] 1.2.1.2 Subtask {#sah-p01-1-2-1-2} - Add `RecordModelInvocationStart` to atomically append the started activity and either reference the existing first manifest or create and reference the next immutable manifest when context changed, requiring an open run, current lease and fence, expected revisions and sequence, and all context bounds before provider dispatch.
      - [x] 1.2.1.3 Subtask {#sah-p01-1-2-1-3} - Add `RecordModelInvocationOutcome` and `RecordToolInvocationStart` with shared attempt sequencing, guard-verified predecessors, idempotency identities derived from attempt, snapshot, fence, operation, and sequence, and bounded classified proposal digests instead of raw sensitive arguments.
      - [x] 1.2.1.4 Subtask {#sah-p01-1-2-1-4} - Extend `FinalizeExecutionRun` completeness guards to require the complete manifest and invocation start and outcome reference sets through the terminal sequence.
      - [x] 1.2.1.5 Subtask {#sah-p01-1-2-1-5} - Prove a failed or ambiguous command commit never dispatches until status recovery proves the start was accepted.

  - [x] 1.3 Section - Define context manifest and bounds contracts.

    This section pins exactly what the model is told, from which revisions,
    and within which limits, for both host-controlled and delegated runs.

    - [x] 1.3.1 Task {#sah-p01-manifests} [repo: jido_code] [after: {#sah-p01-command-protocol}] - Implement host and delegated manifest contracts.

      This task makes context attributable, bounded, and honest about what
      cannot be reconstructed.

      - [x] 1.3.1.1 Subtask {#sah-p01-1-3-1-1} - Define the host `ContextManifest` content contract: attempt, lease, goal, task, and enrollment IRIs; profile, backend mode, authentication kind, and billing classification; repository, branch policy, base commit, and source snapshot; and every ontology, query, policy, workflow, prompt, model, adapter, CLI, and tool revision.
      - [x] 1.3.1.2 Subtask {#sah-p01-1-3-1-2} - Define the delegated-input manifest with provider-internal prompts, context assembly, memory, internal model turns, and tool manifests explicitly marked `unavailable` rather than inferred.
      - [x] 1.3.1.3 Subtask {#sah-p01-1-3-1-3} - Enforce the accepted manifest bounds (at most 20 source graphs and 200 items, 262,144 serialized bytes, 65,536 estimated tokens, 16,384-byte instructions, 32,768-byte source items) and command bounds (16 target graphs, 1,000 effective additions), recording truncation, omissions, measurement method, and each retained reference.
      - [x] 1.3.1.4 Subtask {#sah-p01-1-3-1-4} - Define reconstruction status (`exact`, `partial`, `unavailable`) with missing-class reporting so a digest alone never implies replayability under the privacy contract.

  - [x] 1.4 Section - Define the trust model and threat fixtures.

    This section classifies every information-flow edge and proves the
    core security invariants with executable fixtures.

    - [x] 1.4.1 Task {#sah-p01-trust-model} [repo: jido_code] [after: {#sah-p01-manifests}] - Implement trust labels, information-flow rules, and conformance fixtures.

      This task makes the untrusted-data invariant mechanically testable
      before any provider or tool integration exists.

      - [x] 1.4.1.1 Subtask {#sah-p01-1-4-1-1} - Define the source-to-integrity classification (accepted policy, operator command, provider observation, repository content, model output, tool output, verifier result, authorized decision) and the allowed-flow rules that untrusted data cannot create authority, enlarge capability, choose sinks, declassify, modify policy, or enter accepted memory without mediation.
      - [x] 1.4.1.2 Subtask {#sah-p01-1-4-1-2} - Map runtime diagnostics onto the accepted attempt lifecycle only, and define any new dead-runtime recovery condition as a versioned protocol change rather than an invented terminal state.
      - [x] 1.4.1.3 Subtask {#sah-p01-1-4-1-3} - Build conformance fixtures for authorization denial, stale-fence rejection, idempotent replay, and indirect prompt injection, covering both task utility and security outcome.
      - [x] 1.4.1.4 Subtask {#sah-p01-1-4-1-4} - Wire the fixtures into `mix precommit` so every later phase inherits them as regression gates.

  - [x] 1.5 Section - Phase 1 Integration Tests.

    This final section proves the contract layer holds against the real
    store and closes the phase with its receipt.

    - [x] 1.5.1 Task {#sah-p01-integration} [repo: jido_code] [after: {#sah-p01-trust-model}] - Execute the Phase 1 contract and conformance suite.

      This task proves schema, protocol, manifest, and trust behavior on an
      actual dataset before any gateway is authorized.

      - [x] 1.5.1.1 Subtask {#sah-p01-1-5-1-1} - Prove every mapped resource round-trips through its owning command, obeys its shapes and family write rules, and is rejected from any other family or writer.
      - [x] 1.5.1.2 Subtask {#sah-p01-1-5-1-2} - Prove atomic manifest-with-attempt creation, sequence-guarded invocation starts and outcomes, idempotent replay, stale-guard rejection, and finalize completeness enforcement including the incomplete-run path.
      - [x] 1.5.1.3 Subtask {#sah-p01-1-5-1-3} - Prove manifest bound enforcement at and beyond every accepted limit with recorded truncation and omission metadata.
      - [x] 1.5.1.4 Subtask {#sah-p01-1-5-1-4} - Run the trust-model fixtures, prior-plan regression suites, architecture scans, and `mix precommit`.

    - [x] 1.5.2 Task {#sah-p01-phase-receipt} [repo: jido_code] [after: {#sah-p01-integration}] - Publish the Phase 1 harness-contract receipt.

      This task records the contract evidence in
      `docs/architecture/harness-phase-01-receipt.md` and authorizes Phase 2
      only from the pinned merged baseline.

      - [x] 1.5.2.1 Subtask {#sah-p01-1-5-2-1} - Record resource mappings, shape digests, command-protocol revisions, manifest bounds, and the candidate commit.
      - [x] 1.5.2.2 Subtask {#sah-p01-1-5-2-2} - Attach contract, sequence, bound, and trust-fixture results with known limitations.
      - [x] 1.5.2.3 Subtask {#sah-p01-1-5-2-3} - Keep HG1 blocked while any mapped resource lacks a shape, any invocation can bypass its command, or any untrusted fixture gains authority.
      - [x] 1.5.2.4 Subtask {#sah-p01-1-5-2-4} - Pin the merged candidate commit before authorizing Phase 2.
