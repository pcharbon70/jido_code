---
id: plan.jido_code_hypermedia_ui_milestone_b_phase_01
parent_plan: plan.jido_code_hypermedia_ui_milestone_b
status: proposed
intent: feature
---

# Milestone B Phase 1 - Source, License, Version, And Risk Baseline

This phase freezes the exact upstream artifacts and legal/security posture
before any lockfile or product consumer changes.

Back to plan: [README](./README.md)

- [ ] 1 Phase - Establish immutable dependency, asset, license, and risk provenance.

  This phase closes HUI-B1 by making every selected input independently
  identifiable, reviewable, reproducible, and replaceable.

  - [x] 1.1 Section - Qualify ShadcnUI source and usage authority.

    This section resolves repository identity, namespace, license, metadata,
    CI, accessibility, and component-surface ambiguity.

    - [x] 1.1.1 Task {#huib-p01-shadcn} [repo: jido_code] [after: {#huia-p04-phase-receipt}] - Freeze the ShadcnUI adoption record.

      This task treats `pcharbon70/shadcn_ui` as reviewed source, not a mutable
      package-name assumption.

      - [x] 1.1.1.1 Subtask - Record canonical repository URL, owner, exact commit/tag, archive and tree digests, package name/version/namespace, provenance, release and maintenance status.
      - [x] 1.1.1.2 Subtask - Obtain and record license/usage authority for source, compiled CSS, icons, examples, copied code, modifications, and redistribution; block adoption on unresolved proprietary terms.
      - [x] 1.1.1.3 Subtask - Inventory components, public APIs, dependencies, generated assets, CSS variables, Datastar attribute handling, namespace collisions, and missing application composites.
      - [x] 1.1.1.4 Subtask - Record upstream CI results, tests, advisories, accessibility evidence/gaps, issue risk, update policy, fork/patch disposition, owner, and expiry.

  - [x] 1.2 Section - Qualify Dstar and Datastar source/protocol pairing.

    This section freezes both server helper and browser runtime rather than
    inferring compatibility from examples or versionless documentation.

    - [x] 1.2.1 Task {#huib-p01-datastar} [repo: jido_code] [after: {#huib-p01-shadcn}] - Freeze the Dstar/Datastar compatibility record.

      This task records the exact protocol behaviors the later spike must prove.

      - [x] 1.2.1.1 Subtask - Record Dstar package/source version, commit, lock checksum, archive/tree digest, license, dependencies, supported Elixir/Phoenix constraints, and helper/API inventory.
      - [x] 1.2.1.2 Subtask - Record Datastar client version, source commit, bundle filename, minified/unminified digest, license, build flags, CSP mode, import path, and locally served target.
      - [x] 1.2.1.3 Subtask - Map server event/action/attribute encodings to exact selected client behavior for requests, signals, fragments, SSE events, retries, morphing, and error handling.
      - [x] 1.2.1.4 Subtask - Record protocol gaps, undocumented assumptions, browser support, security advisories, patch/fork needs, update policy, and incompatible combinations.

  - [x] 1.3 Section - Build the dependency and supply-chain decision ledger.

    This section gives every selected or rejected version an explicit rationale,
    risk owner, integrity input, and replacement path.

    - [x] 1.3.1 Task {#huib-p01-ledger} [repo: jido_code] [after: {#huib-p01-datastar}] - Publish the immutable dependency/asset bill of materials.

      This task is the sole version-selection input for Phases 2–4.

      - [x] 1.3.1.1 Subtask - Record direct/transitive Hex/npm/source dependencies, checksums, licenses, advisories, source URLs, build inputs, runtime/compile-only roles, and consumers.
      - [x] 1.3.1.2 Subtask - Record alternatives considered, version constraint conflicts, exceptions, compensating controls, owners, expiry, and rollback/replacement triggers.
      - [x] 1.3.1.3 Subtask - Define offline/cache verification, trusted publication/channel policy, update cadence, drift detection, and emergency advisory response.
      - [x] 1.3.1.4 Subtask - Define expected lockfiles, asset manifest, SBOM, integrity metadata, and signed/reviewed evidence outputs for a clean checkout.

  - [ ] 1.4 Section - Phase 1 Integration Tests.

    This final section proves the provenance ledger can reproduce and verify
    all inputs without silently selecting a mutable or unauthorized artifact.

    - [ ] 1.4.1 Task {#huib-p01-integration} [repo: jido_code] [after: {#huib-p01-ledger}] - Execute the HUI-B1 provenance, license, and integrity matrix.

      This task tests missing, mutated, ambiguous, revoked, and vulnerable
      inputs as release-blocking outcomes.

      - [ ] 1.4.1.1 Subtask - Re-fetch or independently verify source archives, package checksums, browser bundles, licenses, metadata, and digests from the recorded locations.
      - [ ] 1.4.1.2 Subtask - Exercise changed commit/tag, checksum mismatch, missing license/usage grant, namespace drift, advisory, upstream CI failure, and unavailable artifact fixtures.
      - [ ] 1.4.1.3 Subtask - Verify the compatibility matrix names every behavior the consumer spike must prove and contains no inferred/versionless client claim.
      - [ ] 1.4.1.4 Subtask - Run dependency/license/security/documentation checks, `mix precommit`, and clean-checkout CI without introducing product consumers.

    - [ ] 1.4.2 Task {#huib-p01-phase-receipt} [repo: jido_code] [after: {#huib-p01-integration}] - Publish and pin the Phase 1 receipt.

      This task records HUI-B1 evidence in
      `docs/architecture/hypermedia-ui-milestone-b-phase-01-receipt.md`.

      - [ ] 1.4.2.1 Subtask - Keep HUI-B1 merge-pending on mutable provenance, unresolved usage authority, digest mismatch, unknown consumer, unsupported constraint, open critical advisory, or unowned accessibility/CI risk.
      - [ ] 1.4.2.2 Subtask - Record exact sources, digests, licenses, SBOM, risk ledger, exceptions, reviewers, and all reopening conditions.
      - [ ] 1.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 1 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 2.
