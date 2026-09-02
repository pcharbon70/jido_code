---
id: plan.jido_code_hypermedia_ui_milestone_d_phase_03
parent_plan: plan.jido_code_hypermedia_ui_milestone_d
status: proposed
intent: feature
---

# Milestone D Phase 3 - Projection Subscription, Convergence, And Revocation

This phase connects authorized page streams to existing server-owned
projection subscriptions and graph revision hints without making SSE a truth log.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Deliver durable-truth convergence through bounded patches and nudges.

  This phase closes HUI-D3 by re-querying current authorized projections after
  lossy hints, reconnect, restart, and scope change.

  - [ ] 3.1 Section - Map route projections to server-owned subscriptions.

    This section gives each page a closed set of graph-family hints and
    reviewed refresh callbacks based on trusted route state.

    - [ ] 3.1.1 Task {#huid-p03-subscriptions} [repo: jido_code] [after: {#huid-p02-phase-receipt}] - Adapt `ProjectionSubscription` for page stream delivery.

      This task preserves evaluated server revisions, authorization, coalescing,
      and refresh ownership from the accepted bounded-projection contract.

      - [ ] 3.1.1.1 Subtask - Register route/projection families, reviewed query callbacks, allowed graph-family hints, fragment roots, and required server-known scope/filter inputs.
      - [ ] 3.1.1.2 Subtask - Build subscriptions from trusted current route/resource/authority and refuse caller-selected graphs, query names, fragment roots, or refresh functions.
      - [ ] 3.1.1.3 Subtask - Coalesce graph-family/revision hints without carrying display data, protected IDs, user values, or browser-authoritative revision claims.
      - [ ] 3.1.1.4 Subtask - Cancel/rebuild subscriptions on route/scope/filter/session generation changes and clean them on stream closure/restart.

  - [ ] 3.2 Section - Implement patch and bounded nudge delivery.

    This section emits current server-rendered fragments when possible and
    uses named nudges only when harmless tab-local intent must be resent.

    - [ ] 3.2.1 Task {#huid-p03-delivery} [repo: jido_code] [after: {#huid-p03-subscriptions}] - Implement authorized re-query, fragment, and nudge dispatch.

      This task never patches from hint payloads or asks the browser to decide
      what revision is current.

      - [ ] 3.2.1.1 Subtask - Reauthorize and execute the registered reviewed query at a server-known revision after admitted hints, timers, reconnect, and explicit refresh.
      - [ ] 3.2.1.2 Subtask - Render coherent fragments with current state/revision/freshness/provenance and enforce per-root/response/interval byte and rate limits.
      - [ ] 3.2.1.3 Subtask - Emit closed named nudges when current filter/cursor intent is required; validate the resulting bounded request through the Phase 1 schema.
      - [ ] 3.2.1.4 Subtask - Implement paused/new-visual-updates mode for nonessential tables/timelines while retaining security/revocation/session patches and truthful freshness.

  - [ ] 3.3 Section - Implement reconnect, replay scope, and convergence recovery.

    This section guarantees a reconnect loads a current authorized snapshot and
    eventually converges despite lost, duplicated, reordered, or stale hints.

    - [ ] 3.3.1 Task {#huid-p03-convergence} [repo: jido_code] [after: {#huid-p03-delivery}] - Implement initial snapshot, reconnect, and revision convergence.

      This task treats replay cursors as scoped optimization only and falls back
      to fresh reviewed queries whenever safety or continuity is uncertain.

      - [ ] 3.3.1.1 Subtask - On connect/reconnect load current authorized snapshots before incremental delivery and label connection separately from data freshness.
      - [ ] 3.3.1.2 Subtask - Scope any replay cursor to principal/session generation/tab/route/repository/attempt/projection and reject stale, copied, unknown, or post-revocation cursors.
      - [ ] 3.3.1.3 Subtask - Detect hint gaps, outdated revisions, query/patch failure, process/node/deploy restart, graph lag, and subscription loss; schedule bounded fresh re-query with backoff.
      - [ ] 3.3.1.4 Subtask - Record safe convergence metrics and stop terminal retry loops on concealment, session expiry, revocation, unsupported route, or permanent failure.

  - [ ] 3.4 Section - Phase 3 Integration Tests.

    This final section proves streams converge to authorized durable graph
    truth and never replay protected or stale browser-owned state.

    - [ ] 3.4.1 Task {#huid-p03-integration} [repo: jido_code] [after: {#huid-p03-convergence}] - Execute the HUI-D3 subscription and convergence matrix.

      This task injects real graph changes and delivery faults across several
      users, tabs, routes, repositories, and attempts.

      - [ ] 3.4.1.1 Subtask - Exercise each registered route/projection/hint/root, unknown graph/query/root, scope/filter change, subscription cancellation, and cleanup.
      - [ ] 3.4.1.2 Subtask - Exercise lost/duplicate/reordered/delayed/coalesced hints, gap detection, stale revisions, query/patch failure, graph lag, process/node/deploy restart, and backoff.
      - [ ] 3.4.1.3 Subtask - Exercise initial/reconnect snapshots, copied/stale replay cursors, sleep/wake, paused visual updates, field/scope revocation, concealment, expiry, and terminal retry suppression.
      - [ ] 3.4.1.4 Subtask - Run real-store/stream/browser/accessibility/security/convergence suites, `mix precommit`, and clean-checkout CI.

    - [ ] 3.4.2 Task {#huid-p03-phase-receipt} [repo: jido_code] [after: {#huid-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records HUI-D3 evidence in
      `docs/architecture/hypermedia-ui-milestone-d-phase-03-receipt.md`.

      - [ ] 3.4.2.1 Subtask - Keep HUI-D3 merge-pending on hint-as-data, client revision authority, unregistered subscription, replay scope leak, non-convergence, stale protected patch, retry loop, or incomplete cleanup.
      - [ ] 3.4.2.2 Subtask - Record registry/query/root/replay/limit/fault/convergence evidence, failures, limitations, and all reopening conditions.
      - [ ] 3.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 3 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 4.
