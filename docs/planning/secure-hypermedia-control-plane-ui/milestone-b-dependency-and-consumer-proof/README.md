---
id: plan.jido_code_hypermedia_ui_milestone_b
status: completed
intent: feature
milestone: B
program: program.jido_code_secure_hypermedia_control_plane_ui
source:
  - docs/architecture/shadcn-ui-adoption-and-component-contract.md
  - docs/architecture/datastar-dstar-dependency-and-consumer-qualification.md
  - docs/architecture/hypermedia-runtime-migration-and-rollback.md
---

# Milestone B Plan - Dependency And Consumer Proof

This four-phase plan qualifies the exact ShadcnUI, Dstar, Datastar, Phoenix
component, asset, and browser combination before product routes depend on it.
It resolves provenance, license, namespace, version, CSP, accessibility, and CI
risks and then proves the combination in an isolated real consumer.

Back to program: [Secure Hypermedia Control Plane UI](../README.md)

## Goal

Close program Gate HUI2 with immutable dependency and asset provenance plus
clean-consumer evidence for HEEx components, forms, Datastar attributes,
CSRF/CSP, SSE, reconnect, overlay morphing, native fallback, and supported
browsers—without adding a LiveView product route or process.

## Gate And Phase Mapping

| Phase gate | Required result | Phase |
|---|---|---|
| HUI-B1 | Exact sources, commits, licenses, usage authority, advisories, namespace, release metadata, and risk ownership are accepted | [Phase 1](./phase-01-source-license-version-and-risk-baseline.md) |
| HUI-B2 | Phoenix.Component constraints, dependency locks, local asset pipeline, CSP build, facade, and theme proof resolve cleanly | [Phase 2](./phase-02-phoenix-component-and-asset-integration.md) |
| HUI-B3 | An isolated controller/HEEx consumer proves native and enhanced requests, fragments, SSE, reconnect, and overlays in real browsers | [Phase 3](./phase-03-datastar-dstar-consumer-spike.md) |
| HUI-B4 / HUI2 | Architecture checks, supply-chain drift detection, accessibility/browser evidence, and deterministic clean installation pass | [Phase 4](./phase-04-dependency-consumer-and-architecture-qualification.md) |

## Phase Order

1. [Phase 1 - Source, License, Version, And Risk Baseline](./phase-01-source-license-version-and-risk-baseline.md)
2. [Phase 2 - Phoenix Component And Asset Integration](./phase-02-phoenix-component-and-asset-integration.md)
3. [Phase 3 - Datastar/Dstar Consumer Spike](./phase-03-datastar-dstar-consumer-spike.md)
4. [Phase 4 - Dependency, Consumer, And Architecture Qualification](./phase-04-dependency-consumer-and-architecture-qualification.md)

Receipts use
`docs/architecture/hypermedia-ui-milestone-b-phase-01-receipt.md` through
`hypermedia-ui-milestone-b-phase-04-receipt.md`. The final receipt closes HUI2
and authorizes Milestone C only from the qualified immutable combination.

## Parallelism And Boundaries

Source/license review, Hex dependency solving, browser-asset inspection, and
accessibility review may proceed in parallel against the same frozen candidate
manifest. Only the phase owner may select final versions or update locks. The
spike is deliberately isolated from product routes and durable graph mutation;
it may use bounded fixtures but must exercise the real browser and HTTP stack.

## Completion Definition

Milestone B completes when a clean checkout can obtain or verify every pinned
input, build locally served deterministic assets, compile the component facade,
run the isolated native/enhanced consumer in supported browsers and proxy/CSP
modes, reproduce security/accessibility evidence, and reject any unapproved
dependency, digest, runtime, or asset drift.
