---
id: plan.jido_code_secure_hypermedia_control_plane_ui_phase_02
parent_plan: plan.jido_code_secure_hypermedia_control_plane_ui
status: proposed
intent: feature
---

# Secure Hypermedia Control Plane UI Phase 2 — Dependency, Asset, And Consumer Proof

This phase implements Milestone B and closes HUI2 by qualifying immutable
ShadcnUI, Dstar, and Datastar inputs plus a real isolated Phoenix consumer
before any production route depends on them.

Back to plan: [README](./README.md)

- [ ] 2 Phase — Prove the exact UI and hypermedia dependency tuple.

  This phase establishes supply-chain, compatibility, browser, CSP, CSRF,
  component, asset, fragment, stream, reconnect, and fallback evidence.

  - [ ] 2.1 Section — Qualify immutable dependency and asset provenance.

    This section permits no mutable branch, ambiguous license, unrecorded
    browser bundle, or unresolved Phoenix constraint.

    - [ ] 2.1.1 Task {#hui-p02-shadcn-provenance} [repo: jido_code] [after: {#hui-p01-phase-receipt}] — Close the ShadcnUI adoption record.

      This task determines whether the selected Phoenix component source is
      legally, technically, and operationally admissible.

      - [ ] 2.1.1.1 Subtask — Reconcile canonical `pcharbon70/shadcn_ui` namespace with package metadata, source URLs, and documentation.
      - [ ] 2.1.1.2 Subtask — Record exact commit/tag, source/archive/CSS digests, license and usage authority, CI result, component contract, and release status.
      - [ ] 2.1.1.3 Subtask — Resolve the `phoenix_live_view ~> 1.1` versus ShadcnUI `~> 1.2` constraint without enabling LiveView product runtime.
      - [ ] 2.1.1.4 Subtask — Record manual accessibility and native browser capability status and either close or explicitly accept each residual risk.

    - [ ] 2.1.2 Task {#hui-p02-datastar-provenance} [repo: jido_code] [after: {#hui-p02-shadcn-provenance}] — Close the Dstar and Datastar adoption records.

      This task pins the server package and browser runtime as separate
      reproducible dependencies with compatible protocol behavior.

      - [ ] 2.1.2.1 Subtask — Record Dstar version/tag/commit/archive digest/license and supported Phoenix/Plug/Elixir versions.
      - [ ] 2.1.2.2 Subtask — Record Datastar version/tag/commit/bundle filename/digest/license, CSP mode, and local import/build path.
      - [ ] 2.1.2.3 Subtask — Pin request, signal, SSE, retry/takeover, page callback, StreamRegistry, and error/debug behaviors used by JidoCode.
      - [ ] 2.1.2.4 Subtask — Reject versionless docs or a Dstar example version as a substitute for exact browser-client compatibility evidence.

  - [ ] 2.2 Section — Build the isolated ShadcnUI and Datastar consumer.

    This section exercises real components and transport without wiring any
    production Factory/Knowledge command or durable graph mutation.

    - [ ] 2.2.1 Task {#hui-p02-component-consumer} [repo: jido_code] [after: {#hui-p02-datastar-provenance}] — Implement the JidoCode UI facade consumer fixture.

      This task proves narrow imports, forms, attrs/slots, CSS, themes, native
      semantics, and overlay patch boundaries.

      - [ ] 2.2.1.1 Subtask — Add pinned dependency and exact compiled CSS to the controlled local asset build while preserving Tailwind v4 import/source syntax.
      - [ ] 2.2.1.2 Subtask — Add narrow facade wrappers that avoid input/button collisions and preserve `to_form` and project `<.input>` semantics.
      - [ ] 2.2.1.3 Subtask — Map qualified color/surface/focus/radius/motion tokens, keep type/spacing app-owned, and synchronize resolved light/dark theme attrs.
      - [ ] 2.2.1.4 Subtask — Prove exact Datastar attribute forwarding and stable child/sibling patching while Dialog/Popover/Drawer/focus remain intact.

    - [ ] 2.2.2 Task {#hui-p02-hypermedia-consumer} [repo: jido_code] [after: {#hui-p02-component-consumer}] — Implement the isolated Dstar/Datastar protocol fixture.

      This task proves the explicit handler boundary, native fallback, bounded
      signals, CSP/CSRF, SSE, reconnect, expiry, and cleanup.

      - [ ] 2.2.2.1 Subtask — Render one authenticated HEEx page with native form/redirect fallback and a Datastar-enhanced bounded request.
      - [ ] 2.2.2.2 Subtask — Prove authorization/CSRF/rate limits before `Dstar.start`, closed event names, static expressions, and production debug/script prohibition.
      - [ ] 2.2.2.3 Subtask — Exercise patch/nudge/remove, initial snapshot, several tabs, takeover, bounded retry, disconnect/reconnect, hard expiry, revocation, and terminal close.
      - [ ] 2.2.2.4 Subtask — Exercise CSP HTTP nonce headers, local bundle, Origin/Fetch Metadata, no-store/referrer/log policy, and no token in URL/signals.

  - [ ] 2.3 Section — Lock dependency and consumer architecture fitness.

    This section prevents later product work from bypassing the qualified
    tuple, facade, assets, handler, or security boundaries.

    - [ ] 2.3.1 Task {#hui-p02-fitness} [repo: jido_code] [after: {#hui-p02-hypermedia-consumer}] — Enforce immutable dependency and runtime constraints.

      This task turns consumer conclusions into automated build and source
      checks.

      - [ ] 2.3.1.1 Subtask — Reject unpinned ShadcnUI/Dstar/Datastar sources, changed asset digests, CDNs/external scripts/styles, and unknown bundle imports.
      - [ ] 2.3.1.2 Subtask — Reject broad ShadcnUI imports, facade bypass, component name collisions, and forbidden semantic relabeling.
      - [ ] 2.3.1.3 Subtask — Reject Dstar Scripts, production debug errors, unallowlisted dispatch, LiveView route/process additions, and unbounded retry/stream defaults.
      - [ ] 2.3.1.4 Subtask — Create `hypermedia-ui-phase-02-receipt.md` in merge-pending state with Gate HUI2 evidence fields and reopening conditions.

  - [ ] 2.4 Section — Phase 2 Integration Tests.

    This final section proves the exact dependency tuple and consumer behavior
    across build, browser, security, accessibility, and failure boundaries.

    - [ ] 2.4.1 Task {#hui-p02-integration} [repo: jido_code] [after: {#hui-p02-fitness}] — Execute the HUI2 supply-chain and consumer matrix.

      This task keeps all production routes unchanged while proving the
      selected primitives and transport can meet the target contract.

      - [ ] 2.4.1.1 Subtask — Rebuild from a clean dependency/cache state and verify exact dependency and asset digests plus deterministic `app.js`/`app.css` output.
      - [ ] 2.4.1.2 Subtask — Run rendered component/form/theme/overlay, CSS-disabled/no-script, browser capability, keyboard, screen reader, zoom, touch, RTL, forced-colors, and reduced-motion fixtures.
      - [ ] 2.4.1.3 Subtask — Run CSRF/CSP/Origin/signal/injection, SSE loss/reconnect/takeover/revocation/backpressure/cleanup, proxy/HTTP2, and exception-redaction fixtures.
      - [ ] 2.4.1.4 Subtask — Run architecture checks, dependency audit, `mix precommit`, and clean-checkout CI.

    - [ ] 2.4.2 Task {#hui-p02-phase-receipt} [repo: jido_code] [after: {#hui-p02-integration}] — Publish and pin the Phase 2 receipt.

      This task records Gate HUI2 evidence and authorizes production shell work
      only from the merged immutable tuple.

      - [ ] 2.4.2.1 Subtask — Keep HUI2 merge-pending on any provenance/license/CI/version/browser/accessibility/CSP/CSRF/stream/fallback blocker.
      - [ ] 2.4.2.2 Subtask — Record the full implementation merge SHA/date and accepted dependency, asset, consumer, and risk evidence without weakening reopening conditions.
      - [ ] 2.4.2.3 Subtask — Pin the merged candidate commit and check the phase, Phase 2 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 3.
