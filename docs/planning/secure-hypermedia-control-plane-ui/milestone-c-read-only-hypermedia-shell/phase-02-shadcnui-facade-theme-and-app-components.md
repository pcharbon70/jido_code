---
id: plan.jido_code_hypermedia_ui_milestone_c_phase_02
parent_plan: plan.jido_code_hypermedia_ui_milestone_c
status: completed
intent: feature
---

# Milestone C Phase 2 - ShadcnUI Facade, Theme, And Application Components

This phase turns the qualified primitive dependency into a JidoCode-owned
design system for factory pages, projection states, provenance, and navigation.

Back to plan: [README](./README.md)

- [x] 2 Phase - Build the accessible application component and theme layer.

  This phase closes HUI-C2 with stable APIs and DOM contracts that later pages
  and Datastar fragments can share without importing upstream details.

  - [x] 2.1 Section - Complete the primitive facade and semantic tokens.

    This section promotes the qualification wrappers into maintained product
    APIs with coherent styling, forms, focus, and accessibility behavior.

    - [x] 2.1.1 Task {#huic-p02-primitives} [repo: jido_code] [after: {#huic-p01-phase-receipt}] - Implement the supported primitive facade catalog.

      This task provides only semantically justified wrappers and resolves all
      upstream/project naming and form-contract collisions.

      - [x] 2.1.1.1 Subtask - Implement supported link/button/input/form/select/checkbox/radio/badge/table/disclosure/dialog/menu/tooltip/toast/skeleton primitives behind `JidoCodeWeb.Components.UI`.
      - [x] 2.1.1.2 Subtask - Preserve `to_form/2`, project `<.input>`, label/help/error association, unique IDs, native submit, global Datastar attributes, slots, and escaped content.
      - [x] 2.1.1.3 Subtask - Define variant/size/state APIs, forbidden ad hoc styling, upstream API isolation, deprecation, and component documentation/examples.
      - [x] 2.1.1.4 Subtask - Add unit/render/accessibility tests and a dependency-diff checklist for each adopted primitive.

    - [x] 2.1.2 Task {#huic-p02-tokens} [repo: jido_code] [after: {#huic-p02-primitives}] - Implement application theme, density, motion, and responsive tokens.

      This task gives factory composites consistent visual meaning without
      encoding semantic state by color alone.

      - [x] 2.1.2.1 Subtask - Define application typography, spacing, layout, density, elevation, border, focus, status, chart, and code/diff tokens over qualified ShadcnUI variables.
      - [x] 2.1.2.2 Subtask - Resolve system/light/dark preference server-first with no flash, safe persistence, CSP compatibility, and synchronized theme attributes.
      - [x] 2.1.2.3 Subtask - Define reduced-motion, forced-colors/high-contrast, RTL, zoom/reflow, touch target, print, and narrow-screen behavior.
      - [x] 2.1.2.4 Subtask - Add deterministic visual/accessibility fixtures and reject raw status colors, inaccessible contrast, or remote font/icon dependencies.

  - [x] 2.2 Section - Build factory shell and navigation composites.

    This section owns the global/project/attempt hierarchy, scope explanation,
    responsive navigation, and reserved-area presentation.

    - [x] 2.2.1 Task {#huic-p02-shell-components} [repo: jido_code] [after: {#huic-p02-tokens}] - Implement application shell, navigation, and context components.

      This task produces stateless HEEx components that render current server-
      authorized navigation without treating visibility as authority.

      - [x] 2.2.1.1 Subtask - Implement skip link, masthead, primary navigation, project switcher, breadcrumbs, attempt context, utility navigation, account/session menu, and responsive disclosure.
      - [x] 2.2.1.2 Subtask - Implement current route/scope/role/assurance/readiness explanations and concealed omission for inaccessible destinations.
      - [x] 2.2.1.3 Subtask - Implement page header, action area, filter/search shell, pagination, empty state, error summary, maintenance/degraded banners, and footer/support metadata.
      - [x] 2.2.1.4 Subtask - Define stable DOM IDs/roots, focus targets, native behavior, and future fragment boundaries without adding Datastar delivery yet.

  - [x] 2.3 Section - Build projection and factory-domain composites.

    This section creates the missing application components ShadcnUI does not
    supply for operational factory truth.

    - [x] 2.3.1 Task {#huic-p02-projection-components} [repo: jido_code] [after: {#huic-p02-shell-components}] - Implement projection state, trust, attention, and collection components.

      This task makes truth, provenance, readiness, truncation, and action need
      understandable before any domain page is composed.

      - [x] 2.3.1.1 Subtask - Implement all ten projection states with revision/freshness/source/as-of, partial/truncated, contradiction, concealed, unavailable, unconfigured, and safe retry semantics.
      - [x] 2.3.1.2 Subtask - Implement trust header, attention card/list, health summary, fleet/project table, attempt summary, lifecycle/outcome rails, budget meter, receipt/evidence link, and readiness badge.
      - [x] 2.3.1.3 Subtask - Implement bounded table/card switching, column priorities, accessible sorting labels, pagination summaries, no-result states, and narrow-screen alternatives.
      - [x] 2.3.1.4 Subtask - Add hostile-content, long-label, missing-field, stale/error, high-count, keyboard, screen-reader, and visual regression fixtures.

  - [x] 2.4 Section - Phase 2 Integration Tests.

    This final section proves the component layer is coherent, accessible,
    native-first, stable for future patches, and isolated from application authority.

    - [x] 2.4.1 Task {#huic-p02-integration} [repo: jido_code] [after: {#huic-p02-projection-components}] - Execute the HUI-C2 component and design-system matrix.

      This task validates representative full compositions rather than only
      isolated primitive snapshots.

      - [x] 2.4.1.1 Subtask - Render shell, forms, navigation, projection states, fleet tables, attempt summaries, overlays, errors, and long/hostile content under all supported themes and layouts.
      - [x] 2.4.1.2 Subtask - Exercise keyboard, screen-reader names/order/status, zoom/reflow, touch, RTL, reduced motion, forced colors, print, and JavaScript-disabled behavior.
      - [x] 2.4.1.3 Subtask - Verify stable unique DOM roots/focus targets, no broad upstream imports, no inline/remote assets, no authority logic, and no accidental LiveView product dependency.
      - [x] 2.4.1.4 Subtask - Run component/a11y/visual/architecture/dependency tests, `mix precommit`, and clean-checkout CI.

    - [x] 2.4.2 Task {#huic-p02-phase-receipt} [repo: jido_code] [after: {#huic-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records HUI-C2 evidence in
      `docs/architecture/hypermedia-ui-milestone-c-phase-02-receipt.md`.

      - [x] 2.4.2.1 Subtask - Keep HUI-C2 merge-pending on unstable DOM/APIs, inaccessible composition, color-only meaning, broken native forms/navigation, upstream leakage, authority in components, or unqualified asset use.
      - [x] 2.4.2.2 Subtask - Record component/catalog/token/asset digests, browser/a11y evidence, exceptions, limitations, and all reopening conditions.
      - [x] 2.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 2 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 3.
