---
id: plan.jido_code_secure_effective_agent_harness_phase_08
parent_plan: plan.jido_code_secure_effective_agent_harness
status: planned
intent: feature
---

# Harness Phase 8 - Optional Extensions

This phase keeps the high-blast-radius extensions - MCP tool transport,
remote agents, multi-agent execution, and autonomous merge - behind their
own acceptance gates, each evaluated on measured need rather than enabled by
default.

Back to plan: [README](./README.md)

- [ ] 8 Phase - Add reach only when evaluation proves it is worth its risk.

  This phase is intentionally gated: every task requires its own accepted
  specification and evidence before implementation, and none is a
  prerequisite for a useful single-agent repository factory.

  - [x] 8.1 Section - Govern MCP tool transport.

    This section treats MCP as a reviewable tool source, never as an
    authority or runtime replacement.

    - [x] 8.1.1 Task {#sah-p08-mcp} [repo: jido_code] [after: {#sah-p07-phase-receipt}] - Specify and gate the MCP adapter.

      This task keeps third-party tool descriptions and servers from
      silently modifying the trusted execution surface.

      - [x] 8.1.1.1 Subtask {#sah-p08-8-1-1-1} - Require an accepted adapter specification pinning protocol, server package, server identity, and descriptor digests, namespacing tools by configured server identity.
      - [x] 8.1.1.2 Subtask {#sah-p08-8-1-1-2} - Treat tool descriptions, annotations, schemas, and results as untrusted; apply closed schemas, capabilities, budgets, and approvals through the Phase 3 monitor.
      - [x] 8.1.1.3 Subtask {#sah-p08-8-1-1-3} - Forbid token passthrough, validate token audience, implement redirect, PKCE, issuer, and scope controls, prevent SSRF and redirect rebinding during discovery, sandbox local or stdio servers separately, and reauthorize immediately before every call.
      - [x] 8.1.1.4 Subtask {#sah-p08-8-1-1-4} - Store remote handles as external references and treat remote completion as an observation requiring local verification and decision.

  - [x] 8.2 Section - Govern remote-agent delegation.

    This section maps remote work onto local governed attempts.

    - [x] 8.2.1 Task {#sah-p08-remote-agents} [repo: jido_code] [after: {#sah-p08-mcp}] - Specify and gate remote-agent delegation.

      This task keeps independently operated agents inside the same
      capability and verification boundary as local work.

      - [x] 8.2.1.1 Subtask {#sah-p08-8-2-1-1} - Require each remote task to map to a local delegated attempt with bounded capability and its own lease and fence.
      - [x] 8.2.1.2 Subtask {#sah-p08-8-2-1-2} - Route all remote results through independent verification and governed decisions; remote claims are never accepted output.
      - [x] 8.2.1.3 Subtask {#sah-p08-8-2-1-3} - Record remote agent identity, protocol versions, and capability receipts in the attempt provenance.

  - [x] 8.3 Section - Govern selective multi-agent execution.

    This section allows parallelism only where independence is proven.

    - [x] 8.3.1 Task {#sah-p08-multi-agent} [repo: jido_code] [after: {#sah-p08-remote-agents}] - Specify and gate multi-agent work.

      This task converts multi-agent gains into graph work contracts without
      free-form agent chatter.

      - [x] 8.3.1.1 Subtask {#sah-p08-8-3-1-1} - Enable multi-agent execution only for task classes where Phase 7 evaluation shows advantage: independent research branches, disjoint write sets, unboundable single-worker context, specialized isolated tools, or diversity that improves verified success enough to justify cost.
      - [x] 8.3.1.2 Subtask {#sah-p08-8-3-1-2} - Give each worker a separate graph task, context manifest, lease, capability, budget, and output schema, returning bounded outputs to the Factory coordinator.
      - [x] 8.3.1.3 Subtask {#sah-p08-8-3-1-3} - Measure conflicts, duplicated work, merge failures, elapsed time, and final correctness against the single-agent baseline before any class graduates.

  - [x] 8.4 Section - Govern autonomous merge as a separate decision.

    This section keeps human merge authority until a future accepted
    decision changes it.

    - [x] 8.4.1 Task {#sah-p08-autonomous-merge} [repo: jido_code] [after: {#sah-p08-multi-agent}] - Keep autonomous merge blocked pending its own ADR.

      This task ensures merge authority is a deliberate product and
      security decision with production evidence.

      - [x] 8.4.1.1 Subtask {#sah-p08-8-4-1-1} - Record the blocker: autonomous merge requires a separate accepted ADR, release gate, and production shadow plus pull-request evidence.
      - [x] 8.4.1.2 Subtask {#sah-p08-8-4-1-2} - Restrict any future pilot to reversible, low-risk task classes with immediate-disablement triggers and human merge retained until the gate passes.

  - [ ] 8.5 Section - Phase 8 Integration Tests.

    This final section proves each extension obeys its gate and the base
    harness is unaffected when they are disabled.

    - [x] 8.5.1 Task {#sah-p08-integration} [repo: jido_code] [after: {#sah-p08-autonomous-merge}] - Execute the extension-gate matrices.

      This task certifies that reach expands only through its accepted
      specification.

      - [x] 8.5.1.1 Subtask {#sah-p08-8-5-1-1} - Prove no enabled extension is reachable without its accepted specification, pinned digests, and monitor-mediated tools.
      - [x] 8.5.1.2 Subtask {#sah-p08-8-5-1-2} - For each implemented extension, rerun its adversarial scenarios from Phase 7 plus the full prior-phase suites, architecture scans, and `mix precommit`.
      - [x] 8.5.1.3 Subtask {#sah-p08-8-5-1-3} - Prove the harness operates identically with every extension disabled and no dormant code path affects authorization, fencing, or verification.
      - [x] 8.5.1.4 Subtask {#sah-p08-8-5-1-4} - Record which extensions shipped enabled, which remain gated, and their evidence links.

    - [ ] 8.5.2 Task {#sah-p08-phase-receipt} [repo: jido_code] [after: {#sah-p08-integration}] - Publish the Phase 8 extensions receipt.

      This task records the extension posture in
      `docs/architecture/harness-phase-08-receipt.md` and closes the
      harness plan from the pinned merged baseline.

      - [x] 8.5.2.1 Subtask {#sah-p08-8-5-2-1} - Record each extension's gate status, specification references, digests, and the candidate commit.
      - [x] 8.5.2.2 Subtask {#sah-p08-8-5-2-2} - Attach extension-gate and disabled-harness results with known limitations.
      - [x] 8.5.2.3 Subtask {#sah-p08-8-5-2-3} - Keep HG8 and the plan open while any extension is reachable without its accepted specification or evidence.
      - [ ] 8.5.2.4 Subtask {#sah-p08-8-5-2-4} - Pin the merged candidate commit and close the harness plan.
