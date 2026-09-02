---
id: plan.jido_code_hypermedia_ui_milestone_g_phase_01
parent_plan: plan.jido_code_hypermedia_ui_milestone_g
status: proposed
intent: feature
---

# Milestone G Phase 1 - Threat Model Controls And Security Evidence

This phase reconciles the complete implemented product against its threat model
and turns every abuse case into tested prevention, detection, response, and risk ownership.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Complete adversarial security and privacy qualification.

  This phase closes HUI-G1 across identity, scope, browser, stream, command,
  graph, wiki, export, concurrency, resource, and supply-chain boundaries.

  - [ ] 1.1 Section - Reconcile assets, trust boundaries, threats, and controls.

    This section updates the threat model from proposed architecture to exact
    implemented routes, processes, adapters, data flows, and deployment topology.

    - [ ] 1.1.1 Task {#huig-p01-model} [repo: jido_code] [after: {#huif-p05-phase-receipt}] - Publish the implementation-specific threat/control matrix.

      This task gives every threat an owner, control, test, signal, response,
      residual risk, and explicit release decision.

      - [ ] 1.1.1.1 Subtask - Inventory protected identities, credentials/sessions, graph facts, source/wiki/memory/evidence, commands/receipts, costs, incidents, exports, assets, availability, and audit integrity.
      - [ ] 1.1.1.2 Subtask - Model browser/server/proxy/identity/TripleStore/filesystem/agent/provider/dependency/operator boundaries and routes for spoofing, tampering, disclosure, denial, elevation, repudiation, and inference.
      - [ ] 1.1.1.3 Subtask - Map each threat to prevention, validation point, safe failure, detection/telemetry, response/runbook, automated/manual test, evidence owner, severity, and reopening condition.
      - [ ] 1.1.1.4 Subtask - Record out-of-scope assumptions, compensating controls, residual risks, exceptions, approvers, expiry, and exact candidate/config applicability.

  - [ ] 1.2 Section - Harden identity, browser, rendering, and delivery boundaries.

    This section closes account/session, IDOR, request, injection, cache, stream,
    replay, and cross-scope inference paths.

    - [ ] 1.2.1 Task {#huig-p01-web} [repo: jido_code] [after: {#huig-p01-model}] - Complete browser and server-boundary hardening.

      This task verifies defenses in production mode rather than development
      defaults or navigation hiding.

      - [ ] 1.2.1.1 Subtask - Harden account/authenticator/recovery/session/cookie/step-up/revocation, rate/lockout, safe redirect, error concealment, audit, and no shared-operator fallback.
      - [ ] 1.2.1.2 Subtask - Harden exact page/field/query/detail/export/stream/patch authorization, opaque-ref resolution, cache keys, totals/facets/timing, and cross-tenant/project/graph inference.
      - [ ] 1.2.1.3 Subtask - Harden CSRF/Origin/Fetch Metadata/content type/method, closed signals/forms, HEEx/Markdown/HTML/CSV/JSON/filename/link injection, CSP/frame/referrer/nosniff, and no inline/eval/remote runtime.
      - [ ] 1.2.1.4 Subtask - Harden stream admission/lifetime/revocation/replay/reconnect/queue/backpressure, stale client/assets, error patches, protected caching/logging/telemetry, and clickjacking.

  - [ ] 1.3 Section - Harden commands, approvals, graphs, resources, and supply chain.

    This section closes action spoofing/races, raw authority bypass, exhaustion,
    data exfiltration, and dependency compromise paths.

    - [ ] 1.3.1 Task {#huig-p01-authority} [repo: jido_code] [after: {#huig-p01-web}] - Complete command, graph, export, and concurrency hardening.

      This task verifies exact current preconditions and durable receipts under
      malicious replay, races, and partial failure.

      - [ ] 1.3.1.1 Subtask - Harden canonical previews/digests, step-up/SoD/quorum, revision/fence/lease/profile/reason/idempotency, stale invalidation, receipt lookup, uncertain transport, and concurrent humans.
      - [ ] 1.3.1.2 Subtask - Harden reviewed query/lens registry, graph joins, memory/wiki/incident/dataset minimization, export generation/retrieval, cancellation, retention, and revocation.
      - [ ] 1.3.1.3 Subtask - Enforce request/parser/query/render/connection/queue/patch/export/rate/time/memory/file/decompression limits with overload fallback and anti-amplification behavior.
      - [ ] 1.3.1.4 Subtask - Verify dependency/asset/source/lock/license/SBOM integrity, build/release provenance, update path, advisory response, compromised-upstream rollback, and secrets absence.

  - [ ] 1.4 Section - Phase 1 Integration Tests.

    This final section executes the full hostile corpus and independent review
    against the exact production candidate and topology.

    - [ ] 1.4.1 Task {#huig-p01-integration} [repo: jido_code] [after: {#huig-p01-authority}] - Execute the HUI-G1 security, privacy, and exhaustion matrix.

      This task closes threats only with reproducible exploit/negative evidence
      and documented residual-risk decisions.

      - [ ] 1.4.1.1 Subtask - Run identity/session/IDOR/scope/inference, signal/request/injection/CSRF/CSP/cache/log/referrer, stream/replay/revocation, command/approval/race, graph/export, and supply-chain tests.
      - [ ] 1.4.1.2 Subtask - Run fuzz/property/malformed/oversized/deep/decompression/resource, concurrent connection/query/export/command, slow-client, reconnect storm, and load/soak cases.
      - [ ] 1.4.1.3 Subtask - Complete independent security/privacy review or penetration assessment; remediate findings and record accepted risks with owners/expiry.
      - [ ] 1.4.1.4 Subtask - Run architecture/dependency/audit/telemetry checks, `mix precommit`, and clean-checkout CI against exact production configuration.

    - [ ] 1.4.2 Task {#huig-p01-phase-receipt} [repo: jido_code] [after: {#huig-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records HUI-G1 evidence in
      `docs/architecture/hypermedia-ui-milestone-g-phase-01-receipt.md`.

      - [ ] 1.4.2.1 Subtask - Keep HUI-G1 merge-pending on open critical/high risk, authority/data leak, replay/race, injection/CSRF/CSP bypass, unbounded exhaustion path, unsafe supply chain, or unowned residual risk.
      - [ ] 1.4.2.2 Subtask - Record exact threat/control/test/finding/artifact/config evidence, remediation, exceptions, owners, expiry, and all reopening conditions.
      - [ ] 1.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 1 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 2.
