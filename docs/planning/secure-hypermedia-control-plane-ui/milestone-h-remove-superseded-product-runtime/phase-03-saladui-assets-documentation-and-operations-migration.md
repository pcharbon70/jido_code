---
id: plan.jido_code_hypermedia_ui_milestone_h_phase_03
parent_plan: plan.jido_code_hypermedia_ui_milestone_h
status: proposed
intent: feature
---

# Milestone H Phase 3 - SaladUI, Assets, Documentation, And Operations Migration

This phase removes the superseded component/theme/assets layer, reconciles the
remaining asset compiler, and updates all maintained product/developer/operator
documentation and operations to current runtime truth.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Complete UI asset, documentation, and operational migration.

  This phase closes HUI-H3 by leaving one coherent qualified component/asset
  system and support model with no stale implementation instructions.

  - [ ] 3.1 Section - Remove SaladUI and obsolete component/theme code.

    This section deletes manifest-approved old primitives, wrappers, styles,
    examples, and tests only after ShadcnUI facade parity is confirmed.

    - [ ] 3.1.1 Task {#huih-p03-saladui} [repo: jido_code] [after: {#huih-p02-phase-receipt}] - Remove SaladUI consumers and stale UI implementation.

      This task preserves semantic behavior and accessibility evidence through
      the accepted application-owned facade and composites.

      - [ ] 3.1.1.1 Subtask - Remove SaladUI dependencies/imports/wrappers/copied components/helpers, theme variables/styles, examples/stories/docs, tests, aliases, and configuration authorized by the manifest.
      - [ ] 3.1.1.2 Subtask - Replace any residual semantic/a11y behavior through qualified JidoCode components and verify no product template imports upstream or old namespaces directly.
      - [ ] 3.1.1.3 Subtask - Remove obsolete CSS selectors/tokens/icons/fonts/animations/layout hacks and retain only documented application/ShadcnUI token ownership.
      - [ ] 3.1.1.4 Subtask - Regenerate dependency locks/SBOM/licenses/assets and run dead import/selector/template/component/static analysis against production builds.

  - [ ] 3.2 Section - Reconcile JavaScript, CSS, asset compiler, and production delivery.

    This section removes stale client/build paths and either retains Vite for a
    documented exact purpose or migrates it under separately qualified evidence.

    - [ ] 3.2.1 Task {#huih-p03-assets} [repo: jido_code] [after: {#huih-p03-saladui}] - Finalize the app.js/app.css and asset compiler contract.

      This task leaves deterministic locally served assets with minimal CSP,
      cache, deployment, and rollback complexity.

      - [ ] 3.2.1.1 Subtask - Remove obsolete hooks/socket/Vue/LiveView/SaladUI JS/CSS, vendor copies, entry points, build plugins, preloads, source maps, cache keys, CSP allowances, and deployment steps.
      - [ ] 3.2.1.2 Subtask - Retain Vite only for exact app.js/app.css/Datastar/ShadcnUI build consumers with pinned dependencies, deterministic output, documented security/update/rollback ownership.
      - [ ] 3.2.1.3 Subtask - If replacing Vite, perform an independently qualified asset decision and prove output/function/security/accessibility/cache/build/deploy/rollback equivalence before removal.
      - [ ] 3.2.1.4 Subtask - Verify production fingerprints/digests/licenses/compression/MIME/nosniff/cache/CSP, stale-client behavior, offline build inputs, and no remote runtime assets.

  - [ ] 3.3 Section - Rewrite maintained architecture, guides, and operations.

    This section makes current controller/HEEx/Datastar/ShadcnUI/identity/
    stream/command/lens/incident behavior the only maintained implementation story.

    - [ ] 3.3.1 Task {#huih-p03-docs} [repo: jido_code] [after: {#huih-p03-assets}] - Update authoritative architecture and human/agent guidance.

      This task preserves historical context through supersession links while
      removing stale instructions that would recreate old runtime code.

      - [ ] 3.3.1.1 Subtask - Update ADR status, architecture indexes/current-state diagrams, route/component/dependency/asset inventories, specifications, plans/receipts, and migration/retention manifests.
      - [ ] 3.3.1.2 Subtask - Update `AGENTS.md`, contributor/onboarding/local-development/testing/debugging guides, user/developer/admin/security/auditor guides, wiki guidance, and accessibility expectations.
      - [ ] 3.3.1.3 Subtask - Update install/upgrade/deploy/configuration/operations/incident/backup/restore/disaster-recovery/rollback/support/capacity/monitoring/dependency-update runbooks.
      - [ ] 3.3.1.4 Subtask - Remove current-tense LiveView/LiveVue/SaladUI instructions and false capability/readiness claims while preserving links to historical decisions/receipts.

    - [ ] 3.3.2 Task {#huih-p03-ops} [repo: jido_code] [after: {#huih-p03-docs}] - Reconcile operational ownership and clean-room usability.

      This task verifies a new developer/operator can build, run, diagnose,
      deploy, support, recover, and roll back the maintained product.

      - [ ] 3.3.2.1 Subtask - Update dashboards/alerts/SLOs/capacity/health/readiness/log/trace/metric ownership and remove signals tied only to deleted runtime.
      - [ ] 3.3.2.2 Subtask - Update incident escalation, stream/command/identity/graph/wiki/asset failure procedures, evidence retention, support diagnostics, and retained exception review.
      - [ ] 3.3.2.3 Subtask - Run clean-room developer/operator walkthroughs using only maintained docs and record gaps, fixes, time, and outcomes.
      - [ ] 3.3.2.4 Subtask - Update the removal manifest and create `hypermedia-ui-milestone-h-phase-03-receipt.md` in merge-pending state with HUI-H3 evidence.

  - [ ] 3.4 Section - Phase 3 Integration Tests.

    This final section proves one coherent component/asset/runtime/documentation
    architecture remains and can be operated from clean checkout.

    - [ ] 3.4.1 Task {#huih-p03-integration} [repo: jido_code] [after: {#huih-p03-ops}] - Execute the HUI-H3 asset, documentation, and operations matrix.

      This task combines static/production scans, full product regression,
      clean-room workflows, deploy/recovery, and documentation validation.

      - [ ] 3.4.1.1 Subtask - Scan source/dependencies/templates/JS/CSS/assets/bundles/config/tests/docs/deploy outputs for SaladUI and obsolete runtime/asset references, dead imports/selectors, or undocumented Vite/other compiler consumers.
      - [ ] 3.4.1.2 Subtask - Run full visual/semantic/accessibility/native/enhanced product regression with deterministic production assets, themes, CSP/cache/compression, stale clients, and rollback.
      - [ ] 3.4.1.3 Subtask - Run clean-room install/build/test/run/debug/deploy/monitor/incident/backup-restore/rollback and validate all internal/external documentation links and commands.
      - [ ] 3.4.1.4 Subtask - Run dependency/license/architecture/security/a11y/operations suites, `mix precommit`, and clean-checkout CI.

    - [ ] 3.4.2 Task {#huih-p03-phase-receipt} [repo: jido_code] [after: {#huih-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records HUI-H3 evidence in
      `docs/architecture/hypermedia-ui-milestone-h-phase-03-receipt.md`.

      - [ ] 3.4.2.1 Subtask - Keep HUI-H3 merge-pending on old component/asset consumer, inaccessible parity loss, nondeterministic/remote asset, undocumented compiler exception, stale instruction, broken runbook, or failed clean-room workflow.
      - [ ] 3.4.2.2 Subtask - Record exact removal/asset/build/doc/operations/clean-room/rollback evidence, exceptions, owners, expiry, and all reopening conditions.
      - [ ] 3.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 3 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 4.
