---
id: plan.jido_code_hypermedia_ui_milestone_c
status: proposed
intent: feature
milestone: C
program: program.jido_code_secure_hypermedia_control_plane_ui
source:
  - docs/architecture/human-identity-scope-and-authorization-contract.md
  - docs/architecture/secure-product-shell-and-information-architecture.md
  - docs/architecture/shadcn-ui-adoption-and-component-contract.md
---

# Milestone C Plan - Read-Only Hypermedia Shell

This five-phase plan implements named-human browser identity, the qualified
component/composite layer, ordinary authenticated controller/HEEx routes, and
read-only attention, fleet, project, and attempt projections. It establishes a
useful native HTML product before Datastar live delivery or semantic controls.

Back to program: [Secure Hypermedia Control Plane UI](../README.md)

## Goal

Close program Gate HUI3 with a secure, accessible, responsive, no-JS-capable
read-only product shell that uses the same trusted scope and reviewed graph
projections as other product boundaries and tells the truth about unavailable
factory capabilities.

## Gate And Phase Mapping

| Phase gate | Required result | Phase |
|---|---|---|
| HUI-C1 | Named accounts, sessions, trusted authority construction, membership/delegation, assurance, restricted routes, and revocation work through controller paths | [Phase 1](./phase-01-named-human-session-and-scope-foundation.md) |
| HUI-C2 | Qualified primitives are wrapped by application-owned shell, state, table, timeline, trust, and overlay composites with coherent themes and accessibility | [Phase 2](./phase-02-shadcnui-facade-theme-and-app-components.md) |
| HUI-C3 | Authenticated full-page routes, durable URLs, navigation, native forms, errors, and scope switching work without JavaScript | [Phase 3](./phase-03-authenticated-shell-routes-and-native-navigation.md) |
| HUI-C4 | Attention, fleet, project, attempt, cost, wiki, and readiness reads use bounded authorized projections with all projection states | [Phase 4](./phase-04-attention-fleet-project-and-attempt-projections.md) |
| HUI-C5 / HUI3 | Cross-scope isolation, responsive/accessibility, native browser, real-adapter, and operational evidence accept the complete read-only shell | [Phase 5](./phase-05-read-only-shell-accessibility-and-acceptance.md) |

## Phase Order

1. [Phase 1 - Named Human Session And Scope Foundation](./phase-01-named-human-session-and-scope-foundation.md)
2. [Phase 2 - ShadcnUI Facade, Theme, And Application Components](./phase-02-shadcnui-facade-theme-and-app-components.md)
3. [Phase 3 - Authenticated Shell Routes And Native Navigation](./phase-03-authenticated-shell-routes-and-native-navigation.md)
4. [Phase 4 - Attention, Fleet, Project, And Attempt Projections](./phase-04-attention-fleet-project-and-attempt-projections.md)
5. [Phase 5 - Read-Only Shell Accessibility And Acceptance](./phase-05-read-only-shell-accessibility-and-acceptance.md)

Receipts use
`docs/architecture/hypermedia-ui-milestone-c-phase-01-receipt.md` through
`hypermedia-ui-milestone-c-phase-05-receipt.md`. The final receipt closes HUI3
and is the sole live-delivery baseline for Milestone D.

## Parallelism And Boundaries

After Phase 1 pins the identity/authority API, component composites may be
developed in parallel by disjoint module ownership. Route and projection work
must integrate from pinned phase receipts and cannot add commands, automatic
SSE, raw graph queries, or client-owned state. Browser sessions, tabs,
repositories, attempts, interaction sessions, and wiki previews remain
isolated even when tested concurrently.

## Completion Definition

Milestone C completes when named authorized users can navigate factory,
project, and attempt contexts through durable ordinary pages; all projections
show explicit truth/freshness/readiness states; no-JS and accessibility
baselines pass; restricted fields/routes remain concealed; unavailable
capabilities are honest; and no read route produces a semantic effect.
