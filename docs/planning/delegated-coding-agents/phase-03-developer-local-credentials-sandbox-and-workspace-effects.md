---
id: plan.jido_code_delegated_coding_agents_phase_03
parent_plan: plan.jido_code_delegated_coding_agents
status: approved
intent: feature
---

# Delegated Coding Agents Phase 3 - Developer-Local Credentials, Sandbox, And Workspace Effects

This phase connects an existing Codex login to an isolated disposable
workspace without exposing graph, host, repository-publication, or merge
authority.

Back to plan: [README](./README.md)

- [x] 3 Phase - Prove the write-capable Codex process is locally authenticated and contained.

  This phase proves DCG3 by combining expiring readiness, explicit consent,
  protected local authentication, a disposable workspace, registered checks,
  independent resource limits, and complete cleanup.

  - [x] 3.1 Section - Implement readiness, consent, and local credential references.

    This section treats installation and login signals as expiring
    observations rather than authorization.

    - [x] 3.1.1 Task {#dca-p03-readiness} [repo: jido_code] [after: {#dca-p02-phase-receipt}] - Implement non-billable Codex readiness discovery.

      This task verifies the exact profile tuple without sending a
      prompt-bearing provider request.

      - [x] 3.1.1.1 Subtask - Check executable digest and `codex --version` against the accepted adapter release.
      - [x] 3.1.1.2 Subtask - Check bounded Codex login status without claiming the provider identity equals the JidoCode actor.
      - [x] 3.1.1.3 Subtask - Verify worker, sandbox image, network broker, candidate capture, check registry, and independent verifier readiness.
      - [x] 3.1.1.4 Subtask - Bind readiness expiry to adapter, CLI, credential generation, sandbox, network, verifier, and policy drift.

    - [x] 3.1.2 Task {#dca-p03-consent} [repo: jido_code] [after: {#dca-p03-readiness}] - Enforce foreground consent and billing acknowledgement.

      This task prevents silent subscription use, reusable credential release,
      or background scheduling.

      - [x] 3.1.2.1 Subtask - Require authenticated actor consent for the exact profile, repository, task, expiry, and billing classification.
      - [x] 3.1.2.2 Subtask - Require separate consent for every billable live smoke or qualification run.
      - [x] 3.1.2.3 Subtask - Record only opaque local-login references and current revocation generations in the graph.
      - [x] 3.1.2.4 Subtask - Reject managed eligibility, reusable credential export, background dispatch, expired consent, changed billing terms, and actor or repository mismatch.

  - [x] 3.2 Section - Isolate the Codex login and process namespace.

    This section exposes the narrowest usable login reference to Codex while
    preventing repository-controlled tool descendants from reading, copying,
    refreshing, or reusing it.

    - [x] 3.2.1 Task {#dca-p03-isolation} [repo: jido_code] [after: {#dca-p03-consent}] - Implement the trusted local Codex connector.

      This task attaches the existing local login only inside the accepted
      developer-local worker.

      - [x] 3.2.1.1 Subtask - Resolve the approved login file or session through the credential broker without storing token bytes in graph state.
      - [x] 3.2.1.2 Subtask - Attach the credential read-only outside the workspace, with the Codex parent able to authenticate and sandboxed tool descendants denied access.
      - [x] 3.2.1.3 Subtask - Use environment replacement with only fixed non-secret paths and required runtime values; exclude host home, SSH agent, Docker socket, arbitrary configuration, and publication credentials.
      - [x] 3.2.1.4 Subtask - Permit only brokered OpenAI provider egress and deny arbitrary network access to shell commands and repository content.
      - [x] 3.2.1.5 Subtask - Revoke the permit and destroy the credential attachment on cancellation, expiry, supersession, termination, or worker loss.

  - [x] 3.3 Section - Enable bounded workspace writes and registered checks.

    This section gives Codex a useful editing environment while keeping
    authoritative effects and evidence controller-owned.

    - [x] 3.3.1 Task {#dca-p03-workspace} [repo: jido_code] [after: {#dca-p03-isolation}] - Materialize the exact disposable `jido_code` workspace.

      This task limits Codex changes to one admitted source snapshot under
      independently enforced resource and path controls.

      - [x] 3.3.1.1 Subtask - Create a copy-on-write worktree at the exact admitted revision under an unprivileged identity.
      - [x] 3.3.1.2 Subtask - Protect `.git` control data, refs, external directories, sockets, devices, special files, unrelated repositories, and host paths.
      - [x] 3.3.1.3 Subtask - Enforce path, symlink, file-count, patch-size, disk, process, memory, output, idle, wall-time, and egress limits independently of Codex reporting.
      - [x] 3.3.1.4 Subtask - Quarantine the workspace immediately on an out-of-scope path, special file, symlink escape, secret finding, or limit breach.

    - [x] 3.3.2 Task {#dca-p03-checks} [repo: jido_code] [after: {#dca-p03-workspace}] - Run registered checks through the Factory boundary.

      This task prevents Codex-reported commands from becoming authoritative
      verification evidence.

      - [x] 3.3.2.1 Subtask - Allow the opaque Codex loop to run its own sandboxed commands while labeling their events untrusted observations.
      - [x] 3.3.2.2 Subtask - Select authoritative checks only from the existing Factory check registry and run them after each completed turn or handoff.
      - [x] 3.3.2.3 Subtask - Bind check receipts to attempt, fence, source, workspace, profile, command, limits, exit status, and bounded output digest.
      - [x] 3.3.2.4 Subtask - Prevent repository content, task input, or Codex output from adding or changing registered commands.

  - [x] 3.4 Section - Phase 3 Integration Tests.

    This final section proves credential privacy, process isolation, local
    filesystem effects, controller-owned checks, and bounded cleanup.

    - [x] 3.4.1 Task {#dca-p03-integration} [repo: jido_code] [after: {#dca-p03-checks}] - Execute the developer-local security and workspace matrix.

      This task closes DCG3 only when the real write-capable profile remains
      contained under hostile repository and process behavior.

      - [x] 3.4.1.1 Subtask - Exercise installation, login, readiness expiry, consent, billing, revocation, and non-billable discovery paths.
      - [x] 3.4.1.2 Subtask - Run credential, prompt, journal, host-path, cross-actor, and cross-repository canaries from the Codex parent and spawned tool descendants.
      - [x] 3.4.1.3 Subtask - Exercise real file creation, modification, deletion, registered checks, and workspace destruction in isolated temporary workers.
      - [x] 3.4.1.4 Subtask - Attack symlinks, special files, `.git`, egress, process count, output, disk, memory, time, and resistant descendants.
      - [x] 3.4.1.5 Subtask - Rerun DCG1-DCG2, sandbox and harness suites, architecture checks, Dialyzer, `mix precommit`, and clean-checkout CI.

    - [x] 3.4.2 Task {#dca-p03-phase-receipt} [repo: jido_code] [after: {#dca-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records DCG3 evidence in
      `docs/architecture/delegated-agent-phase-03-receipt.md`.

      - [x] 3.4.2.1 Subtask - Record credential, consent, readiness, worker, sandbox, network, workspace, limits, check-registry, and cleanup revisions and digests.
      - [x] 3.4.2.2 Subtask - Keep DCG3 open if a tool descendant can read or reuse the login, escape the workspace, broaden egress, or create an unaccounted effect.
      - [x] 3.4.2.3 Subtask - Attach credential-canary, isolation, workspace, registered-check, resource, cancellation, architecture, Dialyzer, precommit, and clean-checkout evidence.
      - [x] 3.4.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, integration, receipt, and pinning checkboxes before authorizing Phase 4.
