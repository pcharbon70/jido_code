---
id: plan.jido_code_hypermedia_ui_milestone_c_phase_03
parent_plan: plan.jido_code_hypermedia_ui_milestone_c
status: proposed
intent: feature
---

# Milestone C Phase 3 - Authenticated Shell Routes And Native Navigation

This phase implements durable ordinary routes and controller-rendered HEEx
pages for the global, project, attempt, and restricted-area shell.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Deliver the authenticated native-first product shell and route hierarchy.

  This phase closes HUI-C3 with useful navigation and error handling before
  live fragments or commands are added.

  - [x] 3.1 Section - Implement explicit authenticated route groups.

    This section gives every page an owned controller/action/template,
    authority decision, canonical URL, and safe unavailable behavior.

    - [x] 3.1.1 Task {#huic-p03-routes} [repo: jido_code] [after: {#huic-p02-phase-receipt}] - Implement factory, project, attempt, and restricted-area routes.

      This task builds ordinary Phoenix route/controller boundaries without
      LiveView routing or catch-all action dispatch.

      - [x] 3.1.1.1 Subtask - Add authenticated routes for home/attention, fleet, project overview/attempts/wiki/dependencies, attempt workspace, reviews, costs, knowledge lenses, operations, security/incidents, governance, and account/session pages.
      - [x] 3.1.1.2 Subtask - Use opaque bounded resource refs and trusted resolution; preserve conceptual repository/project alias and distinct attempt/interaction/candidate/preview identities.
      - [x] 3.1.1.3 Subtask - Apply exact route/action authorization, assurance, concealment, no-store/referrer policy, safe errors, and restricted-area separation on every handler.
      - [x] 3.1.1.4 Subtask - Add canonical URL, redirect, trailing-slash/query normalization, deep-link, pagination/filter, not-found, forbidden/concealed, maintenance, and unconfigured behavior.

  - [x] 3.2 Section - Compose full-page layouts and scope-aware navigation.

    This section renders the component shell with current authorized context,
    breadcrumbs, status, and meaningful native interactions.

    - [x] 3.2.1 Task {#huic-p03-layout} [repo: jido_code] [after: {#huic-p03-routes}] - Implement controller layout/view-model composition.

      This task keeps templates presentation-only and derives all navigation
      and context from server-owned view models.

      - [x] 3.2.1.1 Subtask - Build page view models containing current principal summary, assurance, route, authorized navigation, project/attempt context, readiness, freshness, notices, and support metadata.
      - [x] 3.2.1.2 Subtask - Render shell, skip/landmark structure, page headers, breadcrumbs, responsive navigation, account/session controls, and reserved-area cues through application components.
      - [x] 3.2.1.3 Subtask - Implement project switching and native filter/search/pagination forms as GET-safe bounded intent with scope reset and no authority fields.
      - [x] 3.2.1.4 Subtask - Preserve focus, page title, current-location semantics, error summaries, flash ownership, back/forward, reload, and bookmark behavior.

  - [x] 3.3 Section - Implement native authentication and session workflows.

    This section makes essential account/session behavior usable without
    JavaScript and consistent with step-up and revocation rules.

    - [x] 3.3.1 Task {#huic-p03-session-ui} [repo: jido_code] [after: {#huic-p03-layout}] - Implement sign-in, sign-out, step-up, recovery, and session-management pages.

      This task exposes only the configured identity capability and avoids
      leaking account existence or security state.

      - [x] 3.3.1.1 Subtask - Implement native forms with `to_form/2`, CSRF, rate/attempt bounds, safe return targets, generic errors, password-manager/autocomplete semantics, and no secrets in logs/URLs.
      - [x] 3.3.1.2 Subtask - Implement current session/assurance display, session list/revocation where accepted, logout-current/all, account disabled, expired session, and step-up-required flows.
      - [x] 3.3.1.3 Subtask - Implement configured/unconfigured identity-provider and recovery posture with operator guidance that reveals no protected implementation detail.
      - [x] 3.3.1.4 Subtask - Verify post-auth/session rotation, focus/error announcements, back-button/cache behavior, and concurrent logout/revocation.

  - [ ] 3.4 Section - Phase 3 Integration Tests.

    This final section proves route ownership, native navigation, scope
    isolation, session flows, and responsive shell behavior end to end.

    - [ ] 3.4.1 Task {#huic-p03-integration} [repo: jido_code] [after: {#huic-p03-session-ui}] - Execute the HUI-C3 route, navigation, and native-browser matrix.

      This task uses ordinary HTTP/browser behavior with JavaScript disabled as
      the mandatory baseline.

      - [ ] 3.4.1.1 Subtask - Exercise every route group, canonical/deep link, redirect, project switch, search/filter/page, reload, back/forward, error, maintenance, and unconfigured path.
      - [ ] 3.4.1.2 Subtask - Exercise anonymous/authenticated/step-up/expired/revoked sessions, role areas, concealed resources, copied refs, cross-project/tenant probes, and several tabs/users.
      - [ ] 3.4.1.3 Subtask - Exercise keyboard, screen-reader landmark/title/focus/error behavior, zoom/reflow, touch, RTL, themes, and narrow layouts with no JavaScript.
      - [ ] 3.4.1.4 Subtask - Run controller/template/router/security/accessibility/architecture suites, `mix precommit`, and clean-checkout CI.

    - [ ] 3.4.2 Task {#huic-p03-phase-receipt} [repo: jido_code] [after: {#huic-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records HUI-C3 evidence in
      `docs/architecture/hypermedia-ui-milestone-c-phase-03-receipt.md`.

      - [ ] 3.4.2.1 Subtask - Keep HUI-C3 merge-pending on unowned/catch-all route, authorization mismatch, broken native workflow, unsafe redirect/cache/referrer, identity leak, inaccessible navigation, or cross-scope state.
      - [ ] 3.4.2.2 Subtask - Record exact route/view-model/browser/config evidence, exceptions, limitations, and every reopening condition.
      - [ ] 3.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 3 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 4.
