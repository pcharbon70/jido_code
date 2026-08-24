---
id: plan.jido_code_managed_coding_agent_runtime_phase_02
parent_plan: plan.jido_code_managed_coding_agent_runtime
status: planned
intent: feature
---

# Managed Coding Phase 2 - Governed Coding Tools And Workspace Effects

This phase turns the existing closed tool catalog into a real, isolated coding
effect plane. It implements exact source reads, digest-guarded workspace
mutations, registered checks, candidate inspection and capture, and complete
invocation accounting before a model-driven loop may use them.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Implement the complete mediated tool plane for one disposable coding workspace.

  This phase proves MCG2 by ensuring every coding effect has a concrete adapter,
  closed schema, current authorization, exact effect identity, bounded result,
  and independently recoverable outcome.

  - [x] 2.1 Section - Establish the isolated workspace contract.

    This section creates the only filesystem boundary in which managed coding
    tools may operate.

    - [x] 2.1.1 Task {#mcar-p02-workspace} [repo: jido_code] [after: {#mcar-p01-phase-receipt}] - Implement managed coding workspace provisioning and identity.

      This task binds one disposable workspace to an exact snapshot, attempt,
      lease, fence, sandbox profile, and cleanup policy.

      - [x] 2.1.1.1 Subtask - Provision a fresh isolated worktree from the exact verified source snapshot with no unrelated repository, Git credential, SSH agent, Docker socket, host home, or store access.
      - [x] 2.1.1.2 Subtask - Define canonical workspace, base-tree, current-tree, parent-directory, candidate-diff, and cleanup digests with deterministic normalization.
      - [x] 2.1.1.3 Subtask - Extend the repository path guard to reject absolute paths, traversal, symlink escapes, special files, case/Unicode ambiguity, and paths outside authorized scopes.
      - [x] 2.1.1.4 Subtask - Enforce file-count, byte, disk, process, memory, wall, idle, and changed-path ceilings at the sandbox boundary.
      - [x] 2.1.1.5 Subtask - Define cleanup, quarantine, hold, cancellation, crash, and candidate-retention behavior without making workspace survival part of recovery truth.

  - [x] 2.2 Section - Implement source discovery and exact reads.

    This section gives the runtime useful repository inspection without raw
    shell access or unbounded source disclosure.

    - [x] 2.2.1 Task {#mcar-p02-read-tools} [repo: jido_code] [after: {#mcar-p02-workspace}] - Implement closed source-search, symbol-inspection, and file-read adapters.

      This task makes every read revision-pinned, scope-safe, attributable, and
      bounded before it reaches model context.

      - [x] 2.2.1.1 Subtask - Implement `search_source` over the accepted source index with exact repository/snapshot scope, deterministic ranking, result count, byte limits, omissions, and no arbitrary SPARQL.
      - [x] 2.2.1.2 Subtask - Implement `inspect_symbol` from reviewed source queries with exact analysis revision, uncertainty, source spans, truncation, and current-snapshot validation.
      - [x] 2.2.1.3 Subtask - Implement `read_file` with canonical path, expected digest, byte/range bounds, binary/encoding classification, content policy, and explicit unavailable/truncated outcomes.
      - [x] 2.2.1.4 Subtask - Treat repository text and tool output as untrusted data, apply secret and forbidden-content scanning, and prevent returned content from altering tool schemas or authority metadata.
      - [x] 2.2.1.5 Subtask - Add deterministic pagination or continuation handles that cannot widen repository, path, classification, snapshot, or actor scope.

  - [x] 2.3 Section - Implement digest-guarded workspace mutation.

    This section provides the minimal write tools needed for coding while
    rejecting ambiguous or stale edits.

    - [x] 2.3.1 Task {#mcar-p02-write-tools} [repo: jido_code] [after: {#mcar-p02-read-tools}] - Implement apply, create, and delete adapters.

      This task makes every file mutation explicit, reversible where possible,
      and protected by snapshot, digest, path, capability, and fence checks.

      - [x] 2.3.1.1 Subtask - Implement `apply_edit` as one exact-match replacement with expected file digest, expected match count of one, encoding preservation, output-size checks, and a new digest receipt.
      - [x] 2.3.1.2 Subtask - Implement `create_file` with target-absent, parent-authorized, expected parent digest, classification, byte, path, and file-mode constraints and no overwrite fallback.
      - [x] 2.3.1.3 Subtask - Implement `delete_file` with exact target digest, allowed-file-type checks, protected-path denial, and a recoverable candidate-diff record.
      - [x] 2.3.1.4 Subtask - Revalidate lease, fence, workspace identity, current digest, capability, and policy immediately before each filesystem effect and reject late or raced operations.
      - [x] 2.3.1.5 Subtask - Assign deterministic effect identities and reconcile filesystem state before retry so a timeout or process loss cannot double-apply a mutation.

  - [x] 2.4 Section - Implement registered checks and candidate artifacts.

    This section lets the runtime test and package work without arbitrary
    commands or publication authority.

    - [x] 2.4.1 Task {#mcar-p02-check-candidate-tools} [repo: jido_code] [after: {#mcar-p02-write-tools}] - Implement check, diff, and candidate-capture adapters.

      This task turns workspace results into bounded observations and immutable
      candidate artifacts suitable for independent verification.

      - [x] 2.4.1.1 Subtask - Implement `run_registered_check` from a server-owned catalog with fixed executable/arguments, image/toolchain digest, cwd, environment, egress, timeout, output, resource, and retry policy.
      - [x] 2.4.1.2 Subtask - Classify check success, failure, timeout, cancellation, infrastructure failure, flake suspicion, truncation, and unavailable evidence without letting the agent relabel outcomes.
      - [x] 2.4.1.3 Subtask - Implement `show_candidate_diff` with stable ordering, binary/large-file summaries, secret scanning, byte limits, exact base/current digests, and explicit omissions.
      - [x] 2.4.1.4 Subtask - Implement candidate capture with immutable patch/artifact digest, base snapshot, changed paths, file modes, submodule state, workspace digest, toolchain/profile revisions, and no publication side effect.
      - [x] 2.4.1.5 Subtask - Keep governed commands, network effects, candidate publication, protected-branch writes, and merge outside the ordinary coder tool capability.

  - [x] 2.5 Section - Wire complete mediation and effect accounting.

    This section connects every adapter to the reference monitor, tool ledger,
    semantic commands, and late-result guards.

    - [x] 2.5.1 Task {#mcar-p02-tool-gateway} [repo: jido_code] [after: {#mcar-p02-check-candidate-tools}] - Integrate production adapters through `ToolGateway`.

      This task eliminates catalog-only tools and proves no managed effect can
      bypass invocation-before-effect accounting.

      - [x] 2.5.1.1 Subtask - Register each adapter module and digest against exactly one tool definition revision and fail closed on missing, substituted, or multiply registered adapters.
      - [x] 2.5.1.2 Subtask - Commit tool proposal and invocation start before effect dispatch, recover ambiguous command commits, and record exactly one bounded terminal outcome afterward.
      - [x] 2.5.1.3 Subtask - Revalidate policy and claim the effect sink at the linearization point, returning replay receipts for already completed identities and denying stale fences.
      - [x] 2.5.1.4 Subtask - Bound and classify diagnostics so paths, source content, secrets, backend errors, and sandbox internals cannot leak through graph events or model results.
      - [x] 2.5.1.5 Subtask - Add architecture checks proving managed runtime code reaches effects only through the Factory tool port and registered adapters.

  - [ ] 2.6 Section - Phase 2 Integration Tests.

    This final section proves real source, filesystem, sandbox, check, and
    candidate effects under the complete mediation boundary.

    - [x] 2.6.1 Task {#mcar-p02-integration} [repo: jido_code] [after: {#mcar-p02-tool-gateway}] - Execute the governed tool and workspace matrix.

      This task closes MCG2 only when every catalogued initial tool performs its
      real effect safely and recoverably.

      - [x] 2.6.1.1 Subtask - Exercise source search, symbol inspection, file reads, edits, creates, deletes, checks, diff rendering, and candidate capture against isolated real Git worktrees.
      - [x] 2.6.1.2 Subtask - Inject traversal, symlink, stale digest, stale fence, duplicate effect, oversized input/output, secret, binary, race, process loss, timeout, and ambiguous-result cases.
      - [x] 2.6.1.3 Subtask - Prove cancellation and cleanup remove or quarantine disposable state without losing the graph's ability to identify completed and unresolved effects.
      - [x] 2.6.1.4 Subtask - Rerun MCG1, harness tool/sandbox/security suites, architecture checks, Dialyzer, and `mix precommit`.

    - [ ] 2.6.2 Task {#mcar-p02-phase-receipt} [repo: jido_code] [after: {#mcar-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records MCG2 evidence in
      `docs/architecture/managed-coding-phase-02-receipt.md` and authorizes
      Phase 3 only from the pinned merged baseline.

      - [x] 2.6.2.1 Subtask - Record workspace, adapter, tool catalog, registered check, sandbox, effect identity, and candidate schema revisions and digests.
      - [x] 2.6.2.2 Subtask - Attach real-worktree, mutation, check, candidate, race, cancellation, and cleanup evidence with known limitations.
      - [x] 2.6.2.3 Subtask - Keep MCG2 open while any enabled tool lacks a concrete adapter, any effect bypass exists, or any retry can duplicate a write.
      - [ ] 2.6.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 3 and preserve every MCG1-MCG2 reopening condition.
