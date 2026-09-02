---
id: plan.jido_code_hypermedia_ui_milestone_b_phase_04
parent_plan: plan.jido_code_hypermedia_ui_milestone_b
status: proposed
intent: feature
---

# Milestone B Phase 4 - Dependency, Consumer, And Architecture Qualification

This phase converts the spike into durable dependency fitness checks and closes
HUI2 at a reproducible clean merged candidate without shipping product routes.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Qualify and govern the exact dependency/consumer combination.

  This phase closes HUI-B4 and HUI2 by ensuring future drift fails before it
  can enter Milestone C product work.

  - [ ] 4.1 Section - Install dependency, asset, and runtime fitness checks.

    This section verifies immutable provenance and rejects forbidden consumers
    on every relevant change.

    - [ ] 4.1.1 Task {#huib-p04-fitness} [repo: jido_code] [after: {#huib-p03-phase-receipt}] - Enforce dependency and asset allowlists with consumer audits.

      This task makes the HUI-B1/B2 manifests executable CI inputs.

      - [ ] 4.1.1.1 Subtask - Verify exact Hex/npm/source versions, checksums, licenses, source commits, browser bundle digests, asset manifests, SBOM entries, and approved consumers.
      - [ ] 4.1.1.2 Subtask - Reject mutable URLs/tags, CDN imports, unreviewed dependency overrides/forks, unexpected transitive applications, broad ShadcnUI imports, and unapproved network/build steps.
      - [ ] 4.1.1.3 Subtask - Reject LiveView product routes/processes/events/streams, LiveVue/Vue, SaladUI additions, Dstar Scripts, inline/eval CSP weakening, and client-authoritative state patterns.
      - [ ] 4.1.1.4 Subtask - Add deterministic update workflow requiring renewed provenance, license, advisory, consumer, browser, accessibility, and rollback evidence.

  - [ ] 4.2 Section - Complete upstream and application qualification evidence.

    This section closes known ShadcnUI and Datastar/Dstar risks with current,
    reproducible evidence and explicit residual-risk ownership.

    - [ ] 4.2.1 Task {#huib-p04-qualification} [repo: jido_code] [after: {#huib-p04-fitness}] - Run component, protocol, browser, accessibility, and security qualification.

      This task promotes only the exact evidence-backed combination for product
      consumption.

      - [ ] 4.2.1.1 Subtask - Run upstream/downstream unit and integration suites, compile warnings, static analysis, dependency/advisory/license scans, reproducible builds, and release startup.
      - [ ] 4.2.1.2 Subtask - Run the full native/enhanced consumer protocol matrix under production CSP/assets, supported browsers, HTTP/2/reverse proxy, offline/stale client, and restart conditions.
      - [ ] 4.2.1.3 Subtask - Complete manual accessibility review for adopted primitives and representative compositions, including overlay/focus behavior during patches.
      - [ ] 4.2.1.4 Subtask - Record patches/forks, upstream reports, residual risks, compensating controls, owners, expiry, and version-update triggers.

  - [ ] 4.3 Section - Publish the product-consumption baseline.

    This section defines exactly what Milestone C may import, copy, configure,
    and rely on and what remains prohibited.

    - [ ] 4.3.1 Task {#huib-p04-baseline} [repo: jido_code] [after: {#huib-p04-qualification}] - Assemble and approve the HUI2 consumption dossier.

      This task binds source, locks, assets, facade APIs, theme tokens, protocol
      behavior, browser profiles, and exceptions to one candidate.

      - [ ] 4.3.1.1 Subtask - Publish the exact approved imports/components/attributes/events/assets/configuration and the application composite gaps Milestone C owns.
      - [ ] 4.3.1.2 Subtask - Publish supported browser/proxy/CSP/accessibility profiles, operational ceilings, known failure modes, rollback, and upgrade procedure.
      - [ ] 4.3.1.3 Subtask - Remove or disable the qualification consumer from production routing while retaining deterministic test fixtures and evidence.
      - [ ] 4.3.1.4 Subtask - Create `hypermedia-ui-milestone-b-phase-04-receipt.md` in merge-pending state with HUI-B4/HUI2 evidence and reopening conditions.

  - [ ] 4.4 Section - Phase 4 Integration Tests.

    This final section proves a clean product branch can consume the approved
    stack and that any drift or forbidden runtime pattern is rejected.

    - [ ] 4.4.1 Task {#huib-p04-integration} [repo: jido_code] [after: {#huib-p04-baseline}] - Execute the HUI-B4/HUI2 release qualification matrix.

      This task repeats the evidence from clean checkout and tests all drift
      guardrails before Milestone C is authorized.

      - [ ] 4.4.1.1 Subtask - Reproduce dependency fetch/verify, asset build, facade compile, release startup, SBOM/license/advisory reports, and consumer browser evidence from pinned inputs.
      - [ ] 4.4.1.2 Subtask - Mutate each protected version/digest/license/import/CSP/runtime/consumer assumption and prove CI rejects it with actionable diagnostics.
      - [ ] 4.4.1.3 Subtask - Verify production routing/supervision contains no qualification route or LiveView product runtime and rollback restores the prior dependency/asset set.
      - [ ] 4.4.1.4 Subtask - Run all Milestone B suites, architecture/security/a11y checks, `mix precommit`, and clean-checkout CI.

    - [ ] 4.4.2 Task {#huib-p04-phase-receipt} [repo: jido_code] [after: {#huib-p04-integration}] - Publish and pin the Phase 4 receipt and HUI2 closure.

      This task records HUI-B4/HUI2 evidence in
      `docs/architecture/hypermedia-ui-milestone-b-phase-04-receipt.md`.

      - [ ] 4.4.2.1 Subtask - Keep HUI2 merge-pending on unreproducible inputs, unresolved license/advisory, failing consumer/browser/a11y case, unbounded protocol behavior, forbidden consumer, or ineffective drift check.
      - [ ] 4.4.2.2 Subtask - Record exact artifact/config/browser/proxy digests, evidence, exceptions, owners, expiry, and every reopening condition.
      - [ ] 4.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 4 Integration Tests section, receipt task, pinning subtask, and Milestone B completion before authorizing Milestone C Phase 1.
