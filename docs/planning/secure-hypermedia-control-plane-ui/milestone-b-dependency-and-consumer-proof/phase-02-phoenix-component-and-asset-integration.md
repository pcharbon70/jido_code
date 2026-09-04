---
id: plan.jido_code_hypermedia_ui_milestone_b_phase_02
parent_plan: plan.jido_code_hypermedia_ui_milestone_b
status: proposed
intent: feature
---

# Milestone B Phase 2 - Phoenix Component And Asset Integration

This phase resolves package constraints and proves deterministic server
component, CSS, theme, and browser-asset integration without product runtime use.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Integrate the pinned component and asset inputs at compile/build boundaries.

  This phase closes HUI-B2 with one clean dependency graph, local asset path,
  narrow facade, and CSP-compatible deterministic build.

  - [x] 2.1 Section - Resolve Phoenix.Component and Hex dependency constraints.

    This section proves the chosen ShadcnUI/Dstar combination compiles with the
    application without adding LiveView routes, processes, or state ownership.

    - [x] 2.1.1 Task {#huib-p02-hex} [repo: jido_code] [after: {#huib-p01-phase-receipt}] - Resolve and pin the qualified Hex graph.

      This task explicitly handles the `phoenix_live_view` constraint as a
      component-library dependency rather than hiding it as product runtime.

      - [x] 2.1.1.1 Subtask - Select the qualified Phoenix/Phoenix.HTML/Phoenix.LiveView/ShadcnUI/Dstar constraint set from the HUI-B1 ledger and document each resolution.
      - [x] 2.1.1.2 Subtask - Update dependency declarations and lock checksums deterministically; reject implicit overrides, unreviewed forks, or broad floating constraints.
      - [x] 2.1.1.3 Subtask - Prove compilation and release startup include no LiveView product socket, route, process, event, stream, or state consumer created by the dependency change.
      - [x] 2.1.1.4 Subtask - Record compile-only/runtime application loading, release footprint, transitive modules, upgrade/rollback, and exception posture.

  - [x] 2.2 Section - Establish the component facade and theme contract.

    This section contains upstream primitives behind JidoCode-owned APIs and
    resolves naming, form, accessibility, and token collisions centrally.

    - [x] 2.2.1 Task {#huib-p02-facade} [repo: jido_code] [after: {#huib-p02-hex}] - Build the minimal qualification-only component facade.

      This task proves primitive consumption without implementing product
      composites reserved for Milestone C.

      - [x] 2.2.1.1 Subtask - Introduce narrow wrappers/import aliases for representative button, input/form, link, badge, table shell, disclosure, dialog, and status primitives.
      - [x] 2.2.1.2 Subtask - Preserve `Phoenix.Component.to_form/2`, `<.form>`, project `<.input>`, slots, global attributes, HEEx escaping, unique DOM IDs, and no inline script behavior.
      - [x] 2.2.1.3 Subtask - Resolve function/attribute/class collisions and prove product modules need not broadly `use ShadcnUI` or know upstream namespaces.
      - [x] 2.2.1.4 Subtask - Define wrapper versioning, upstream-diff review, deprecation, component test, accessibility evidence, and escape-hatch policy.

    - [x] 2.2.2 Task {#huib-p02-theme} [repo: jido_code] [after: {#huib-p02-facade}] - Integrate controlled CSS variables and theme resolution.

      This task maps ShadcnUI tokens into the existing asset contract without
      remote styles or runtime-generated unsafe CSS.

      - [x] 2.2.2.1 Subtask - Map surface/color/focus/radius/motion variables and resolved light/dark theme attributes while keeping application typography/spacing ownership.
      - [x] 2.2.2.2 Subtask - Verify contrast, focus visibility, reduced motion, forced colors, RTL, zoom/reflow, print, and no-JS rendering for representative primitives.
      - [x] 2.2.2.3 Subtask - Preserve Tailwind v4 source/import conventions, avoid `@apply`, and keep all CSS in controlled local bundles.
      - [x] 2.2.2.4 Subtask - Record theme migration, cache invalidation, stale asset behavior, rollback, and visual-regression fixtures.

  - [ ] 2.3 Section - Build the pinned Datastar asset pipeline.

    This section produces one locally served browser runtime with exact
    integrity, CSP, caching, and reproducible-build behavior.

    - [ ] 2.3.1 Task {#huib-p02-assets} [repo: jido_code] [after: {#huib-p02-theme}] - Integrate and verify the selected Datastar bundle.

      This task does not yet enable product enhancement; it proves the asset
      can be built, served, and constrained safely.

      - [ ] 2.3.1.1 Subtask - Vendor or build the exact selected Datastar source through the approved app.js pipeline with source/digest/license metadata and no CDN fallback.
      - [ ] 2.3.1.2 Subtask - Configure production fingerprinting, manifest lookup, cache headers, compression, MIME/nosniff, source-map policy, and stale-client compatibility.
      - [ ] 2.3.1.3 Subtask - Configure HTTP CSP nonce/hash mode, static Datastar expressions, no Dstar Scripts, no unsafe inline/eval allowance, and no third-party network dependency.
      - [ ] 2.3.1.4 Subtask - Add deterministic build and drift checks comparing source, bundle, manifest, production release, and HUI-B1 digest records.

  - [ ] 2.4 Section - Phase 2 Integration Tests.

    This final section proves the exact dependency and asset combination can be
    reproduced without introducing prohibited product runtime consumers.

    - [ ] 2.4.1 Task {#huib-p02-integration} [repo: jido_code] [after: {#huib-p02-assets}] - Execute the HUI-B2 compile, facade, theme, and asset matrix.

      This task covers clean install/build/release plus hostile drift and stale
      client conditions.

      - [ ] 2.4.1.1 Subtask - Run clean dependency resolution, compile, release, SBOM/license scan, supervision/router audit, and rollback against the pinned locks.
      - [ ] 2.4.1.2 Subtask - Render representative facade components/forms/slots/global Datastar attributes under all themes, accessibility modes, no-JS, and hostile content.
      - [ ] 2.4.1.3 Subtask - Build and serve production assets under CSP, fingerprint/cache/compression, digest mismatch, missing asset, stale manifest, and rollback cases.
      - [ ] 2.4.1.4 Subtask - Run architecture/dependency/browser smoke tests, `mix precommit`, and clean-checkout CI.

    - [ ] 2.4.2 Task {#huib-p02-phase-receipt} [repo: jido_code] [after: {#huib-p02-integration}] - Publish and pin the Phase 2 receipt.

      This task records HUI-B2 evidence in
      `docs/architecture/hypermedia-ui-milestone-b-phase-02-receipt.md`.

      - [ ] 2.4.2.1 Subtask - Keep HUI-B2 merge-pending on unresolved constraints, unpinned locks/assets, broad imports, CSP weakening, remote runtime, inaccessible primitives, nondeterministic build, or LiveView product consumption.
      - [ ] 2.4.2.2 Subtask - Record exact locks/assets/config/build outputs, tests, exceptions, limitations, and all reopening conditions.
      - [ ] 2.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 2 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 3.
