---
id: plan.jido_code_hypermedia_ui_milestone_d_phase_04
parent_plan: plan.jido_code_hypermedia_ui_milestone_d
status: proposed
intent: feature
---

# Milestone D Phase 4 - Local Deployment, Capacity, Recovery, And Delivery Acceptance

This phase qualifies the complete live-delivery path for production-quality
use on local developer machines, establishes capacity and support controls,
and closes HUI4. The primary supported topology is a browser connecting
directly to Phoenix/Bandit on the same machine, with one application runtime
owning the local writable store. A reverse proxy, external load balancer,
public domain, or multi-node deployment is not required.

Loopback-only HTTP is the default local profile to qualify; it does not imply
that LAN or public HTTP exposure is supported. Any supported non-loopback
profile must separately qualify direct HTTPS, certificate handling, trusted
hosts/origins, and secure cookies. Local deployment retains named-human
authentication, exact authorization, CSRF/origin checks, CSP, and revocation.

Proxy-specific requirements in broader release guidance apply only if a proxy
profile is explicitly selected. Reverse-proxy and clustered profiles are
outside this phase's required acceptance scope and must not be advertised as
supported without separate qualification. Existing proxy regression evidence
is retained, but is not a prerequisite infrastructure deployment for D4.
Historical receipts and their reopening conditions remain unchanged. The
existing filename and task anchor are retained for link compatibility.

Back to plan: [README](./README.md)

Maintainer decision (2026-09-09): independent security, accessibility, and
operations-release reviews are deferred, as is the workstation suspend/resume
test. Deferred does not mean passed; retain the unchecked acceptance tasks and
all reopening conditions. Continue the production-load repair and automated
qualification without waiting for reviewer assignment. See the phase receipt
for the deferral record.

