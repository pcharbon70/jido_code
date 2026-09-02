---
id: plan.jido_code_hypermedia_ui_milestone_c_phase_01
parent_plan: plan.jido_code_hypermedia_ui_milestone_c
status: proposed
intent: feature
---

# Milestone C Phase 1 - Named Human Session And Scope Foundation

This phase implements named-human authentication and one trusted authority
construction path before any new multi-user product projection is exposed.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Implement secure human sessions, scope construction, and revocation.

  This phase closes HUI-C1 by making controller and future SSE authorization
  consistent with accepted graph capabilities, delegation, and assurance.

  - [ ] 1.1 Section - Implement named account and authenticator foundations.

    This section adds durable account identity and secure authentication
    without conflating humans, agents, services, or the legacy shared operator.

    - [ ] 1.1.1 Task {#huic-p01-accounts} [repo: jido_code] [after: {#huib-p04-phase-receipt}] - Implement the accepted human account and authentication profile.

      This task establishes the minimum production account lifecycle and
      assurance metadata required by the authorization contract.

      - [ ] 1.1.1.1 Subtask - Implement immutable human subject IDs, display identity, account state, authenticators, assurance level, authentication time, recovery state, and audit provenance through the accepted durable authority.
      - [ ] 1.1.1.2 Subtask - Implement account enrollment/bootstrap, sign-in, failed-attempt controls, recovery, disablement, credential rotation, and logout-all with safe responses.
      - [ ] 1.1.1.3 Subtask - Implement phishing-resistant/step-up integration points and explicit unavailable posture where the production authenticator is not configured.
      - [ ] 1.1.1.4 Subtask - Migrate or disable shared-operator browser access without silently upgrading it into a named administrator.

  - [ ] 1.2 Section - Implement browser session lifecycle and security.

    This section provides server-validated sessions whose generation, expiry,
    and assurance can be rechecked by ordinary requests and future streams.

    - [ ] 1.2.1 Task {#huic-p01-sessions} [repo: jido_code] [after: {#huic-p01-accounts}] - Implement session issuance, rotation, expiry, and revocation.

      This task keeps cookies and browser correlation identifiers from becoming
      authority on their own.

      - [ ] 1.2.1.1 Subtask - Issue signed/encrypted cookies containing only bounded references and validate current account/session/generation state server-side on every protected request.
      - [ ] 1.2.1.2 Subtask - Enforce fixation prevention, post-auth rotation, secure/HTTP-only/same-site attributes, hard and idle expiry, authentication age, CSRF, Origin, and safe return locations.
      - [ ] 1.2.1.3 Subtask - Implement session generation changes for logout-all, account disablement, credential events, risk/incident response, and administrative revocation.
      - [ ] 1.2.1.4 Subtask - Record privacy-safe session telemetry and audit without logging cookies, authenticators, protected content, or reusable tokens.

  - [ ] 1.3 Section - Implement trusted scope and authority construction.

    This section centralizes current membership, role explanation, exact grants,
    delegation, assurance, and resource scope for all web handlers.

    - [ ] 1.3.1 Task {#huic-p01-authority} [repo: jido_code] [after: {#huic-p01-sessions}] - Build the trusted controller/stream authority adapter.

      This task prevents routes and future stream handlers from reconstructing
      authority differently or accepting browser-supplied grant fields.

      - [ ] 1.3.1.1 Subtask - Resolve current human subject, tenant, repository/project membership, role labels, exact graph/action grants, delegations, clearance, assurance, policy revision, and session generation.
      - [ ] 1.3.1.2 Subtask - Resolve opaque resource references through authorized registries and keep project, attempt, `InteractionSession`, candidate, wiki preview, and graph scopes distinct.
      - [ ] 1.3.1.3 Subtask - Expose deny-by-default page/query/field/stream/command/export decisions with concealment/redaction and safe reason codes.
      - [ ] 1.3.1.4 Subtask - Add reusable reauthorization hooks for pre-query, post-shaping, pre-response, future pre-patch, command admission, and download retrieval.

    - [ ] 1.3.2 Task {#huic-p01-membership} [repo: jido_code] [after: {#huic-p01-authority}] - Implement membership, delegation, restricted-area, and revocation reads.

      This task makes role-scoped navigation explainable while exact grants
      remain authoritative.

      - [ ] 1.3.2.1 Subtask - Implement bounded current membership/delegation/role explanations and administrative mutation only through already accepted governed interfaces.
      - [ ] 1.3.2.2 Subtask - Define route groups for developer, reviewer, operations, security, cost, knowledge, and administration areas with independent field/query checks.
      - [ ] 1.3.2.3 Subtask - Publish session/role/delegation/project/tenant/graph revocation notifications for request caches and future stream coordinators.
      - [ ] 1.3.2.4 Subtask - Preserve concealed-not-found behavior and prevent navigation, disabled controls, URLs, cookie values, or roles alone from granting access.

  - [ ] 1.4 Section - Phase 1 Integration Tests.

    This final section proves named identity and authority behave correctly
    across real sessions, scopes, revocation, and hostile browser inputs.

    - [ ] 1.4.1 Task {#huic-p01-integration} [repo: jido_code] [after: {#huic-p01-membership}] - Execute the HUI-C1 identity, session, and authorization matrix.

      This task closes identity only against the real accepted stores/adapters
      and concurrent session conditions.

      - [ ] 1.4.1.1 Subtask - Exercise account bootstrap/sign-in/recovery/disable, session fixation/rotation/idle/hard expiry/logout-all, step-up age, CSRF/Origin, and safe redirect cases.
      - [ ] 1.4.1.2 Subtask - Exercise all role explanations, exact grants, membership/delegation expiry/revocation, field redaction, concealed resources, and restricted route groups.
      - [ ] 1.4.1.3 Subtask - Exercise copied/tampered refs, cross-tenant/project/attempt/interaction/preview/graph probes, several users/tabs, stale session generations, and concurrent revocation.
      - [ ] 1.4.1.4 Subtask - Run identity/security/privacy/architecture suites, `mix precommit`, and clean-checkout CI with the production adapter or explicit unconfigured posture.

    - [ ] 1.4.2 Task {#huic-p01-phase-receipt} [repo: jido_code] [after: {#huic-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records HUI-C1 evidence in
      `docs/architecture/hypermedia-ui-milestone-c-phase-01-receipt.md`.

      - [ ] 1.4.2.1 Subtask - Keep HUI-C1 merge-pending on shared identity, fixation/revocation failure, inconsistent authority construction, implicit role grant, cross-scope disclosure, or unavailable authenticator presented as ready.
      - [ ] 1.4.2.2 Subtask - Record identity/session/policy versions, adapter/config fixtures, security evidence, exceptions, limitations, and every reopening condition.
      - [ ] 1.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 1 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 2.
