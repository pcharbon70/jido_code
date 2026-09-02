---
id: plan.jido_code_hypermedia_ui_milestone_g_phase_05
parent_plan: plan.jido_code_hypermedia_ui_milestone_g
status: proposed
intent: feature
---

# Milestone G Phase 5 - Release Candidate Acceptance

This phase assembles independent evidence, fixes the exact qualified candidate,
runs the full regression matrix, and closes HUI7 before destructive cleanup.

Back to plan: [README](./README.md)

- [ ] 5 Phase - Accept the secure, accessible, operable, rollback-capable release candidate.

  This phase closes HUI-G5 and HUI7 only when all prior program gates remain
  true at the same immutable commit, artifacts, configuration, and topology.

  - [ ] 5.1 Section - Assemble the immutable release and evidence manifest.

    This section binds code, dependencies, assets, config, schemas, fixtures,
    browsers, proxies, tests, findings, approvals, and residual risks.

    - [ ] 5.1.1 Task {#huig-p05-manifest} [repo: jido_code] [after: {#huig-p04-phase-receipt}] - Build the HUI7 release-candidate dossier.

      This task rejects mixed-candidate or stale evidence and makes every
      exception accountable and expiring.

      - [ ] 5.1.1.1 Subtask - Record full candidate SHA/tree, locks/SBOM/licenses/advisories, asset/source/build digests, schemas/protocols/queries/components, config/feature flags, toolchains, and deployment topology.
      - [ ] 5.1.1.2 Subtask - Index security/threat/incident/accessibility/usability/load/fault/install/upgrade/rollback evidence with command/fixture/browser/AT/proxy versions and retention/integrity.
      - [ ] 5.1.1.3 Subtask - Reconcile all HUI1-HUI6 receipts/reopening conditions, open findings, residual risks, exceptions, compensating controls, owners, expiry, and required approvers.
      - [ ] 5.1.1.4 Subtask - Define final go/no-go, canary, observation, abort, incident, rollback, evidence invalidation, and Milestone H authorization criteria.

  - [ ] 5.2 Section - Conduct independent final review and remediation.

    This section verifies architecture, security, accessibility, operations,
    and product evidence independently and reruns anything invalidated by fixes.

    - [ ] 5.2.1 Task {#huig-p05-review} [repo: jido_code] [after: {#huig-p05-manifest}] - Execute cross-discipline release review.

      This task requires reviewers to verify evidence and candidate identity,
      not merely approve summaries.

      - [ ] 5.2.1.1 Subtask - Review architecture/authority/runtime, identity/security/privacy, commands/receipts/incidents, graph/lens/wiki/accounting, accessibility/usability, and operations/rollback domains.
      - [ ] 5.2.1.2 Subtask - Verify no critical/high finding, failed threshold, unowned exception, stale evidence, unsupported dependency/topology, false readiness, or unresolved rollback risk remains.
      - [ ] 5.2.1.3 Subtask - Remediate findings through scoped changes; invalidate and rerun every affected test/evidence class on the new exact candidate.
      - [ ] 5.2.1.4 Subtask - Record reviewer identity/role/independence, findings/disposition, residual-risk acceptance, expiry, and separation-of-duty approvals.

  - [ ] 5.3 Section - Prepare release operations and removal authorization.

    This section freezes the cutover/rollback manifest Milestone H may execute
    and prevents cleanup from expanding beyond proven consumers.

    - [ ] 5.3.1 Task {#huig-p05-authorization} [repo: jido_code] [after: {#huig-p05-review}] - Publish the qualified parity and removal-entry manifest.

      This task maps each legacy route/module/process/dependency/asset/test/doc/
      operation to qualified replacement, intentional retirement, or retained exception.

      - [ ] 5.3.1.1 Subtask - Reconcile product route/capability/read/control/lens/incident/accessibility/security/operations parity and identify any legacy-only consumer.
      - [ ] 5.3.1.2 Subtask - Freeze route/traffic cohort order, canary/abort/rollback checkpoints, session/assets/stream/command/graph compatibility, and observation metrics.
      - [ ] 5.3.1.3 Subtask - Authorize no removal for items lacking qualified replacement/retirement evidence; assign owner and reopening condition to every retained exception.
      - [ ] 5.3.1.4 Subtask - Create `hypermedia-ui-milestone-g-phase-05-receipt.md` in merge-pending state with HUI-G5/HUI7 evidence and all reopening conditions.

  - [ ] 5.4 Section - Phase 5 Integration Tests.

    This final section runs the complete program acceptance matrix at the exact
    candidate and proves its evidence can be reproduced from clean checkout.

    - [ ] 5.4.1 Task {#huig-p05-integration} [repo: jido_code] [after: {#huig-p05-authorization}] - Execute the HUI-G5/HUI7 final release matrix.

      This task is the final non-destructive qualification gate before
      Milestone H may cut over and remove old runtime consumers.

      - [ ] 5.4.1.1 Subtask - Run full identity/authorization/native/live/control/review/cost/wiki/lens/incident/security/accessibility/usability/operations journeys across supported roles/scopes/browsers/AT/topology.
      - [ ] 5.4.1.2 Subtask - Run hostile/fuzz/IDOR/inference/injection/replay/race/exhaustion, large/parallel/load/soak, adapter/proxy/node/deploy faults, revocation, backup/restore, and reconciliation.
      - [ ] 5.4.1.3 Subtask - Run clean install/upgrade/canary/abort/rollback and independently reproduce evidence digests, reports, dashboards/alerts, runbooks, and removal-entry manifest.
      - [ ] 5.4.1.4 Subtask - Run all prior phase suites, architecture/security/a11y checks, dependency/license scans, `mix precommit`, and clean-checkout CI on the pinned candidate.

    - [ ] 5.4.2 Task {#huig-p05-phase-receipt} [repo: jido_code] [after: {#huig-p05-integration}] - Publish and pin the Phase 5 receipt and HUI7 closure.

      This task records HUI-G5/HUI7 evidence in
      `docs/architecture/hypermedia-ui-milestone-g-phase-05-receipt.md`.

      - [ ] 5.4.2.1 Subtask - Keep HUI7 merge-pending on mixed/stale evidence, open critical/high finding, failed security/a11y/usability/operations threshold, unsupported candidate/topology, unproven rollback, or unexplained legacy consumer.
      - [ ] 5.4.2.2 Subtask - Record exact candidate/artifact/config/evidence/reviewer/risk/removal manifest, exceptions, owners, expiry, and every reopening condition.
      - [ ] 5.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 5 Integration Tests section, receipt task, pinning subtask, and Milestone G completion before authorizing Milestone H Phase 1.
