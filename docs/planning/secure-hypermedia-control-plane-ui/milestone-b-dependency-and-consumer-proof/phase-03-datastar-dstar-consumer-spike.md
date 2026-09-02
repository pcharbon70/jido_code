---
id: plan.jido_code_hypermedia_ui_milestone_b_phase_03
parent_plan: plan.jido_code_hypermedia_ui_milestone_b
status: proposed
intent: feature
---

# Milestone B Phase 3 - Datastar/Dstar Consumer Spike

This phase builds an isolated, non-product consumer that exercises the exact
server/browser/component combination through real HTTP and browser behavior.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Prove the selected hypermedia stack in a clean bounded consumer.

  This phase closes HUI-B3 with executable evidence for native HTML, Datastar
  requests and patches, Dstar SSE, reconnect, CSP, CSRF, focus, and overlays.

  - [ ] 3.1 Section - Build the isolated controller and HEEx consumer.

    This section creates ordinary page and action routes separated from product
    projections, semantic commands, and production navigation.

    - [ ] 3.1.1 Task {#huib-p03-consumer} [repo: jido_code] [after: {#huib-p02-phase-receipt}] - Implement the qualification-only page and form workflow.

      This task establishes a meaningful no-JS baseline and representative
      component composition before enhancement.

      - [ ] 3.1.1.1 Subtask - Add isolated test/dev-only controller routes and HEEx templates with explicit layout, unique DOM IDs, safe fixture data, and no LiveView route/process.
      - [ ] 3.1.1.2 Subtask - Render representative facade primitives, form validation, pagination/filter intent, loading/ready/empty/error states, dialog/disclosure overlays, and hostile labels.
      - [ ] 3.1.1.3 Subtask - Prove ordinary navigation, form submission, validation errors, focus order, deep links, reload, back/forward, and maintenance/error pages with JavaScript disabled.
      - [ ] 3.1.1.4 Subtask - Keep the consumer inaccessible in production builds unless an explicit qualification flag and restricted route policy are active.

  - [ ] 3.2 Section - Exercise Datastar request and fragment behavior.

    This section validates attribute preservation, signal serialization,
    request security, fragment targeting, morphing, and overlay continuity.

    - [ ] 3.2.1 Task {#huib-p03-requests} [repo: jido_code] [after: {#huib-p03-consumer}] - Add bounded enhanced request/patch scenarios.

      This task proves the selected browser asset and server helpers agree on
      exact encodings and failure behavior.

      - [ ] 3.2.1.1 Subtask - Define a closed harmless signal fixture with allowlisted keys, types, sizes, normalization, unknown-key rejection, and no identity/authority/revision fields.
      - [ ] 3.2.1.2 Subtask - Exercise GET-safe reads and non-GET form actions with Phoenix CSRF header/body transport, Origin/Fetch Metadata, same-origin policy, and no sensitive URL/log/referrer data.
      - [ ] 3.2.1.3 Subtask - Emit Dstar/Datastar fragment events for stable roots and verify escaping, coherent state metadata, deterministic target selection, and unsupported-event rejection.
      - [ ] 3.2.1.4 Subtask - Verify focused input/selection, open dialog/disclosure, scroll root, reading position, pending state, error summary, and explicit focus return survive expected morphs.

  - [ ] 3.3 Section - Exercise SSE, reconnect, and browser lifecycle behavior.

    This section proves the transport mechanics without assigning durable truth
    or production authorization semantics to the spike.

    - [ ] 3.3.1 Task {#huib-p03-sse} [repo: jido_code] [after: {#huib-p03-requests}] - Add a bounded Dstar SSE fixture and fault harness.

      This task verifies selected protocol behavior through real connections,
      cancellation, retry, and morph cycles.

      - [ ] 3.3.1.1 Subtask - Implement a fixed-lifetime test stream with bounded event count/bytes/rate/queue, heartbeat, retry hints, explicit completion, cancellation, and cleanup telemetry.
      - [ ] 3.3.1.2 Subtask - Exercise initial snapshot, patch and nudge events, duplicate/reordered/dropped fixture hints, disconnect/reconnect, sleep/wake, server restart, and terminal close.
      - [ ] 3.3.1.3 Subtask - Exercise several tabs, missing/duplicate tab IDs as untrusted correlation data, connection ceilings, slow consumers, backpressure, and zombie cleanup.
      - [ ] 3.3.1.4 Subtask - Verify connection state is separate from fixture freshness/truth and the page remains safely usable through native reload after enhancement failure.

  - [ ] 3.4 Section - Phase 3 Integration Tests.

    This final section proves the clean consumer works across supported browser,
    CSP, proxy, accessibility, native, and enhanced profiles.

    - [ ] 3.4.1 Task {#huib-p03-integration} [repo: jido_code] [after: {#huib-p03-sse}] - Execute the HUI-B3 real-consumer matrix.

      This task uses production-built assets and a real browser/proxy path, not
      helper-only unit tests.

      - [ ] 3.4.1.1 Subtask - Run native and enhanced workflows across supported browsers, JavaScript disabled, stale/missing asset, hard reload, back/forward, multiple tabs, and narrow/zoomed layouts.
      - [ ] 3.4.1.2 Subtask - Exercise signal tampering/size, CSRF/Origin/CSP, injection, fragment mismatch, malformed SSE, reconnect storms, slow client, proxy buffering, and cleanup.
      - [ ] 3.4.1.3 Subtask - Run keyboard, screen-reader smoke, focus/overlay, reduced-motion, forced-colors, RTL, touch, theme, and hostile-content checks.
      - [ ] 3.4.1.4 Subtask - Run exact protocol fixture tests, architecture checks, `mix precommit`, and clean-checkout CI.

    - [ ] 3.4.2 Task {#huib-p03-phase-receipt} [repo: jido_code] [after: {#huib-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records HUI-B3 evidence in
      `docs/architecture/hypermedia-ui-milestone-b-phase-03-receipt.md`.

      - [ ] 3.4.2.1 Subtask - Keep HUI-B3 merge-pending on native failure, client/server protocol mismatch, CSRF/CSP bypass, unsafe morph, lost focus/overlay state, unbounded stream, reconnect leak, or unsupported browser behavior.
      - [ ] 3.4.2.2 Subtask - Record exact consumer/config/asset/browser/proxy fixtures, results, failures, limitations, and all reopening conditions.
      - [ ] 3.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 3 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 4.