- [ ] 4 Phase - Accept bounded hypermedia delivery under production operations and faults.

  This phase closes HUI-D4 and HUI4 only when native fallback, live delivery,
  revocation, convergence, and resource behavior all pass together.

  - [ ] 4.1 Section - Configure local-first transport and deployment behavior.

    This section makes direct-server SSE behavior explicit across loopback
    binding, supported HTTP versions, buffering, timeouts, keepalive, shutdown,
    restarts, and workstation sleep/wake. TLS is qualified for any supported
    non-loopback profile, without requiring a reverse proxy.

    - [ ] 4.1.1 Task {#huid-p04-proxy} [repo: jido_code] [after: {#huid-p03-phase-receipt}] - Qualify the deployed SSE and asset topology.

      This task qualifies a production build running locally, not merely the
      development server with code reloading and development assets.

      - [ ] 4.1.1.1 Subtask - Configure and document loopback-only binding, trusted hosts/origins, supported HTTP versions, direct-server streaming and compression behavior, idle/read/write timeouts, keepalive, connection limits, cookie security, and cache policy; qualify direct TLS/HTTP2 and certificate handling only for profiles that claim them. Do not trust caller-supplied forwarding headers.
      - [ ] 4.1.1.2 Subtask - Implement local start/stop, drain/terminal retry, process crash and restart, workstation sleep/wake and network transitions, health/readiness, and safe connection cleanup; preserve single-writer ownership during upgrades and restarts rather than requiring rolling replicas or a load balancer.
      - [ ] 4.1.1.3 Subtask - Verify CSP/assets/service-worker absence or policy, stale client/asset compatibility, referrer/log privacy, and error/maintenance fallback.
      - [ ] 4.1.1.4 Subtask - Publish supported local OS/browser/runtime/transport profiles, production-build installation and upgrade commands, configuration digests, validation commands, and fail-closed behavior for unsupported network exposure or topology.

  - [ ] 4.2 Section - Establish capacity, telemetry, and operational response.

    This section bounds live delivery per principal, tenant, and factory and
    gives operators safe signals for degradation and abuse.

    - [ ] 4.2.1 Task {#huid-p04-capacity} [repo: jido_code] [after: {#huid-p04-proxy}] - Define and test stream/query/patch capacity envelopes.

      This task links admission and degradation decisions to measured resource
      ceilings rather than arbitrary process survival. Measure on declared
      developer-machine hardware and account for contention with normal
      development workloads; no dedicated monitoring service is required.

      - [ ] 4.2.1.1 Subtask - Measure concurrent streams, processes/memory, sockets, queue bytes, event/patch throughput, query pressure, CPU, reconnect rate, convergence time, and cleanup latency.
      - [ ] 4.2.1.2 Subtask - Define per-principal/session/tenant/factory budgets, alert thresholds, overload admission, coalescing/drop behavior, read-only/native fallback, and recovery hysteresis.
      - [ ] 4.2.1.3 Subtask - Instrument admitted/current/rejected/revoked/zombie streams, retries, pressure, dropped/coalesced hints, patch bytes, query latency/failure, and convergence with privacy-safe dimensions.
      - [ ] 4.2.1.4 Subtask - Publish locally usable diagnostics, resource warnings, optional monitoring integrations, triage/runbooks, developer-machine capacity assumptions, support escalation, and post-degradation reconciliation without requiring an external observability stack.

  - [ ] 4.3 Section - Reconcile delivery security, accessibility, and recovery evidence.

    This section validates full journeys through live updates and ensures
    enhancement never degrades critical native or assistive behavior.

    - [ ] 4.3.1 Task {#huid-p04-release} [repo: jido_code] [after: {#huid-p04-capacity}] - Assemble the HUI4 live-delivery dossier.

      This task binds exact code, assets, config, limits, browsers, local
      runtime/transport profiles, and fault evidence to one release candidate.

      - [ ] 4.3.1.1 Subtask - Reconcile signal/request/fragment schemas, stable roots, stream admission/lifecycle/revocation, subscription registry, convergence, native fallback, and all limits.
      - [ ] 4.3.1.2 Subtask - Complete browser/accessibility review of live status, focus, overlays, paused updates, announcements, reconnect, stale/error/concealed replacement, and reduced motion.
      - [ ] 4.3.1.3 Subtask - Rehearse disable-live-delivery rollback to accepted Milestone C pages without changing graph truth, sessions, routes, or user bookmarks.
      - [ ] 4.3.1.4 Subtask - Create `hypermedia-ui-milestone-d-phase-04-receipt.md` in merge-pending state with HUI-D4/HUI4 evidence and reopening conditions.

  - [ ] 4.4 Section - Phase 4 Integration Tests.

    This final section proves the exact candidate is secure, bounded,
    accessible, disposable, convergent, operable, and rollback-capable.

    - [ ] 4.4.1 Task {#huid-p04-integration} [repo: jido_code] [after: {#huid-p04-release}] - Execute the HUI-D4/HUI4 production delivery matrix.

      This task combines real adapters, a local production build and its
      direct-server transport, supported browsers, several scopes, load,
      faults, and live revocation. Local-first deployment does not substitute
      fake identity/graph adapters for required real integration evidence.

      - [ ] 4.4.1.1 Subtask - Run full native/enhanced request, fragment, stream, subscription, reconnect, replay, convergence, scope/revocation, focus/overlay, and accessibility scenarios.
      - [ ] 4.4.1.2 Subtask - Run connection/queue/query/patch load and soak on declared local hardware, rapid hints, reconnect storm, slow client, direct-server buffering/timeout, process crash and upgrade/restart failure, workstation sleep/wake, network transitions, graph/identity outage, and cleanup.
      - [ ] 4.4.1.3 Subtask - Verify declared limits/SLOs, privacy-safe telemetry/alerts, runbooks, degradation/native fallback, rollback rehearsal, and post-fault graph convergence.
      - [ ] 4.4.1.4 Subtask - Run all Milestone D and prior regression suites, architecture/security/a11y checks, `mix precommit`, and clean-checkout CI.

    - [ ] 4.4.2 Task {#huid-p04-phase-receipt} [repo: jido_code] [after: {#huid-p04-integration}] - Publish and pin the Phase 4 receipt and HUI4 closure.

      This task records HUI-D4/HUI4 evidence in
      `docs/architecture/hypermedia-ui-milestone-d-phase-04-receipt.md`.

      - [ ] 4.4.2.1 Subtask - Keep HUI4 merge-pending on security/revocation leak, breached resource bound, non-convergence, an unqualified claimed local runtime/transport/browser profile, inaccessible update, broken native fallback, unsafe network exposure or deployment, or failed rollback.
      - [ ] 4.4.2.2 Subtask - Record exact candidate/asset/config/local hardware/runtime/transport/browser/load/fault/rollback evidence, exceptions, limitations, unsupported deployment profiles, and every reopening condition.
      - [ ] 4.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 4 Integration Tests section, receipt task, pinning subtask, and Milestone D completion before authorizing Milestone E Phase 1.
