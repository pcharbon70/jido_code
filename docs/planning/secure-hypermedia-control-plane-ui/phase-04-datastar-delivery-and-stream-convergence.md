---
id: plan.jido_code_secure_hypermedia_control_plane_ui_phase_04
parent_plan: plan.jido_code_secure_hypermedia_control_plane_ui
status: proposed
intent: feature
---

# Secure Hypermedia Control Plane UI Phase 4 — Datastar Delivery And Stream Convergence

This phase implements Milestone D and closes HUI4 by progressively enhancing
the read-only shell with closed signals, stable HEEx fragments, one bounded
authorized stream per page/tab, server-owned subscription refresh, reconnect,
revocation, backpressure, and graph-revision convergence.

Back to plan: [README](./README.md)

- [ ] 4 Phase — Deliver secure bounded hypermedia updates without changing authority.

  This phase preserves native pages and graph truth while making authorized
  projections responsive to user intent and durable change hints.

  - [ ] 4.1 Section — Implement explicit request, signal, and fragment contracts.

    This section makes every enhanced request and patch closed, bounded,
    independently authorized, and stable under focus/overlay state.

    - [ ] 4.1.1 Task {#hui-p04-signals} [repo: jido_code] [after: {#hui-p03-phase-receipt}] — Implement per-page signal schemas and request handlers.

      This task admits only harmless bounded request/presentation intent and
      keeps identity, authority, commands, and revisions server-derived.

      - [ ] 4.1.1.1 Subtask — Define namespace, allowed local/non-local keys, per-action subsets, normalization, count/depth/length/aggregate-byte limits, and scope-reset behavior for each page.
      - [ ] 4.1.1.2 Subtask — Implement explicit controller handlers for filter/sort/cursor/search and reject unknown, duplicate, malformed, oversized, or forbidden authority keys.
      - [ ] 4.1.1.3 Subtask — Integrate CSRF header/body transport outside non-local signals plus Origin/Fetch Metadata, no GET effects, no-store/referrer/log policy.
      - [ ] 4.1.1.4 Subtask — Enforce static expressions, HEEx escaping/sanitization, CSP HTTP nonce mode, no Dstar Scripts, and production debug-error disablement.

    - [ ] 4.1.2 Task {#hui-p04-fragments} [repo: jido_code] [after: {#hui-p04-signals}] — Implement coherent stable fragment renderers.

      This task updates the smallest complete authorized projection without
      corrupting focus, reading position, native overlays, or state labels.

      - [ ] 4.1.2.1 Subtask — Define stable roots for attention, health, fleet, project summary/attempts, attempt header/timeline/checks/budget, receipt, and lens results.
      - [ ] 4.1.2.2 Subtask — Render data/state/revision/freshness/accessibility metadata atomically per fragment and never retain unavailable rows.
      - [ ] 4.1.2.3 Subtask — Preserve focused forms, navigation, open overlays, scroll roots, selected rows/nodes, and explicit post-action focus targets.
      - [ ] 4.1.2.4 Subtask — Add paused/new-updates mode for nonessential auto-updating tables/timelines without implying agent pause.

  - [ ] 4.2 Section — Implement authorized stream coordination and graph convergence.

    This section connects scoped durable change hints to current reviewed
    projections without treating SSE or browser revisions as truth.

    - [ ] 4.2.1 Task {#hui-p04-stream} [repo: jido_code] [after: {#hui-p04-fragments}] — Implement the supervised page/tab stream coordinator.

      This task owns admission, dedup/takeover, route/scope state, hard expiry,
      revocation, queueing, retries, metrics, and cleanup.

      - [ ] 4.2.1.1 Subtask — Authorize CSRF/origin/principal/route/resource before response start and key takeover by trusted browser-session identity plus untrusted tab ID.
      - [ ] 4.2.1.2 Subtask — Store trusted route/scope/generation/authorization/expiry/subscription state and separately limit missing/invalid tab IDs.
      - [ ] 4.2.1.3 Subtask — Enforce connection/queue/event/patch/rate/lifetime/heartbeat/retry/backoff/cleanup limits per principal, tenant, and factory.
      - [ ] 4.2.1.4 Subtask — Implement hard expiry, independent generation/revocation subscription, periodic/pre-patch reauthorization, concealed replacement, terminal close, and reconnect suppression.

    - [ ] 4.2.2 Task {#hui-p04-subscription} [repo: jido_code] [after: {#hui-p04-stream}] — Adapt existing ProjectionSubscription to SSE patch and nudge delivery.

      This task preserves server-owned evaluated revisions, coalescing,
      reauthorization, and refresh callbacks.

      - [ ] 4.2.2.1 Subtask — Map graph-family/revision hints to closed projection families and subscribed authorized routes without carrying display data in hints.
      - [ ] 4.2.2.2 Subtask — Emit fresh server-known fragments directly or named nudges when the tab must resend bounded filter/cursor intent.
      - [ ] 4.2.2.3 Subtask — On connect/reconnect load current snapshots and scope any replay cursor to principal/session/tab/route/repository/attempt/projection.
      - [ ] 4.2.2.4 Subtask — Converge under dropped, duplicate, reordered, delayed, coalesced hints and deploy/process restart without browser revision authority.

  - [ ] 4.3 Section — Operationalize live delivery and safe fallback.

    This section ensures live updates fail observably to safe ordinary pages
    rather than producing false freshness or unbounded resource use.

    - [ ] 4.3.1 Task {#hui-p04-operations} [repo: jido_code] [after: {#hui-p04-subscription}] — Add stream health, limits, telemetry, and deployment controls.

      This task makes connection behavior supportable without logging protected
      content or conflating connection with data freshness.

      - [ ] 4.3.1.1 Subtask — Instrument admitted/current/rejected/revoked/zombie streams, retries, queue pressure, coalesced/dropped hints, patch bytes, query latency, and convergence time with safe dimensions.
      - [ ] 4.3.1.2 Subtask — Render live/reconnecting/offline separately from ready/stale/unavailable and disable/revalidate freshness-sensitive future controls.
      - [ ] 4.3.1.3 Subtask — Configure TLS/HTTP2, reverse-proxy buffering/timeouts, keepalive, cache/referrer/log policy, and deploy drain/restart.
      - [ ] 4.3.1.4 Subtask — Create `hypermedia-ui-phase-04-receipt.md` in merge-pending state with Gate HUI4 limits, metrics, and reopening conditions.

  - [ ] 4.4 Section — Phase 4 Integration Tests.

    This final section proves live delivery is bounded, authorized, accessible,
    disposable, and convergent with durable graph truth.

    - [ ] 4.4.1 Task {#hui-p04-integration} [repo: jido_code] [after: {#hui-p04-operations}] — Execute the HUI4 request, fragment, stream, and recovery matrix.

      This task closes live delivery only under hostile inputs, failures,
      several tabs/users/scopes, and the deployed proxy/runtime profile.

      - [ ] 4.4.1.1 Subtask — Exercise every signal schema/key/bound, forbidden authority field, CSRF/Origin/CSP/injection case, request class, and fragment target/state.
      - [ ] 4.4.1.2 Subtask — Exercise several tabs/routes/projects/users, takeover, missing tab ID, connection/queue limits, paused updates, focus/overlay/scroll preservation.
      - [ ] 4.4.1.3 Subtask — Exercise hint loss/duplicate/reorder/delay, stale revisions, query error, disconnect/reconnect, sleep/wake, deploy restart, hard expiry, role/session revocation, terminal retry, and cleanup.
      - [ ] 4.4.1.4 Subtask — Run load/resource/proxy tests, browser/accessibility regression, architecture/security checks, `mix precommit`, and clean-checkout CI.

    - [ ] 4.4.2 Task {#hui-p04-phase-receipt} [repo: jido_code] [after: {#hui-p04-integration}] — Publish and pin the Phase 4 receipt.

      This task records Gate HUI4 evidence and authorizes semantic controls only
      from the merged bounded delivery baseline.

      - [ ] 4.4.2.1 Subtask — Keep HUI4 merge-pending on unbounded signals/streams/patches, auth after response start, client revision authority, CSRF leak, focus loss, protected reconnect, or convergence failure.
      - [ ] 4.4.2.2 Subtask — Record the full merge SHA/date, exact limits/config/proxy/browser evidence, metrics, failures, and accepted limitations.
      - [ ] 4.4.2.3 Subtask — Pin the merged candidate commit and check the phase, Phase 4 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 5.
