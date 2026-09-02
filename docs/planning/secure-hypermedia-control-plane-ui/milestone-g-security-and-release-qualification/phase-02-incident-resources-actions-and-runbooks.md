---
id: plan.jido_code_hypermedia_ui_milestone_g_phase_02
parent_plan: plan.jido_code_hypermedia_ui_milestone_g
status: proposed
intent: feature
---

# Milestone G Phase 2 - Incident Resources, Actions, And Runbooks

This phase implements and qualifies separately authorized incident resources,
timelines, evidence, accepted response actions, operational runbooks, and drills.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Deliver the governed security incident control plane.

  This phase closes HUI-G2 without inventing decorative freeze, revoke,
  quarantine, or stop controls where no accepted semantic command exists.

  - [ ] 2.1 Section - Implement incident resources, lifecycle, and read projections.

    This section makes detection, scope, ownership, decisions, effects,
    verification, and closure durable and distinguishable.

    - [ ] 2.1.1 Task {#huig-p02-resources} [repo: jido_code] [after: {#huig-p01-phase-receipt}] - Implement the accepted incident ontology/query/profile.

      This task reuses TripleStore authority and closed semantic interfaces
      rather than an operations-only side database or unrestricted log search.

      - [ ] 2.1.1.1 Subtask - Implement incident identity, severity, classification, affected tenant/project/repository/attempt/session/graph/resource, owner, status, source, timestamps, policy, and audit provenance.
      - [ ] 2.1.1.2 Subtask - Implement detected/triaged/contained/remediating/recovering/re-observed/verified/follow-up/closed lifecycle with exact transition authority and reason/evidence requirements.
      - [ ] 2.1.1.3 Subtask - Implement bounded reviewed list/detail/timeline projections with readiness, stale/partial/concealed/unavailable states and exact field/evidence authorization.
      - [ ] 2.1.1.4 Subtask - Correlate alerts, human decisions, commands/receipts, effects, verification, affected resources, and follow-up without exposing an unrestricted operational event dump.

  - [ ] 2.2 Section - Bind accepted response actions and protected evidence.

    This section gives responders only command semantics accepted by ontology,
    gateways, step-up, SoD, idempotency, and receipt contracts.

    - [ ] 2.2.1 Task {#huig-p02-actions} [repo: jido_code] [after: {#huig-p02-resources}] - Implement explicit incident action previews, routes, and receipts.

      This task presents unsupported actions as manual runbook/escalation steps,
      never as a button that sends a direct process or infrastructure message.

      - [ ] 2.2.1.1 Subtask - Inventory accepted create/triage/assign/escalate/contain/revoke/freeze/quarantine/recover/verify/close commands and mark absent semantics read-only/manual.
      - [ ] 2.2.1.2 Subtask - Implement exact scope/current state/revision/fence, reason/ticket/evidence, step-up, maker/checker/quorum, canonical digest, expiry, idempotency, and conflict checks.
      - [ ] 2.2.1.3 Subtask - Render admitted/dispatched/effected/verified/failed/recovered status and durable receipts; re-observe affected resources before claiming containment or recovery.
      - [ ] 2.2.1.4 Subtask - Protect evidence previews/downloads through classification, integrity, retention, redaction, exact grants, assurance, audit, export bounds, and revocation.

  - [ ] 2.3 Section - Publish and drill incident operations.

    This section turns product capability and manual gaps into executable
    detection, containment, recovery, escalation, and reconciliation procedures.

    - [ ] 2.3.1 Task {#huig-p02-runbooks} [repo: jido_code] [after: {#huig-p02-actions}] - Implement responder runbooks, alerts, and degraded modes.

      This task ensures people can act safely when identity, graph, stream,
      command, dependency, or provider systems are degraded or compromised.

      - [ ] 2.3.1.1 Subtask - Publish runbooks for account/session compromise, authorization leak, stream abuse, uncertain/duplicate command, agent runaway suspicion, data exposure, dependency/asset compromise, graph integrity/availability, and wiki/provider incident.
      - [ ] 2.3.1.2 Subtask - Define alert intake, ownership/escalation, evidence preservation, safe read-only/degraded posture, out-of-band coordination, break-glass approval/audit, and return-to-service criteria.
      - [ ] 2.3.1.3 Subtask - Define backup/restore/reconciliation, revocation propagation, stream/queue drain, command receipt recovery, asset rollback, notification, and post-incident follow-up.
      - [ ] 2.3.1.4 Subtask - Run tabletop and technical drills with two-person actions, role boundaries, failed dependencies, missed/duplicate alerts, concurrent incidents, and shift handoff.

  - [ ] 2.4 Section - Phase 2 Integration Tests.

    This final section proves incidents are scoped, actionable, receipted,
    recoverable, and safe under concurrency, compromise, and degraded systems.

    - [ ] 2.4.1 Task {#huig-p02-integration} [repo: jido_code] [after: {#huig-p02-runbooks}] - Execute the HUI-G2 incident lifecycle and drill matrix.

      This task covers real gateways/adapters where commands exist and explicit
      manual/runbook posture where they do not.

      - [ ] 2.4.1.1 Subtask - Exercise every incident lifecycle/role/scope/severity/state, list/detail/timeline/evidence projection, field redaction, concealment, and concurrent incident update.
      - [ ] 2.4.1.2 Subtask - Exercise every accepted/unsupported action, preview/step-up/SoD/quorum/revision/idempotency/conflict/receipt/re-observation/recovery path and two-human race.
      - [ ] 2.4.1.3 Subtask - Execute technical/tabletop drills for each runbook, adapter outage, compromised session, stream revocation, uncertain command, dependency rollback, backup/restore, and handoff.
      - [ ] 2.4.1.4 Subtask - Run incident/security/audit/browser/accessibility/operations suites, `mix precommit`, and clean-checkout CI.

    - [ ] 2.4.2 Task {#huig-p02-phase-receipt} [repo: jido_code] [after: {#huig-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records HUI-G2 evidence in
      `docs/architecture/hypermedia-ui-milestone-g-phase-02-receipt.md`.

      - [ ] 2.4.2.1 Subtask - Keep HUI-G2 merge-pending on unsupported direct control, incident/evidence scope leak, stale/self-approved action, unreceipted effect, false containment/recovery, incomplete audit, or failed drill/escalation.
      - [ ] 2.4.2.2 Subtask - Record exact incident model/query/command/runbook/drill evidence, failures, limitations, and all reopening conditions.
      - [ ] 2.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 2 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 3.
