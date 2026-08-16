---
id: plan.jido_code_secure_effective_agent_harness_phase_07
parent_plan: plan.jido_code_secure_effective_agent_harness
status: planned
intent: feature
---

# Harness Phase 7 - Evaluation And Controlled Rollout

This phase measures the whole harness as a system, attacks it with an
adversarial suite, and gates every rollout stage so autonomy increases only
from measured outcomes.

Back to plan: [README](./README.md)

- [ ] 7 Phase - Let evidence, not confidence, set the autonomy boundary.

  This phase pins corpora, metrics, adjudication, and gates so every later
  authority increase is justified and reversible.

  - [ ] 7.1 Section - Build the evaluation tracks and pinned corpora.

    This section treats each capability claim as a reproducible experiment.

    - [ ] 7.1.1 Task {#sah-p07-eval-tracks} [repo: jido_code] [after: {#sah-p06-phase-receipt}] - Implement the evaluation track harness.

      This task pins task corpora and revisions per track so results are
      comparable across time.

      - [ ] 7.1.1.1 Subtask {#sah-p07-7-1-1-1} - Implement tracks for access-profile conformance, ReqLLM provider contract, JidoHarness CLI contract, harness conformance, editing reliability, retrieval, SWE-bench Verified, fresh and private issues, terminal workload, flaky-test corpus, production shadow, and pull-request pilot.
      - [ ] 7.1.1.2 Subtask {#sah-p07-7-1-1-2} - Pin each evaluation profile's task corpus and revisions, acceptance stage, correctness oracle, verifier policy, human-review rubric, reviewer independence, disagreement procedure, and statistical method.
      - [ ] 7.1.1.3 Subtask {#sah-p07-7-1-1-3} - Report every result sliced by repository, language, task class, risk, model, access mode, authentication kind, billing mode, adapter revisions, CLI version, harness profile, and tool version, never pooling access modes without separate reporting.
      - [ ] 7.1.1.4 Subtask {#sah-p07-7-1-1-4} - Use multiple fresh independent executions with confidence intervals for stochastic claims; never assume provider seed control.

  - [ ] 7.2 Section - Implement primary metrics and correctness adjudication.

    This section defines success mathematically and keeps humans as the
    correctness oracle where it matters.

    - [ ] 7.2.1 Task {#sah-p07-metrics} [repo: jido_code] [after: {#sah-p07-eval-tracks}] - Implement the metric and adjudication pipeline.

      This task prevents an abstaining or self-grading system from looking
      successful.

      - [ ] 7.2.1.1 Subtask {#sah-p07-7-2-1-1} - Implement Correct Accepted Yield, accepted precision, critical false-acceptance incidence, acceptance coverage, attempt coverage, tool-proposal schema validity, and malformed-proposal containment.
      - [ ] 7.2.1.2 Subtask {#sah-p07-7-2-1-2} - Fix two-sided 95 percent Wilson score intervals for binary proportion gates and preregistered stratified bootstrap for continuous metrics; report patch approval and final-goal satisfaction separately.
      - [ ] 7.2.1.3 Subtask {#sah-p07-7-2-1-3} - Require the independent fresh-checkout verifier plus verifier-owned or hidden checks for executable correctness; fresh or private tasks additionally receive two blinded independent reviewers with a third resolving disagreement under the pinned rubric.
      - [ ] 7.2.1.4 Subtask {#sah-p07-7-2-1-4} - Keep LLM judges advisory only, and also report pass-at-one, repeated-run consistency, separately labelled pass-at-k, unauthorized-effect and stale-fence rejection rates, provenance completeness, verifier reproducibility, retrieval recall and token cost, recovery success, cost and latency per correct accepted outcome, review time and override rate, and post-publication CI, revert, incident, and regression rates.

  - [ ] 7.3 Section - Build the adversarial security suite.

    This section attacks utility and security together, distinguishing safe
    failure from violating success.

    - [ ] 7.3.1 Task {#sah-p07-adversarial} [repo: jido_code] [after: {#sah-p07-metrics}] - Implement the release adversarial suite.

      This task provides the zero-bypass evidence the rollout gates require.

      - [ ] 7.3.1.1 Subtask {#sah-p07-7-3-1-1} - Cover instruction injection through source comments, documentation, issue titles, branch names, paths, compiler output, and test logs, each checking task utility and security outcome.
      - [ ] 7.3.1.2 Subtask {#sah-p07-7-3-1-2} - Cover path traversal, symlink, hard-link, and shell injection; malicious hooks, workflows, and build scripts; metadata-service, SSRF, DNS-rebinding, and redirect attacks; and fake credentials plus canary secrets outside authorized scope.
      - [ ] 7.3.1.3 Subtask {#sah-p07-7-3-1-3} - Cover memory poisoning and delayed cross-attempt retrieval; malicious CLI project settings, extensions, skills, and cached provider context; provider login-cache theft, argv prompt inspection, journal disclosure, and cross-actor credential reuse; and malicious MCP-style tool descriptions and changed schemas.
      - [ ] 7.3.1.4 Subtask {#sah-p07-7-3-1-4} - Cover stale worker, approval race, branch movement, and duplicate-effect races; test deletion, skip configuration, verifier manipulation, and forged results; resource exhaustion, persistence, and sandbox escape; and cross-repository or cross-tenant access.

  - [ ] 7.4 Section - Implement rollout stages and graduation gates.

    This section encodes the staged authority ladder and its numeric gates.

    - [ ] 7.4.1 Task {#sah-p07-rollout} [repo: jido_code] [after: {#sah-p07-adversarial}] - Implement the staged rollout gate.

      This task makes each stage advance a recorded, reviewable decision.

      - [ ] 7.4.1.1 Subtask {#sah-p07-7-4-1-1} - Encode stages 0 through 6 (contract, offline, shadow, draft PR, PR publication, broader PR, limited merge as a separate future decision) with per-stage authority limits and graduation evidence recorded per `ModelAccessProfile`.
      - [ ] 7.4.1.2 Subtask {#sah-p07-7-4-1-2} - Enforce zero critical authorization, credential, protected-branch, host, or evidence bypasses in the preregistered adversarial suite; 100 percent stale-fence and late-output rejection; 100 percent evidence binding to manifest and revisions; 100 percent malformed-proposal containment; and 100 percent unapproved-fallback rejection.
      - [ ] 7.4.1.3 Subtask {#sah-p07-7-4-1-3} - Require at least 300 fresh or private eligible tasks across at least 10 repositories, accepted precision of at least 95 percent with the Wilson lower bound at least 90 percent, zero critical false acceptances, and fresh-checkout reproducibility for every accepted patch before automatic pull-request publication.
      - [ ] 7.4.1.4 Subtask {#sah-p07-7-4-1-4} - Keep single-operator profiles at shadow stage until an independently authenticated and granted decision actor satisfies actor-separation policy, and implement immediate disablement on secret exposure, sandbox escape, evidence mismatch, or protected-branch mutation.

  - [ ] 7.5 Section - Phase 7 Integration Tests.

    This final section proves the evaluation machinery itself is sound.

    - [ ] 7.5.1 Task {#sah-p07-integration} [repo: jido_code] [after: {#sah-p07-rollout}] - Execute the evaluation-infrastructure matrices.

      This task certifies the gates before any stage advance is claimed.

      - [ ] 7.5.1.1 Subtask {#sah-p07-7-5-1-1} - Prove pinned corpora reproduce identical slices, intervals, and gate verdicts across reruns, and that changing adjudication creates a new profile version requiring a rerun.
      - [ ] 7.5.1.2 Subtask {#sah-p07-7-5-1-2} - Prove every adversarial scenario reports utility and security outcomes separately and that safe failure is distinguishable from violating success.
      - [ ] 7.5.1.3 Subtask {#sah-p07-7-5-1-3} - Prove graduation cannot advance without its recorded evidence, and that stage authority limits hold in the coordinator, not only in policy text.
      - [ ] 7.5.1.4 Subtask {#sah-p07-7-5-1-4} - Rerun prior phases, architecture scans, and `mix precommit`.

    - [ ] 7.5.2 Task {#sah-p07-phase-receipt} [repo: jido_code] [after: {#sah-p07-integration}] - Publish the Phase 7 evaluation-and-rollout receipt.

      This task records the evaluation evidence in
      `docs/architecture/harness-phase-07-receipt.md` and authorizes Phase 8
      only from the pinned merged baseline.

      - [ ] 7.5.2.1 Subtask {#sah-p07-7-5-2-1} - Record track harness, metric pipeline, adversarial suite, and rollout-gate revisions plus the candidate commit.
      - [ ] 7.5.2.2 Subtask {#sah-p07-7-5-2-2} - Attach reproducibility, scenario-coverage, and graduation-machinery results with known limitations.
      - [ ] 7.5.2.3 Subtask {#sah-p07-7-5-2-3} - Keep HG7 blocked while any metric can be computed outside its pinned profile or any stage can advance without recorded evidence.
      - [ ] 7.5.2.4 Subtask {#sah-p07-7-5-2-4} - Pin the merged candidate commit before authorizing Phase 8.
