---
id: plan.jido_code_hypermedia_ui_milestone_d_phase_02
parent_plan: plan.jido_code_hypermedia_ui_milestone_d
status: proposed
intent: feature
---

# Milestone D Phase 2 - Authorized Page/Tab Stream Coordinator

This phase implements the supervised connection lifecycle and its hard
authorization, lifetime, queue, rate, takeover, and cleanup boundaries.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Deliver one bounded authorized stream coordinator per page/tab.

  This phase closes HUI-D2 by ensuring long-lived responses cannot outlive
  current session/scope authority or exhaust factory resources.

  - [ ] 2.1 Section - Implement stream admission and trusted connection identity.

    This section authorizes the exact page/resource before response start and
    treats tab IDs and reconnect cursors only as untrusted correlation input.

    - [ ] 2.1.1 Task {#huid-p02-admission} [repo: jido_code] [after: {#huid-p01-phase-receipt}] - Implement explicit SSE route admission and takeover keys.

      This task binds connections to current server-known principal/session,
      route, scope, generation, and expiry.

      - [ ] 2.1.1.1 Subtask - Add explicit per-page stream routes with authentication, CSRF/Origin/Fetch Metadata, content negotiation, route/resource resolution, and authorization before headers/body.
      - [ ] 2.1.1.2 Subtask - Derive trusted principal/session generation/tenant/repository/attempt/route/projection identity server-side and validate bounded random tab/cursor inputs separately.
      - [ ] 2.1.1.3 Subtask - Define deterministic duplicate/takeover behavior by trusted browser session plus tab/route identity, including old-stream terminal close and race handling.
      - [ ] 2.1.1.4 Subtask - Reject missing/invalid/oversized/reused correlation values under bounded fallback limits without treating them as grants.

  - [ ] 2.2 Section - Implement supervised lifecycle, limits, and backpressure.

    This section centralizes stream ownership and ensures slow, abandoned, or
    malicious clients cannot create unbounded process or memory growth.

    - [ ] 2.2.1 Task {#huid-p02-coordinator} [repo: jido_code] [after: {#huid-p02-admission}] - Implement the page/tab stream coordinator under supervision.

      This task owns state transitions, queues, event encoding, cancellation,
      telemetry, and cleanup; page modules do not own independent stream loops.

      - [ ] 2.2.1.1 Subtask - Define admitted/connected/idle/retrying/revoked/expired/closing/closed states and trusted route/scope/subscription/generation/expiry state.
      - [ ] 2.2.1.2 Subtask - Enforce per-principal/session/tenant/factory connection counts, admission rate, event rate, event/patch bytes, queue depth/bytes, lifetime, heartbeat, retry/backoff, and idle limits.
      - [ ] 2.2.1.3 Subtask - Coalesce safe hints, drop superseded nonterminal work, terminate overflow/slow clients safely, and prevent protected payload replay after queue or scope change.
      - [ ] 2.2.1.4 Subtask - Handle client disconnect, process/node failure, deploy drain, timeout, exception, cancellation, and supervisor restart with deterministic cleanup.

  - [ ] 2.3 Section - Integrate hard expiry and live revocation.

    This section ensures a connection is never a continuing grant and protected
    delivery stops when any relevant authority generation changes.

    - [ ] 2.3.1 Task {#huid-p02-revocation} [repo: jido_code] [after: {#huid-p02-coordinator}] - Implement generation subscriptions and repeated reauthorization.

      This task rechecks authority at admission, periodically, before protected
      query/patch, and on explicit revocation events.

      - [ ] 2.3.1.1 Subtask - Subscribe to account/session/role/delegation/project/tenant/graph/incident generation changes using trusted server state.
      - [ ] 2.3.1.2 Subtask - Enforce hard session/connection expiry independent of traffic and reauthorize route/resource/projection before every protected refresh or patch.
      - [ ] 2.3.1.3 Subtask - On revocation, cancel queued work, emit only an authorized concealed/session-expired replacement where safe, terminate, audit, and suppress reconnect.
      - [ ] 2.3.1.4 Subtask - Prevent stale `Last-Event-ID`, tab ID, retry timer, cached fragment, or open socket from restoring authorization.

  - [ ] 2.4 Section - Phase 2 Integration Tests.

    This final section proves stream lifecycle is authorized, bounded,
    revocable, observable, and leak-free under concurrent clients and failures.

    - [ ] 2.4.1 Task {#huid-p02-integration} [repo: jido_code] [after: {#huid-p02-revocation}] - Execute the HUI-D2 admission, capacity, and revocation matrix.

      This task uses real HTTP streaming and production supervision rather than
      direct process-only tests.

      - [ ] 2.4.1.1 Subtask - Exercise authentication/CSRF/Origin/content negotiation, copied refs, cross-scope routes, missing/invalid tab IDs, duplicate/takeover races, and authorization before response start.
      - [ ] 2.4.1.2 Subtask - Exercise connection/rate/event/patch/queue/lifetime/heartbeat/backoff limits, slow readers, overflow, disconnect, zombie clients, process/node failure, and deploy drain.
      - [ ] 2.4.1.3 Subtask - Exercise hard expiry and every revocation generation before connect, while idle, while queued/querying, before patch, during reconnect, and after browser sleep.
      - [ ] 2.4.1.4 Subtask - Run stream/resource/security/telemetry/proxy smoke suites, `mix precommit`, and clean-checkout CI.

    - [ ] 2.4.2 Task {#huid-p02-phase-receipt} [repo: jido_code] [after: {#huid-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records HUI-D2 evidence in
      `docs/architecture/hypermedia-ui-milestone-d-phase-02-receipt.md`.

      - [ ] 2.4.2.1 Subtask - Keep HUI-D2 merge-pending on authorization after response start, unbounded connection/queue/lifetime, zombie cleanup failure, tab-derived authority, protected replay, revocation leak, or reconnect bypass.
      - [ ] 2.4.2.2 Subtask - Record exact limits/config/supervision/telemetry/load fixtures, failures, limitations, and all reopening conditions.
      - [ ] 2.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 2 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 3.
