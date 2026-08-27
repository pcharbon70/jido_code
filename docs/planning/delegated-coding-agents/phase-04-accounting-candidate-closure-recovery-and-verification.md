---
id: plan.jido_code_delegated_coding_agents_phase_04
parent_plan: plan.jido_code_delegated_coding_agents
status: approved
intent: feature
---

# Delegated Coding Agents Phase 4 - Accounting, Candidate Closure, Recovery, And Verification

This phase accounts for the observable outer Codex runtime, independently
captures workspace effects, and verifies immutable candidates from a fresh
checkout.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Convert an opaque Codex run into a trustworthy candidate workflow.

  This phase proves DCG4 by recording honest outer accounting, recomputing
  candidates, separating verification, and recovering only from graph state
  and accepted content-addressed artifacts.

  - [x] 4.1 Section - Implement honest delegated accounting and turn checkpoints.

    This section records everything JidoCode controls without fabricating
    visibility into Codex's internal prompts, reasoning, provider context, or
    tool loop.

    - [x] 4.1.1 Task {#dca-p04-accounting} [repo: jido_code] [after: {#dca-p03-phase-receipt}] - Extend total semantic accounting for delegated turns.

      This task distinguishes authoritative controller evidence from incomplete
      provider and CLI observations.

      - [x] 4.1.1.1 Subtask - Mark internal prompts, reasoning, provider context, and internal tool mediation explicitly unavailable in the delegated-input and accounting manifests.
      - [x] 4.1.1.2 Subtask - Record invocation-before-effect and terminal-or-ambiguous outcomes for every outer Codex run and JidoCode-controlled credential, check, candidate, and verifier effect.
      - [x] 4.1.1.3 Subtask - Adopt only bounded lifecycle, usage, changed-path, check-request, terminal, workspace, patch, tree, artifact, and omission observations.
      - [x] 4.1.1.4 Subtask - Exclude raw prompts, transcripts, hidden reasoning, unbounded output, credentials, and provider-private state from graph and memory.
      - [x] 4.1.1.5 Subtask - Capture a content-addressed workspace checkpoint at accepted turn boundaries so follow-up and restart do not require provider-session state.

  - [ ] 4.2 Section - Capture and close immutable candidates.

    This section derives candidate identity and integrity from the isolated
    workspace rather than trusting the delegated agent.

    - [ ] 4.2.1 Task {#dca-p04-candidate} [repo: jido_code] [after: {#dca-p04-accounting}] - Extend controller-owned candidate closure for Codex workspaces.

      This task produces an immutable proposal with exact provenance and
      explicit accounting omissions.

      - [ ] 4.2.1.1 Subtask - Recompute the normalized patch, resulting tree, ordered path operations, generated artifact identities, and digests from the exact base.
      - [ ] 4.2.1.2 Subtask - Bind candidate identity to source, attempt, fence, delegated profile, adapter, CLI, model, sandbox, policy, tool manifest, check registry, and candidate protocol.
      - [ ] 4.2.1.3 Subtask - Attach controller-observed registered-check receipts and secret-scan evidence without trusting CLI-reported success.
      - [ ] 4.2.1.4 Subtask - Quarantine dirty bases, symlink escapes, special files, forbidden paths, oversized patches, generated-file violations, secrets, and digest mismatches.
      - [ ] 4.2.1.5 Subtask - Keep candidate, verification, evidence sufficiency, disposition, publication authorization, and goal satisfaction separate.

  - [ ] 4.3 Section - Implement independent verification and recovery.

    This section proves candidates in a separate environment and makes
    cancellation, restart, timeout, and ambiguity fail closed.

    - [ ] 4.3.1 Task {#dca-p04-verification} [repo: jido_code] [after: {#dca-p04-candidate}] - Verify delegated candidates from a fresh checkout.

      This task prevents the Codex workspace, process, provider session, or
      reported checks from becoming its own verifier.

      - [ ] 4.3.1.1 Subtask - Reconstruct the exact source and immutable patch in an independently provisioned verifier environment.
      - [ ] 4.3.1.2 Subtask - Run required checks from the verifier registry and compare expected tree, patch, file, artifact, and secret-scan digests.
      - [ ] 4.3.1.3 Subtask - Require a distinct verifier identity and prohibit reuse of the delegated workspace, CLI process, provider session, or CLI check reports.
      - [ ] 4.3.1.4 Subtask - Produce governed evidence and disposition while leaving publication and merge unavailable for the DGA1 profile.

    - [ ] 4.3.2 Task {#dca-p04-recovery} [repo: jido_code] [after: {#dca-p04-verification}] - Reconcile cancellation, timeout, ambiguity, and restart.

      This task reconstructs semantic action from graph state and exact
      checkpoint artifacts rather than disposable runtime references.

      - [ ] 4.3.2.1 Subtask - Enforce cancellation order: graph intent, permit revocation, adapter cancel, process-namespace kill, workspace cleanup, late-output rejection, and terminal accounting.
      - [ ] 4.3.2.2 Subtask - Classify timeout as a failure outcome and ambiguity as an effect or result classification, not an invented lifecycle state.
      - [ ] 4.3.2.3 Subtask - On restart, discard process and provider-session references and reconstruct only from graph facts, exact source, and accepted workspace checkpoints.
      - [ ] 4.3.2.4 Subtask - Forbid generic retry after a possibly completed effect and require effect-identity reconciliation plus an accepted recovery classification.
      - [ ] 4.3.2.5 Subtask - Reject stale fences and late streams, files, callbacks, artifacts, candidates, verification results, and terminal events before adoption.

  - [ ] 4.4 Section - Phase 4 Integration Tests.

    This final section proves end-to-end candidate integrity, verifier
    independence, cancellation ordering, ambiguity handling, and graph-only
    recovery.

    - [ ] 4.4.1 Task {#dca-p04-integration} [repo: jido_code] [after: {#dca-p04-recovery}] - Execute the candidate and recovery integration matrix.

      This task closes DCG4 only when opaque Codex work becomes independently
      reproducible evidence.

      - [ ] 4.4.1.1 Subtask - Run admission, Codex turns, real workspace edits, registered checks, candidate capture, fresh-checkout verification, evidence, and disposition end to end.
      - [ ] 4.4.1.2 Subtask - Inject malformed output, dirty bases, path attacks, secret findings, digest mismatch, check disagreement, verifier loss, and corrupt checkpoints.
      - [ ] 4.4.1.3 Subtask - Inject BEAM restart, worker loss, provider outage, partial output, process crash, cancellation races, ambiguity, stale fences, and late results.
      - [ ] 4.4.1.4 Subtask - Prove graph-only reconstruction and prove Codex cannot verify, accept, publish, merge, mutate policy, or adopt knowledge.
      - [ ] 4.4.1.5 Subtask - Rerun DCG1-DCG3 and prior factory, harness, memory, managed-coding, architecture, Dialyzer, `mix precommit`, and clean-checkout gates.

    - [ ] 4.4.2 Task {#dca-p04-phase-receipt} [repo: jido_code] [after: {#dca-p04-integration}] - Publish and pin the Phase 4 receipt.

      This task records DCG4 evidence in
      `docs/architecture/delegated-agent-phase-04-receipt.md`.

      - [ ] 4.4.2.1 Subtask - Record accounting, checkpoint, candidate, verifier, recovery, reconciliation, and adversarial fixture revisions and digests.
      - [ ] 4.4.2.2 Subtask - Keep DCG4 open if CLI claims become authoritative, candidate facts are not recomputed, verification reuses the delegated workspace, or restart depends on disposable state.
      - [ ] 4.4.2.3 Subtask - Attach candidate, verifier, restart, cancellation, ambiguity, late-result, architecture, Dialyzer, precommit, and clean-checkout evidence.
      - [ ] 4.4.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, integration, receipt, and pinning checkboxes before authorizing Phase 5.
