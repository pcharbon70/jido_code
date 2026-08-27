---
id: plan.jido_code_delegated_coding_agents_phase_05
parent_plan: plan.jido_code_delegated_coding_agents
status: approved
intent: feature
---

# Delegated Coding Agents Phase 5 - Developer Product Workflow

This phase exposes one consistent browser, API, and CLI workflow while keeping
all process, credential, graph, and runtime details behind product gateways.

Back to plan: [README](./README.md)

- [ ] 5 Phase - Make the Codex profile selectable and controllable by developers.

  This phase proves DCG5 by giving developers one foreground workflow for
  catalog selection, submission, progress, clarification, steering,
  cancellation, candidate handoff, and independent verification.

  - [x] 5.1 Section - Implement product gateways and authenticated JSON APIs.

    This section translates product requests into the same reviewed queries
    and Factory commands used by every other surface.

    - [x] 5.1.1 Task {#dca-p05-gateways} [repo: jido_code] [after: {#dca-p04-phase-receipt}] - Add catalog, submission, attempt, and control gateways.

      This task centralizes input validation, authorization, redaction,
      idempotency, and exact offering resolution.

      - [x] 5.1.1.1 Subtask - Add a catalog gateway returning actor-, tenant-, repository-, task-, capability-, rollout-, and time-scoped `AgentOffering` projections.
      - [x] 5.1.1.2 Subtask - Add a submission gateway accepting semantic intent, repository and snapshot, task class, acceptance requirements, opaque offering, actor, and idempotency key.
      - [x] 5.1.1.3 Subtask - Extend the attempt projection with runtime, profile, provider, deployment, billing, readiness, interaction, workspace, candidate, verification, disposition, and limitation fields.
      - [x] 5.1.1.4 Subtask - Extend the control gateway with state-aware steer, answer, cancel, handoff, and accepted recovery controls.
      - [x] 5.1.1.5 Subtask - Prevent every gateway from accepting modules, executables, credentials, raw sandbox settings, arbitrary commands, graph names, raw RDF, or provider options.

    - [x] 5.1.2 Task {#dca-p05-api} [repo: jido_code] [after: {#dca-p05-gateways}] - Add versioned JSON API routes.

      This task gives automation a bounded representation of the same workflow
      without direct runtime or store access.

      - [x] 5.1.2.1 Subtask - Add authenticated `/api/v1/agent-offerings` and `/api/v1/coding-attempts` catalog, submit, detail, and refresh endpoints.
      - [x] 5.1.2.2 Subtask - Add state-bound control endpoints for steer, answer, cancel, handoff, and accepted recovery.
      - [x] 5.1.2.3 Subtask - Use bounded bearer authentication mapped to the existing product identity and authority context and never persist or echo the credential.
      - [x] 5.1.2.4 Subtask - Return stable outcome codes for admitted, duplicate, stale, unauthorized, incompatible, unavailable, rejected, and conflict cases.

  - [x] 5.2 Section - Build the browser catalog, submission, and attempt experience.

    This section presents native and delegated coding agents together while
    making their different trust, billing, readiness, rollout, and authority
    boundaries unmistakable.

    - [x] 5.2.1 Task {#dca-p05-browser} [repo: jido_code] [after: {#dca-p05-api}] - Implement the authenticated coding-agent workflow.

      This task gives developers a polished foreground workflow with explicit
      selection, consent, billing acknowledgement, and honest runtime status.

      - [x] 5.2.1.1 Subtask - Add an agent catalog and task-submission LiveView using `<Layouts.app>`, `current_scope`, streams, `to_form`, `<.input>`, and stable DOM IDs.
      - [x] 5.2.1.2 Subtask - Display runtime class, provider, deployment, billing, capability, readiness age, rollout stage, repository envelope, and material limitations.
      - [x] 5.2.1.3 Subtask - Require explicit profile selection plus foreground consent and billing acknowledgement before submission.
      - [x] 5.2.1.4 Subtask - Extend the attempt experience to show normalized progress, clarification, boundary steering, workspace effects, checks, candidate, verification, disposition, and cleanup.
      - [x] 5.2.1.5 Subtask - Show controls only in valid states and omit publication, protected-branch, and merge controls for the DGA1 profile.

  - [x] 5.3 Section - Add the developer CLI.

    This section provides a scriptable local interface without placing task
    context or authentication material in command arguments.

    - [x] 5.3.1 Task {#dca-p05-cli} [repo: jido_code] [after: {#dca-p05-browser}] - Implement `mix jido_code.agent`.

      This task invokes the same authenticated product gateways as the browser
      and JSON API.

      - [x] 5.3.1.1 Subtask - Add `catalog`, `submit`, `show`, `steer`, `answer`, `cancel`, and `handoff` subcommands.
      - [x] 5.3.1.2 Subtask - Accept bounded JSON requests through stdin or a protected regular file and never accept semantic task content or credentials directly in argv.
      - [x] 5.3.1.3 Subtask - Emit bounded machine-readable JSON with stable outcome codes and redacted diagnostics.
      - [x] 5.3.1.4 Subtask - Require authenticated local operator context for every query and action and reuse exact product authorization.
      - [x] 5.3.1.5 Subtask - Reject unknown fields, raw commands, executable paths, provider options, credentials, and stale offering references.

  - [ ] 5.4 Section - Phase 5 Integration Tests.

    This final section proves all three product surfaces produce equivalent
    authorized behavior and disclose no internal authority or sensitive state.

    - [ ] 5.4.1 Task {#dca-p05-integration} [repo: jido_code] [after: {#dca-p05-cli}] - Execute browser, API, CLI, and product security matrices.

      This task closes DCG5 only when a developer can complete the supported
      DGA1 workflow through every public surface.

      - [x] 5.4.1.1 Subtask - Test catalog filtering, explicit selection, submission, consent, billing, readiness expiry, duplicate requests, stale offerings, and incompatible profiles.
      - [x] 5.4.1.2 Subtask - Test LiveView forms, streams, empty states, loading states, and controls through stable element IDs without raw HTML assertions.
      - [x] 5.4.1.3 Subtask - Test JSON and CLI parity for catalog, submit, status, clarification, steering, cancellation, handoff, recovery, and bounded errors.
      - [x] 5.4.1.4 Subtask - Prove graph IRIs, process IDs, workspace paths, prompts, transcripts, hidden reasoning, credentials, and unbounded output are not displayed or returned.
      - [ ] 5.4.1.5 Subtask - Prove no browser, API, or CLI route can publish or merge, then rerun DCG1-DCG4, architecture checks, Dialyzer, `mix precommit`, and clean-checkout CI.

    - [ ] 5.4.2 Task {#dca-p05-phase-receipt} [repo: jido_code] [after: {#dca-p05-integration}] - Publish and pin the Phase 5 receipt.

      This task records DCG5 evidence in
      `docs/architecture/delegated-agent-phase-05-receipt.md`.

      - [x] 5.4.2.1 Subtask - Record product gateway, route, LiveView, CLI, API, authentication, projection, redaction, and UI contract revisions.
      - [x] 5.4.2.2 Subtask - Keep DCG5 open if a surface bypasses semantic admission, differs in authority, leaks prohibited details, or exposes publication or merge.
      - [ ] 5.4.2.3 Subtask - Attach surface-parity, authorization, redaction, accessibility, LiveView, API, CLI, precommit, Dialyzer, and clean-checkout evidence.
      - [ ] 5.4.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, integration, receipt, and pinning checkboxes before authorizing Phase 6.
