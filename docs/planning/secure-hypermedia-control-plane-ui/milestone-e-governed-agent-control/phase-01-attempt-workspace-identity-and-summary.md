---
id: plan.jido_code_hypermedia_ui_milestone_e_phase_01
parent_plan: plan.jido_code_hypermedia_ui_milestone_e
status: proposed
intent: feature
---

# Milestone E Phase 1 - Attempt Workspace Identity And Summary

This phase builds the authoritative attempt workspace frame and its bounded
summary panels before timeline or command complexity is introduced.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Deliver a durable, scoped, resumable attempt oversight workspace.

  This phase closes HUI-E1 by making attempt identity, state, authority,
  readiness, evidence, and cost posture understandable in native and live modes.

  - [ ] 1.1 Section - Implement attempt identity and trust-header projections.

    This section keeps every durable/ephemeral identity distinct and exposes
    the exact context in which the attempt may be understood or controlled.

    - [ ] 1.1.1 Task {#huie-p01-identity} [repo: jido_code] [after: {#huid-p04-phase-receipt}] - Implement the attempt workspace query and view model.

      This task composes only accepted bounded projections and separately
      authorizes every field and destination.

      - [ ] 1.1.1.1 Subtask - Query attempt, task, repository/project, agent/profile, runtime, branch/worktree, owner, lifecycle, outcome, current revision/fence, lease, policy, and source baseline.
      - [ ] 1.1.1.2 Subtask - Represent linked `InteractionSession`, provider thread, browser session, candidate, verification, publication/application, wiki preview, and process identities as distinct typed references.
      - [ ] 1.1.1.3 Subtask - Include current principal scope/role explanation, assurance, permitted action vocabulary, freshness, readiness, provenance, redaction, and unsupported capability posture.
      - [ ] 1.1.1.4 Subtask - Bound linked-resource counts/details and expose separately authorized durable URLs without raw IRIs or graph traversal.

    - [ ] 1.1.2 Task {#huie-p01-header} [repo: jido_code] [after: {#huie-p01-identity}] - Render the trust header and lifecycle/outcome rails.

      This task gives users a stable source-of-truth summary independent of
      chat text, process heartbeat, or connection status.

      - [ ] 1.1.2.1 Subtask - Render identity/scope, task intent, agent/profile/runtime, branch/worktree, lifecycle and outcome, revision/fence/lease, readiness, freshness, and ownership.
      - [ ] 1.1.2.2 Subtask - Distinguish planned/requested/admitted/running from observed/effected/verified/decided/published/applied/re-observed/satisfied states.
      - [ ] 1.1.2.3 Subtask - Render stream connection separately from data freshness and process liveness separately from semantic progress.
      - [ ] 1.1.2.4 Subtask - Add accessible definitions, provenance links, responsive layout, keyboard order, screen-reader summaries, and stable fragment roots.

  - [ ] 1.2 Section - Compose bounded oversight summary panels.

    This section surfaces enough plan, interaction, artifact, evidence, review,
    cost, wiki, and receipt context to decide where deeper inspection is needed.

    - [ ] 1.2.1 Task {#huie-p01-panels} [repo: jido_code] [after: {#huie-p01-header}] - Implement attempt plan, activity, evidence, and budget summaries.

      This task avoids a wall of chat by grouping domain concerns while
      retaining causal links and projection states.

      - [ ] 1.2.1.1 Subtask - Render current plan/checkpoint/next expected work, recent interactions, artifacts/effects, verification/decision, command/receipt, handoff/recovery, and incident summaries.
      - [ ] 1.2.1.2 Subtask - Render token/monetary budget and usage, provider/model attribution, wiki generation activity/cost, reservations, thresholds, and estimate/final labels where authorized.
      - [ ] 1.2.1.3 Subtask - Render wiki enrollment/opt-out/effective policy, maintainer/readiness, candidate/publication/application, and known gaps without fabricating controls.
      - [ ] 1.2.1.4 Subtask - Apply bounded recent-item counts, partial/truncated states, safe empty/unavailable/concealed behavior, and links to separately authorized details.

  - [ ] 1.3 Section - Implement resume and live-summary behavior.

    This section lets humans return to several parallel attempt workspaces and
    understand what changed without creating browser-owned durable read markers.

    - [ ] 1.3.1 Task {#huie-p01-resume} [repo: jido_code] [after: {#huie-p01-panels}] - Implement server-derived since-known summary and fragment refresh.

      This task uses a bounded signed/browser-session preference or explicit
      accepted durable marker and never silently mutates graph truth on read.

      - [ ] 1.3.1.1 Subtask - Define permitted resume cursor/last-seen input, scope binding, expiry, tamper handling, cross-tab behavior, and no-authority semantics.
      - [ ] 1.3.1.2 Subtask - Derive bounded changes in lifecycle/outcome, plan, interactions, effects, evidence, reviews, costs, commands, wiki, and incidents since the safe cursor.
      - [ ] 1.3.1.3 Subtask - Add native full-page and Datastar fragment refresh using existing stream/subscription contracts and stable workspace roots.
      - [ ] 1.3.1.4 Subtask - Preserve paused visual updates, focus/scroll/selection, stale/error/concealed replacement, and several workspace tabs without cross-attempt state.

  - [ ] 1.4 Section - Phase 1 Integration Tests.

    This final section proves the workspace identity and summary remain scoped,
    truthful, bounded, resumable, accessible, and read-only.

    - [ ] 1.4.1 Task {#huie-p01-integration} [repo: jido_code] [after: {#huie-p01-resume}] - Execute the HUI-E1 workspace identity and resume matrix.

      This task covers parallel attempts, several users/tabs, all projection
      states, and changed authority while a workspace is open.

      - [ ] 1.4.1.1 Subtask - Exercise all identity/state/readiness distinctions, linked resources, field redactions, unsupported capabilities, and native/live projection states.
      - [ ] 1.4.1.2 Subtask - Exercise several parallel attempts/workspaces, copied refs/cursors, cross-project/interaction/candidate/preview probes, stale resume cursors, role/session revocation, and concealed replacement.
      - [ ] 1.4.1.3 Subtask - Exercise long/high-volume summaries, truncation, hostile content, cost/wiki opt-out, focus/scroll/paused updates, responsive, keyboard, screen-reader, and no-JS behavior.
      - [ ] 1.4.1.4 Subtask - Run real-store/browser/stream/security/accessibility suites, `mix precommit`, and clean-checkout CI with no command effect.

    - [ ] 1.4.2 Task {#huie-p01-phase-receipt} [repo: jido_code] [after: {#huie-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records HUI-E1 evidence in
      `docs/architecture/hypermedia-ui-milestone-e-phase-01-receipt.md`.

      - [ ] 1.4.2.1 Subtask - Keep HUI-E1 merge-pending on identity conflation, heartbeat-as-progress, cross-scope/cursor leak, unbounded summary, false capability, inaccessible workspace, or read-side graph effect.
      - [ ] 1.4.2.2 Subtask - Record query/view-model/root/cursor/limit/browser evidence, failures, limitations, and all reopening conditions.
      - [ ] 1.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 1 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 2.
