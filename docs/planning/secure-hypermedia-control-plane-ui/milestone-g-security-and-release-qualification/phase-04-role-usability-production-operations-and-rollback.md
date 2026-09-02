---
id: plan.jido_code_hypermedia_ui_milestone_g_phase_04
parent_plan: plan.jido_code_hypermedia_ui_milestone_g
status: proposed
intent: feature
---

# Milestone G Phase 4 - Role Usability, Production Operations, And Rollback

This phase validates human outcomes and the production deployment/operations
profile, then rehearses rollback before destructive legacy removal.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Prove critical roles, production topology, capacity, recovery, and rollback.

  This phase closes HUI-G4 by showing the exact candidate is understandable,
  operable, supportable, and reversible under realistic load and failures.

  - [ ] 4.1 Section - Execute role-centered usability qualification.

    This section measures correct outcomes for developers, maintainers,
    reviewers, operators, security responders, knowledge stewards, cost observers, and auditors.

    - [ ] 4.1.1 Task {#huig-p04-usability} [repo: jido_code] [after: {#huig-p03-phase-receipt}] - Run critical factory supervision and governance scenarios.

      This task tests attention, parallel work, trust calibration, and safe
      intervention under interruption, uncertainty, and privilege boundaries.

      - [ ] 4.1.1.1 Subtask - Test finding why work is stalled, scanning a large fleet, resuming three attempts, tracing causal/evidence/source/wiki knowledge, and interpreting readiness/freshness/truncation.
      - [ ] 4.1.1.2 Subtask - Test steer/answer/cancel/handoff/recovery, uncertain receipt recovery, review/stale approval avoidance, two-human conflicts, incident response, and role-restricted areas.
      - [ ] 4.1.1.3 Subtask - Test dependency posture, wiki opt-out/maintainer/token-cost/budget, sensitive memory/audit/dataset boundaries, stream loss/reconnect, revocation, and degraded states.
      - [ ] 4.1.1.4 Subtask - Measure task success, critical error, time to detect/understand/intervene, resume/approval accuracy, reconnect understanding, alert burden, workload, confidence, and trust calibration against thresholds.

  - [ ] 4.2 Section - Qualify production topology, capacity, and fault recovery.

    This section proves the application with real adapters, supported proxy/
    browser profiles, production builds, realistic data, and dependency failures.

    - [ ] 4.2.1 Task {#huig-p04-operations} [repo: jido_code] [after: {#huig-p04-usability}] - Execute load, soak, fault, deploy, and observability qualification.

      This task validates declared SLOs/limits and safe degradation rather than
      relying on happy-path local development behavior.

      - [ ] 4.2.1.1 Subtask - Test real identity, TripleStore, command, filesystem, wiki, asset, provider-fixture, proxy/TLS/HTTP2, browser, and telemetry adapters with production configuration.
      - [ ] 4.2.1.2 Subtask - Measure full page/fragment/query/command/export latency, stream/connection/queue/patch resources, large fleets/timelines/graphs, concurrent users/tabs, convergence, and cleanup against SLOs.
      - [ ] 4.2.1.3 Subtask - Exercise identity/store/graph/wiki/provider/asset/telemetry outage/lag, proxy buffering/timeouts, disk/memory/CPU pressure, process/node/deploy failure, clock skew, stale assets/client, and overload fallback.
      - [ ] 4.2.1.4 Subtask - Verify health/readiness, dashboards/alerts, safe logs/traces/metrics, capacity/runbooks/on-call ownership, backup/restore, incident escalation, and post-fault reconciliation.

  - [ ] 4.3 Section - Qualify clean installation, upgrade, and rollback.

    This section demonstrates that the release can be reproduced, upgraded,
    reversed, and recovered before Milestone H removes fallback code.

    - [ ] 4.3.1 Task {#huig-p04-rollback} [repo: jido_code] [after: {#huig-p04-operations}] - Rehearse install, upgrade, rollback, and release abort decisions.

      This task binds route/assets/session/stream/command/graph compatibility to
      an exact candidate and declares the observation window Milestone H must use.

      - [ ] 4.3.1.1 Subtask - Run clean install/build/config/bootstrap/start, representative data restore, production assets, identity setup, health/readiness, and smoke journeys from maintained docs.
      - [ ] 4.3.1.2 Subtask - Run upgrade from the accepted pre-hypermedia baseline with session/cookie, route/deep-link, graph/schema/query/command, wiki/accounting, asset/cache, and stream compatibility.
      - [ ] 4.3.1.3 Subtask - Rehearse rollback of routes/assets/config/dependencies while terminating streams safely, preserving command/receipt truth, reconciling graphs, and avoiding irreversible data mismatch.
      - [ ] 4.3.1.4 Subtask - Define canary, go/no-go, observation, abort, reconciliation, escalation, fallback retention, and rollback-close authorities/thresholds.

  - [ ] 4.4 Section - Phase 4 Integration Tests.

    This final section proves human and operational qualification results hold
    together at one exact production-like candidate.

    - [ ] 4.4.1 Task {#huig-p04-integration} [repo: jido_code] [after: {#huig-p04-rollback}] - Execute the HUI-G4 usability, operations, and rollback matrix.

      This task combines measured role outcomes, real adapters, production
      topology, load/faults, clean install/upgrade, and rollback.

      - [ ] 4.4.1.1 Subtask - Run all predeclared role scenarios with representative participants, large/parallel/failure states, exact metrics, critical-error review, and remediation reruns.
      - [ ] 4.4.1.2 Subtask - Run production build/proxy/browser real-adapter load/soak/fault/deploy/overload/backup-restore scenarios and verify SLO/limit/alert/runbook outcomes.
      - [ ] 4.4.1.3 Subtask - Run clean install, upgrade, canary/abort, rollback, graph/receipt/accounting reconciliation, and operator handoff solely from maintained documentation.
      - [ ] 4.4.1.4 Subtask - Run operational/security/accessibility/usability regressions, `mix precommit`, and clean-checkout CI against exact candidate/config.

    - [ ] 4.4.2 Task {#huig-p04-phase-receipt} [repo: jido_code] [after: {#huig-p04-integration}] - Publish and pin the Phase 4 receipt.

      This task records HUI-G4 evidence in
      `docs/architecture/hypermedia-ui-milestone-g-phase-04-receipt.md`.

      - [ ] 4.4.2.1 Subtask - Keep HUI-G4 merge-pending on failed critical task/threshold, breached SLO/limit, unsupported topology, missing alert/runbook/owner, failed clean install/upgrade/rollback, or unexplained reconciliation.
      - [ ] 4.4.2.2 Subtask - Record exact usability participants/results, topology/config/load/fault/install/upgrade/rollback evidence, exceptions, owners, expiry, and all reopening conditions.
      - [ ] 4.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 4 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 5.
