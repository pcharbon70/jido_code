---
id: plan.jido_code_hypermedia_ui_milestone_e_phase_02
parent_plan: plan.jido_code_hypermedia_ui_milestone_e
status: proposed
intent: feature
---

# Milestone E Phase 2 - Causal Timeline, Evidence, And Resume

This phase implements the bounded normalized timeline that correlates parallel
attempt activity while preserving event type, provenance, causal identity, and
independent evidence authority.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Deliver a trustworthy causal timeline and evidence inspection path.

  This phase closes HUI-E2 by making retries, parallel work, claims, effects,
  verification, decisions, and source outcomes understandable without reducing
  the attempt to chat chronology.

  - [ ] 2.1 Section - Define and implement normalized timeline records.

    This section maps accepted graph resources into a closed display vocabulary
    with deterministic ordering, correlation, pagination, and redaction.

    - [ ] 2.1.1 Task {#huie-p02-model} [repo: jido_code] [after: {#huie-p01-phase-receipt}] - Implement the causal timeline query and normalization layer.

      This task does not manufacture causal order from timestamps when durable
      correlation or partial order is absent.

      - [ ] 2.1.1.1 Subtask - Normalize plan/checkpoint, interaction/message, tool/effect, artifact, verification, decision, command/receipt, handoff/recovery, cost, wiki, publication/application, incident, and satisfaction events.
      - [ ] 2.1.1.2 Subtask - Preserve event identity, type, actor class/ref, causal parent/correlation, attempt/session/candidate refs, source/evaluated revision, timestamps, provenance, classification, and redaction.
      - [ ] 2.1.1.3 Subtask - Define deterministic partial-order/grouping/tie behavior, retry/supersession/duplicate/late/missing semantics, concurrent branches, and explicit unknown ordering.
      - [ ] 2.1.1.4 Subtask - Enforce allowed types/joins, page/time/count/byte bounds, truncation, cancellation, query timeout, and exact field/resource authorization.

  - [ ] 2.2 Section - Render timeline, event detail, and evidence views.

    This section presents causality and trust through accessible timeline/table
    structures and separately authorized evidence inspection.

    - [ ] 2.2.1 Task {#huie-p02-ui} [repo: jido_code] [after: {#huie-p02-model}] - Implement timeline, filters, grouping, and accessible alternatives.

      This task keeps human scanning efficient at high volume and preserves
      native navigation plus live-update stability.

      - [ ] 2.2.1.1 Subtask - Render grouped causal timeline with event summaries, state markers, actor, time, outcome, provenance, retry/supersession, and trust distinctions.
      - [ ] 2.2.1.2 Subtask - Add bounded event-type/time/actor/outcome filters, server pagination, deep links, table/text alternative, new-updates indicator, and paused visual updates.
      - [ ] 2.2.1.3 Subtask - Preserve focus/selection/scroll on patches and provide keyboard navigation, screen-reader summaries, reduced motion, narrow layout, and print behavior.
      - [ ] 2.2.1.4 Subtask - Render unknown/missing/late/duplicate/contradictory/partial/truncated/stale/unavailable/concealed states without implying a complete chronology.

    - [ ] 2.2.2 Task {#huie-p02-evidence} [repo: jido_code] [after: {#huie-p02-ui}] - Implement event detail, artifact, effect, and evidence inspection.

      This task distinguishes agent claims from observed effects and independent
      verification and applies separate authorization to protected content.

      - [ ] 2.2.2.1 Subtask - Render typed event detail with canonical refs, source/evaluated revisions, causal relationships, actor, classification, integrity, retention, and receipt/evidence links.
      - [ ] 2.2.2.2 Subtask - Provide safe bounded previews for text/diff/log/test/artifact/evidence content with escaping/sanitization, byte/line limits, binary handling, and download policy.
      - [ ] 2.2.2.3 Subtask - Distinguish requested effect, observed effect, verifier evidence, decision, draft publication, external application, re-observation, post-change verification, and satisfaction.
      - [ ] 2.2.2.4 Subtask - Reauthorize detail/download on every access and invalidate open/cached/queued content on field/graph/resource/session revocation.

  - [ ] 2.3 Section - Integrate timeline resume and convergence.

    This section lets a human reconstruct several attempts after interruption
    and receive live changes without losing causal or authorization boundaries.

    - [ ] 2.3.1 Task {#huie-p02-resume} [repo: jido_code] [after: {#huie-p02-evidence}] - Add bounded since-known summaries and live timeline fragments.

      This task reuses server-known revisions and registered subscriptions; it
      never treats browser event IDs as the durable event log.

      - [ ] 2.3.1.1 Subtask - Derive bounded since-known counts/key events per accepted event family using a scoped expiring cursor and fresh authorized queries.
      - [ ] 2.3.1.2 Subtask - Register timeline/event-detail fragment roots and graph-family hints with current snapshot, nudge, gap/reconnect, and revocation behavior.
      - [ ] 2.3.1.3 Subtask - Coalesce rapid updates while preserving terminal/security/decision/receipt events and expose explicit truncation/new-updates/freshness state.
      - [ ] 2.3.1.4 Subtask - Prove browser/session/process restart and hint loss converge to current durable records without duplicate or missing truth claims.

  - [ ] 2.4 Section - Phase 2 Integration Tests.

    This final section proves the timeline remains causal, bounded, accessible,
    scoped, and convergent across high-volume parallel and failed activity.

    - [ ] 2.4.1 Task {#huie-p02-integration} [repo: jido_code] [after: {#huie-p02-resume}] - Execute the HUI-E2 timeline, evidence, and recovery matrix.

      This task uses real event/evidence graphs and injects disorder, gaps,
      redaction, revocation, and transport faults.

      - [ ] 2.4.1.1 Subtask - Exercise every event type and state distinction, causal branch, retry/supersession, duplicate/late/missing/unknown order, filter/page/truncation, and high-volume sequence.
      - [ ] 2.4.1.2 Subtask - Exercise claims/effects/evidence/decision/publication/application/satisfaction distinctions, hostile previews/downloads, field redaction, copied detail refs, and revocation.
      - [ ] 2.4.1.3 Subtask - Exercise several attempt tabs, since-known cursors, paused updates, hint loss/reorder, reconnect/restart, focus/scroll/selection, native fallback, and accessibility modes.
      - [ ] 2.4.1.4 Subtask - Run real-store/browser/stream/security/accessibility/load suites, `mix precommit`, and clean-checkout CI.

    - [ ] 2.4.2 Task {#huie-p02-phase-receipt} [repo: jido_code] [after: {#huie-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records HUI-E2 evidence in
      `docs/architecture/hypermedia-ui-milestone-e-phase-02-receipt.md`.

      - [ ] 2.4.2.1 Subtask - Keep HUI-E2 merge-pending on causal identity loss, fabricated total order, claim/evidence conflation, unbounded content, cross-scope detail, inaccessible timeline, or non-convergent resume.
      - [ ] 2.4.2.2 Subtask - Record event/query/view/limit/browser/fault evidence, failures, limitations, and all reopening conditions.
      - [ ] 2.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 2 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 3.
