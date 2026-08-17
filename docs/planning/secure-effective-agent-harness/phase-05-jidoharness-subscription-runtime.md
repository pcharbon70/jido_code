---
id: plan.jido_code_secure_effective_agent_harness_phase_05
parent_plan: plan.jido_code_secure_effective_agent_harness
status: planned
intent: feature
---

# Harness Phase 5 - JidoHarness Subscription Runtime

This phase admits delegated coding-CLI execution through JidoHarness only
after its adoption blockers are resolved, as one delegated activity inside
one graph-authorized attempt, with proven containment and cancellation.

Back to plan: [README](./README.md)

- [ ] 5 Phase - Treat subscription CLIs as delegated execution, never as a second model port.

  This phase gives subscription developers first-class access while keeping
  coarse-grained authority, credential isolation, and disposable runtime
  truth.

  - [x] 5.1 Section - Resolve the JidoHarness adoption gates.

    This section converts the research's release blockers into accepted
    evidence before any dependency merge.

    - [x] 5.1.1 Task {#sah-p05-adoption-gates} [repo: jido_code] - Resolve compatibility, prompt-transport, journal, and tool-profile gates.

      This task keeps an unreleased, incompatible runtime out of the
      production dependency tree until each gap is closed.

      - [x] 5.1.1.1 Subtask {#sah-p05-5-1-1-1} - Resolve the Elixir `~> 1.19` versus JidoCode `~> 1.18` toolchain conflict and JidoHarness's unreleased state through an accepted dependency and toolchain decision with a pinned revision and digest.
      - [x] 5.1.1.2 Subtask {#sah-p05-5-1-1-2} - Require protected prompt transport (stdin or protected file, never CLI argv) so prompts are not readable through process inspection.
      - [x] 5.1.1.3 Subtask {#sah-p05-5-1-1-3} - Require disabled, memory-only, or separately owned journals inaccessible to tool descendants, with per-record and total retention bounds and propagation through every nested process; disposable disk journals remain developer-local opt-in only and are disclosed.
      - [x] 5.1.1.4 Subtask {#sah-p05-5-1-1-4} - Require verified deny-all-tools and bounded-tool profiles with conformance tests; an empty tool list must mean no tools, not a missing flag.

  - [x] 5.2 Section - Implement the delegated runtime adapter.

    This section maps one Harness run or session turn to one delegated
    execution activity with disposable references.

    - [x] 5.2.1 Task {#sah-p05-harness-adapter} [repo: jido_code] [after: {#sah-p05-adoption-gates}] - Implement `JidoCode.Runtime.JidoHarnessAdapter` and run registry.

      This task keeps JidoHarness behind the execution-runtime port and out
      of Knowledge and model-port dependencies.

      - [x] 5.2.1.1 Subtask {#sah-p05-5-2-1-1} - Implement the adapter against the existing execution-runtime port so one Harness run or session turn is a delegated execution activity inside one graph-authorized attempt.
      - [x] 5.2.1.2 Subtask {#sah-p05-5-2-1-2} - Keep an ephemeral run registry valid only within one BEAM lifetime; run IDs, session IDs, provider session IDs, event cursors, process IDs, and journals are never required for restart recovery.
      - [x] 5.2.1.3 Subtask {#sah-p05-5-2-1-3} - Map Harness lifecycle and normalized terminal results to graph attempts; treat missing CLI processes after restart as runtime diagnostics classified through the accepted transition vocabulary (recover, supersede, propagated cancellation, abandon, retry-later), never an invented `crashed` state.
      - [x] 5.2.1.4 Subtask {#sah-p05-5-2-1-4} - Record the delegated run, CLI and provider versions, bounded normalized lifecycle observations, final workspace digest, candidate diff, and artifacts; keep CLI event records observations rather than proof of complete tool mediation, and never adopt provider-internal context claims.

  - [x] 5.3 Section - Implement developer-local delegated mode.

    This section ships the explicit local opt-in inside the Phase 4 isolated
    worker while managed fleet use stays blocked.

    - [x] 5.3.1 Task {#sah-p05-developer-local} [repo: jido_code] [after: {#sah-p05-harness-adapter}] - Offer official CLIs as explicit developer-local opt-in.

      This task matches the trust assumptions of running the CLI manually
      and labels them honestly.

      - [x] 5.3.1.1 Subtask {#sah-p05-5-3-1-1} - Run developer-local CLIs only inside the Phase 4 isolated worker with one disposable worktree at the exact snapshot, `env_mode: :replace` with a minimal environment, provider endpoint egress only, no store handle, no publication credentials, no SSH agent or Docker socket, and no unrelated repository access.
      - [x] 5.3.1.2 Subtask {#sah-p05-5-3-1-2} - Apply hard finite outer run and session-turn counts, idle, wall-clock, output, process, memory, and disk limits, plus CLI-internal ceilings only where the selected profile can enforce or reliably report them, recording each dimension's enforcement class.
      - [x] 5.3.1.3 Subtask {#sah-p05-5-3-1-3} - Exclude no additional directories, project extensions, MCP servers, skills, or provider configuration beyond the accepted profile; allow none of them to grant protected-branch or publication authority.
      - [x] 5.3.1.4 Subtask {#sah-p05-5-3-1-4} - Label every developer-local profile opt-in and exclude it from managed-fleet security claims; keep managed delegated use blocked until the credential-helper or proxy boundary from Phase 4 is proven per provider.

  - [x] 5.4 Section - Prove cancellation and containment.

    This section makes outer process-namespace termination the safety net
    that adapter bugs cannot defeat.

    - [x] 5.4.1 Task {#sah-p05-cancellation} [repo: jido_code] [after: {#sah-p05-developer-local}] - Prove bounded process-group cancellation per adapter.

      This task prevents orphaned CLI process trees after cancellation,
      expiry, or supersession.

      - [x] 5.4.1.1 Subtask {#sah-p05-5-4-1-1} - Require every enabled adapter to prove cancellation terminates its CLI parent and descendant process group within a bound; keep the Z.AI adapter disabled until it exposes and proves native cancellation.
      - [x] 5.4.1.2 Subtask {#sah-p05-5-4-1-2} - On lease expiry or supersession, commit cancellation, ask the adapter to stop, and independently kill the outer worker's process namespace before sandbox destruction.
      - [x] 5.4.1.3 Subtask {#sah-p05-5-4-1-3} - Reject any late event, diff, artifact, callback, or result by the current-fence check so nothing enters durable graph state or triggers an external JidoCode effect after expiry.
      - [x] 5.4.1.4 Subtask {#sah-p05-5-4-1-4} - Add non-billable readiness discovery and consent-gated live smoke tests per supported subscription profile, reporting authentication evidence without claiming actor identity.

  - [ ] 5.5 Section - Phase 5 Integration Tests.

    This final section proves delegated containment, recovery, and honest
    capability reporting.

    - [ ] 5.5.1 Task {#sah-p05-integration} [repo: jido_code] [after: {#sah-p05-cancellation}] - Execute the delegated-runtime matrices.

      This task certifies the subscription path before verification and
      publication work on its candidates.

      - [ ] 5.5.1.1 Subtask {#sah-p05-5-5-1-1} - Prove delegated attempts start only from graph authorization, run inside the isolated worker, and recover entirely from graph state after BEAM restart with disposable journals and sessions.
      - [ ] 5.5.1.2 Subtask {#sah-p05-5-5-1-2} - Prove bounded process-group cancellation per enabled adapter, late-output rejection after expiry, and sandbox destruction with bounded candidate capture.
      - [ ] 5.5.1.3 Subtask {#sah-p05-5-5-1-3} - Prove journal privacy under the accepted profile, prompt non-exposure in argv, and zero subscription credential, prompt, journal, or cross-actor canary leakage in the profile adversarial suite.
      - [ ] 5.5.1.4 Subtask {#sah-p05-5-5-1-4} - Rerun prior phases, architecture scans, and `mix precommit`.

    - [ ] 5.5.2 Task {#sah-p05-phase-receipt} [repo: jido_code] [after: {#sah-p05-integration}] - Publish the Phase 5 delegated-runtime receipt.

      This task records the runtime evidence in
      `docs/architecture/harness-phase-05-receipt.md` and authorizes Phase 6
      only from the pinned merged baseline.

      - [ ] 5.5.2.1 Subtask {#sah-p05-5-5-2-1} - Record the pinned JidoHarness revision, enabled adapters with cancellation proofs, profile labels, and the candidate commit.
      - [ ] 5.5.2.2 Subtask {#sah-p05-5-5-2-2} - Attach lifecycle, cancellation, privacy, readiness, and restart-recovery results with known limitations.
      - [ ] 5.5.2.3 Subtask {#sah-p05-5-5-2-3} - Keep HG5 blocked while any adapter lacks a cancellation bound, any journal or prompt can leak, or any late output can enter durable state.
      - [ ] 5.5.2.4 Subtask {#sah-p05-5-5-2-4} - Pin the merged candidate commit before authorizing Phase 6.
