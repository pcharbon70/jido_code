---
id: plan.jido_code_hypermedia_ui_milestone_a_phase_02
parent_plan: plan.jido_code_hypermedia_ui_milestone_a
status: proposed
intent: feature
---

# Milestone A Phase 2 - Human Identity And Authorization Authority

This phase accepts or narrows the named-human security model before any
multi-user controller, stream, command, review, cost, or incident surface is
implemented.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Establish named-human identity and exact scoped authorization authority.

  This phase closes HUI-A2 with one deny-by-default decision model shared by
  ordinary requests, fragments, streams, commands, approvals, exports, and
  revocation.

  - [x] 2.1 Section - Accept the identity, assurance, and session contract.

    This section defines who a human principal is and how authentication state
    is established, renewed, stepped up, revoked, and audited.

    - [x] 2.1.1 Task {#huia-p02-identity} [repo: jido_code] [after: {#huia-p01-phase-receipt}] - Ratify named account and authentication assurance semantics.

      This task replaces shared-operator assumptions with accountable human
      identity while keeping service and agent principals distinct.

      - [x] 2.1.1.1 Subtask - Define human account, authenticator, session, assurance level, authentication age, recovery, disablement, and audit identities with immutable subject references.
      - [x] 2.1.1.2 Subtask - Define phishing-resistant and step-up requirements by action risk, environment, data classification, and incident posture.
      - [x] 2.1.1.3 Subtask - Define session fixation prevention, rotation, hard/idle expiry, cookie/security attributes, logout-all, account disable, and generation-based revocation.
      - [x] 2.1.1.4 Subtask - Define bootstrap, break-glass, recovery, and identity-provider outage behavior without restoring a shared omnipotent operator.

  - [x] 2.2 Section - Freeze scope, role, delegation, and capability semantics.

    This section makes roles understandable without allowing them to replace
    exact graph capabilities or cross project and tenant boundaries.

    - [x] 2.2.1 Task {#huia-p02-scope} [repo: jido_code] [after: {#huia-p02-identity}] - Ratify the trusted authority-builder inputs and outputs.

      This task defines the single server-owned mapping from authenticated
      identity and requested resource to exact current authority.

      - [x] 2.2.1.1 Subtask - Define tenant, repository/project membership, role, exact graph/action grants, delegation, clearance, environment, lifecycle, fence, and assurance inputs.
      - [x] 2.2.1.2 Subtask - Define observer, developer, maintainer, verifier, operator, security auditor, administrator, knowledge steward, and cost observer as navigation/explanation roles only.
      - [x] 2.2.1.3 Subtask - Define delegation issuer, subject, resources/actions, graph families, environment, validity, revision, attenuation, revocation, and non-transitive defaults.
      - [x] 2.2.1.4 Subtask - Define deny-by-default intersection, concealment, field redaction, decision reason, policy revision, audit correlation, and safe error output.

    - [x] 2.2.2 Task {#huia-p02-authz-matrix} [repo: jido_code] [after: {#huia-p02-scope}] - Publish the route, field, stream, command, and export authorization matrix.

      This task makes every product operation independently reviewable and
      forbids navigation visibility or browser state from acting as a grant.

      - [x] 2.2.2.1 Subtask - Enumerate page/fragment/query/field/search/detail/stream/patch/export and command/approval/incident actions by resource and role explanation.
      - [x] 2.2.2.2 Subtask - Bind every operation to exact grants, current membership/delegation, assurance, resource scope, classification, environment, lifecycle, revision, and fence where applicable.
      - [x] 2.2.2.3 Subtask - Define concealed-not-found, redacted, denied, unavailable, revoked, and step-up-required outcomes without cross-scope inference.
      - [x] 2.2.2.4 Subtask - Define reauthorization points before response start, query execution, field shaping, each patch, command admission, approval commit, and export retrieval.

  - [x] 2.3 Section - Define approval separation and live revocation.

    This section prevents stale or self-approved high-risk effects and ensures
    open browser connections cannot outlive changed authority.

    - [x] 2.3.1 Task {#huia-p02-approval-revocation} [repo: jido_code] [after: {#huia-p02-authz-matrix}] - Ratify separation-of-duty and revocation state machines.

      This task defines canonical action-bound approvals and terminal browser
      behavior under account, session, role, delegation, and scope change.

      - [x] 2.3.1.1 Subtask - Define maker/checker, eligible approver, self-approval prohibition, quorum, canonical action digest, evidence binding, expiry, and stale-input invalidation.
      - [x] 2.3.1.2 Subtask - Define concurrent approval/command compare-and-set outcomes and canonical winner/loser receipts.
      - [x] 2.3.1.3 Subtask - Define generation/revision events for account, session, role, delegation, project, tenant, graph, and incident revocation.
      - [x] 2.3.1.4 Subtask - Define terminal stream close, protected-fragment replacement, reconnect suppression, download invalidation, and audit behavior after revocation.

  - [ ] 2.4 Section - Phase 2 Integration Tests.

    This final section proves the proposed security model is complete,
    non-escalating, and compatible with accepted graph and command authority.

    - [x] 2.4.1 Task {#huia-p02-integration} [repo: jido_code] [after: {#huia-p02-approval-revocation}] - Execute the HUI-A2 policy and authority model matrix.

      This task validates normative examples and hostile counterexamples before
      implementation code may rely on the contract.

      - [x] 2.4.1.1 Subtask - Trace representative pages, fields, streams, patches, commands, approvals, incidents, and exports from named principal to exact graph/gateway decision.
      - [x] 2.4.1.2 Subtask - Exercise cross-tenant/project/attempt/interaction/graph probes, copied opaque refs, role union attempts, expired delegation, stale step-up, and concealed resources in contract fixtures.
      - [x] 2.4.1.3 Subtask - Exercise two-human approvals, concurrent transitions, session/role/delegation revocation, open streams, reconnect, and export retrieval in deterministic state models.
      - [x] 2.4.1.4 Subtask - Run architecture/spec consistency, threat-model traceability, documentation validation, `mix precommit`, and clean-checkout CI.

    - [ ] 2.4.2 Task {#huia-p02-phase-receipt} [repo: jido_code] [after: {#huia-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records HUI-A2 evidence in
      `docs/architecture/hypermedia-ui-milestone-a-phase-02-receipt.md`.

      - [x] 2.4.2.1 Subtask - Keep HUI-A2 merge-pending on shared-human identity, implicit role union, missing operation authorization, stale approval, incomplete revocation, or a widened graph grant.
      - [x] 2.4.2.2 Subtask - Record exact decision tables, fixtures, reviewers, unresolved risks, limitations, and all reopening conditions.
      - [ ] 2.4.2.3 Subtask - Record the full merge SHA/date and pin the merged candidate; check the phase, Phase 2 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 3.
