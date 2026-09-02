---
id: plan.jido_code_hypermedia_ui_milestone_g
status: proposed
intent: feature
milestone: G
program: program.jido_code_secure_hypermedia_control_plane_ui
source:
  - docs/architecture/ui-security-privacy-and-threat-model.md
  - docs/architecture/incident-control-plane-contract.md
  - docs/architecture/ui-accessibility-usability-and-release-qualification.md
  - docs/architecture/hypermedia-runtime-migration-and-rollback.md
---

# Milestone G Plan - Security And Release Qualification

This five-phase plan qualifies the complete control plane against its threat
model, incident response contract, WCAG target, assistive technologies,
role-centered usability scenarios, production topology, resource limits,
recovery, and rollback. It accepts an exact release candidate before any
superseded runtime code may be removed.

Back to program: [Secure Hypermedia Control Plane UI](../README.md)

## Goal

Close program Gate HUI7 with reproducible evidence that named identity,
authorization, live revocation, separation of duty, streams, commands,
approvals, lenses, wiki/accounting, incidents, accessibility, usability,
operations, and rollback work together under hostile and failed conditions.

## Gate And Phase Mapping

| Phase gate | Required result | Phase |
|---|---|---|
| HUI-G1 | Every threat has implemented prevention/detection/response/evidence; hostile identity, authorization, request, rendering, stream, command, cache, inference, exhaustion, and supply-chain suites pass | [Phase 1](./phase-01-threat-model-controls-and-security-evidence.md) |
| HUI-G2 | Incident resources, timelines, protected evidence, accepted actions, step-up/SoD, receipts, runbooks, and drills are production-qualified | [Phase 2](./phase-02-incident-resources-actions-and-runbooks.md) |
| HUI-G3 | WCAG 2.2 AA and supported browser/assistive-technology evidence covers all critical native/live/read/control/lens/incident workflows | [Phase 3](./phase-03-accessibility-and-assistive-technology-qualification.md) |
| HUI-G4 | Role usability thresholds, production topology, load/soak/fault/deploy behavior, observability, install/upgrade, and rollback rehearsal pass | [Phase 4](./phase-04-role-usability-production-operations-and-rollback.md) |
| HUI-G5 / HUI7 | Independent review, exact artifact/config evidence, residual-risk decisions, clean installation, full regression, and merged-candidate closure accept the release | [Phase 5](./phase-05-release-candidate-acceptance.md) |

## Phase Order

1. [Phase 1 - Threat Model Controls And Security Evidence](./phase-01-threat-model-controls-and-security-evidence.md)
2. [Phase 2 - Incident Resources, Actions, And Runbooks](./phase-02-incident-resources-actions-and-runbooks.md)
3. [Phase 3 - Accessibility And Assistive-Technology Qualification](./phase-03-accessibility-and-assistive-technology-qualification.md)
4. [Phase 4 - Role Usability, Production Operations, And Rollback](./phase-04-role-usability-production-operations-and-rollback.md)
5. [Phase 5 - Release Candidate Acceptance](./phase-05-release-candidate-acceptance.md)

Receipts use
`docs/architecture/hypermedia-ui-milestone-g-phase-01-receipt.md` through
`hypermedia-ui-milestone-g-phase-05-receipt.md`. The final receipt closes HUI7
and alone authorizes destructive legacy removal in Milestone H.

## Parallelism And Independence

Threat testing, accessibility review, role usability, and operations
qualification may use independent sessions against the same immutable
candidate and evidence manifest. Fixes invalidate affected evidence and require
reruns; sessions cannot silently qualify different commits/configurations.
Security-sensitive findings remain access-controlled, while release gate
summaries and residual-risk decisions remain auditable.

## Completion Definition

Milestone G completes when no open critical/high release risk remains; all
critical workflows meet accessibility and usability thresholds; real adapters,
supported browsers/AT/proxy, capacity, faults, deploys, installation, upgrade,
and rollback pass; incidents can be detected/contained/recovered safely; and a
clean merged-candidate receipt binds exact artifacts, evidence, exceptions,
owners, and reopening conditions.
