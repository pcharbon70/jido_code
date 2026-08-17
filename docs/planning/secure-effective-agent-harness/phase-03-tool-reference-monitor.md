---
id: plan.jido_code_secure_effective_agent_harness_phase_03
parent_plan: plan.jido_code_secure_effective_agent_harness
status: planned
intent: feature
---

# Harness Phase 3 - Tool Reference Monitor

This phase builds the closed tool catalog and the capability-enforcing tool
gateway so every host-controlled effect is closed-validated, authorized,
committed before dispatch, recorded after, and fence-checked.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Make the tool boundary both the agent interface and the security boundary.

  This phase gives the model small, typed, immediate-feedback tools while
  keeping complete mediation of every effect in deterministic code.

  - [x] 3.1 Section - Implement the closed tool catalog and input validation.

    This section makes the model-facing interface a versioned, reviewed,
    schema-enforced collection rather than an open API.

    - [x] 3.1.1 Task {#sah-p03-tool-catalog} [repo: jido_code] [after: {#sah-p02-phase-receipt}] - Publish the versioned tool catalog.

      This task pins every tool contract, effect class, and supply-chain
      identity before any tool is executable.

      - [x] 3.1.1.1 Subtask {#sah-p03-3-1-1-1} - Define the initial model-facing tool set (`search_source`, `inspect_symbol`, `read_file`, `apply_edit`, `create_file`, `delete_file`, `run_registered_check`, `run_governed_command`, `show_candidate_diff`, `submit_candidate`, `request_clarification`) with stable names, versions, and input/output schema digests.
      - [x] 3.1.1.2 Subtask {#sah-p03-3-1-1-2} - Record capability and effect class, preconditions and expected revisions, side effects and reversibility, timeout, retry and idempotency policy, maximum output size, approval requirements, adapter identity and supply-chain digest, and safe error vocabulary for every tool.
      - [x] 3.1.1.3 Subtask {#sah-p03-3-1-1-3} - Implement closed structural and semantic validation rejecting unknown properties, path traversal, absolute paths, ambiguous replacements, unauthorized refs, unapproved destinations, and scope-expanding arguments before any effect.
      - [x] 3.1.1.4 Subtask {#sah-p03-3-1-1-4} - Keep raw shell access a separate high-risk capability; routine work uses registered commands whose executable, working directory, arguments, environment, network policy, and resource limits are server-owned.

  - [x] 3.2 Section - Implement action proposals and deterministic authorization.

    This section converts model output into governed proposals and derives
    attenuated capabilities deterministically.

    - [x] 3.2.1 Task {#sah-p03-action-proposals} [repo: jido_code] [after: {#sah-p03-tool-catalog}] - Convert directives into authorized action proposals.

      This task ensures a directive is never authority by itself and every
      capability shrinks from the lease outward.

      - [x] 3.2.1.1 Subtask {#sah-p03-3-2-1-1} - Convert Jido directives and model tool calls into normalized `ActionProposal` resources carrying bounded classified digests and references, never raw secret-bearing arguments.
      - [x] 3.2.1.2 Subtask {#sah-p03-3-2-1-2} - Implement the policy governor deriving the attempt capability set from lease, task, repository policy, actor, and data classification: scope, profile, model and versions, snapshot and graph revisions, permitted tools, filesystem paths and refs, graph scopes, network destinations and data classes, resource ceilings, credential references, expiry, fencing token, and idempotency namespace.
      - [x] 3.2.1.3 Subtask {#sah-p03-3-2-1-3} - Keep execution capabilities free of decision, acceptance, ontology, security-policy, durable-memory, verification, and publication authority.
      - [x] 3.2.1.4 Subtask {#sah-p03-3-2-1-4} - Revalidate current policy, revisions, capability, and fence immediately before every effect; a race-time denial after an admitted start becomes an authorized no-effect outcome.

  - [x] 3.3 Section - Implement invocation-before-effect commits.

    This section records why each start was admitted and every bounded
    outcome through the accepted Knowledge facade.

    - [x] 3.3.1 Task {#sah-p03-invocation-commit} [repo: jido_code] [after: {#sah-p03-action-proposals}] - Commit starts and outcomes around every effect.

      This task makes authorization provenance durable without becoming
      reusable effect authority.

      - [x] 3.3.1.1 Subtask {#sah-p03-3-3-1-1} - Atomically write the bounded classified proposal digest, started invocation, command authorization provenance, and audit in one commit through `RecordToolInvocationStart` and the accepted writer.
      - [x] 3.3.1.2 Subtask {#sah-p03-3-3-1-2} - Record the bounded outcome through the same facade after the effect, with digests and status, and never persist raw secret-bearing arguments.
      - [x] 3.3.1.3 Subtask {#sah-p03-3-3-1-3} - Keep pre-admission rejections as the accepted concealed transient receipt unless a separate bounded rejection-audit protocol is later accepted.
      - [x] 3.3.1.4 Subtask {#sah-p03-3-3-1-4} - Prove persisted authorization explains the start decision but can never substitute for the immediate pre-effect revalidation.

  - [x] 3.4 Section - Enforce fencing and idempotency at every sink.

    This section rejects stale tokens and duplicate effects at the boundaries
    JidoCode owns.

    - [x] 3.4.1 Task {#sah-p03-fencing-sinks} [repo: jido_code] [after: {#sah-p03-invocation-commit}] - Enforce stale-fence and idempotency rejection.

      This task closes the time-of-check to time-of-use window at every
      lease-governed sink.

      - [x] 3.4.1.1 Subtask {#sah-p03-3-4-1-1} - Require fencing checks before every graph command, sandbox mutation, tool execution, Git or provider write, artifact publication, and execution outcome; sinks receive and reject stale monotonic tokens.
      - [x] 3.4.1.2 Subtask {#sah-p03-3-4-1-2} - Derive idempotency identities from attempt, snapshot, fence, operation, and sequence so retries cannot duplicate effects.
      - [x] 3.4.1.3 Subtask {#sah-p03-3-4-1-3} - Accept stable effect IDs from external mutation adapters, reconcile ambiguous results before retry, and create new linked attempts for semantic retries rather than overwriting history.
      - [x] 3.4.1.4 Subtask {#sah-p03-3-4-1-4} - Keep model calls honestly at-least-once: record ambiguous outcomes when a response is irretrievable and permit only one recovered result to advance the workflow under an expected-revision transition.

  - [ ] 3.5 Section - Phase 3 Integration Tests.

    This final section proves complete mediation under race, replay, and
    hostile-input conditions.

    - [ ] 3.5.1 Task {#sah-p03-integration} [repo: jido_code] [after: {#sah-p03-fencing-sinks}] - Execute the reference-monitor matrices.

      This task certifies the tool boundary before production sandboxes are
      authorized.

      - [ ] 3.5.1.1 Subtask {#sah-p03-3-5-1-1} - Prove every catalog tool validates closed schemas, rejects malformed and scope-expanding arguments without an effect, and returns its safe error vocabulary.
      - [ ] 3.5.1.2 Subtask {#sah-p03-3-5-1-2} - Race authorization revocation, lease expiry, and fence supersession against effect dispatch; prove 100 percent stale-token rejection and no-effect outcomes for race-time denials.
      - [ ] 3.5.1.3 Subtask {#sah-p03-3-5-1-3} - Replay idempotent starts and outcomes, kill processes between commit and effect, and prove no duplicate effects and exactly one terminal outcome.
      - [ ] 3.5.1.4 Subtask {#sah-p03-3-5-1-4} - Run hostile-input fixtures (path traversal, symlink, shell injection, unauthorized destinations) plus prior suites, architecture scans, and `mix precommit`.

    - [ ] 3.5.2 Task {#sah-p03-phase-receipt} [repo: jido_code] [after: {#sah-p03-integration}] - Publish the Phase 3 tool-monitor receipt.

      This task records the mediation evidence in
      `docs/architecture/harness-phase-03-receipt.md` and authorizes Phase 4
      only from the pinned merged baseline.

      - [ ] 3.5.2.1 Subtask {#sah-p03-3-5-2-1} - Record catalog versions and schema digests, capability derivation rules, sink inventory with fence checks, and the candidate commit.
      - [ ] 3.5.2.2 Subtask {#sah-p03-3-5-2-2} - Attach validation, race, replay, and hostile-input results with known limitations.
      - [ ] 3.5.2.3 Subtask {#sah-p03-3-5-2-3} - Keep HG3 blocked while any host-controlled effect can bypass the monitor, any sink accepts a stale fence, or any proposal shape stays open.
      - [ ] 3.5.2.4 Subtask {#sah-p03-3-5-2-4} - Pin the merged candidate commit before authorizing Phase 4.
