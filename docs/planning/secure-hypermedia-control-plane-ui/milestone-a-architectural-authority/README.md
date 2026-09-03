---
id: plan.jido_code_hypermedia_ui_milestone_a
status: completed
intent: feature
milestone: A
program: program.jido_code_secure_hypermedia_control_plane_ui
source:
  - docs/architecture/hypermedia-product-governance-baseline.md
  - docs/architecture/human-identity-scope-and-authorization-contract.md
  - docs/architecture/hypermedia-runtime-migration-and-rollback.md
---

# Milestone A Plan - Architectural Authority

This four-phase plan establishes the authority required to change the browser
product without contradicting accepted architecture. It inventories current
truth, accepts or narrows the proposed ADR/specification set, defines named
human identity and exact authorization, supersedes LiveView/LiveVue product
ownership, and installs enforceable governance checks before any dependency or
product implementation begins.

Back to program: [Secure Hypermedia Control Plane UI](../README.md)

## Goal

Close program Gate HUI1 with one coherent vocabulary and accepted authority
for pages, fragments, streams, signals, commands, receipts, revocation,
parallel sessions, accessibility, security, migration, and rollback.

## Boundaries

- This plan changes decisions, specifications, contributor rules, architecture
  checks, inventories, and evidence fixtures; it does not implement the new UI.
- Existing graph, query, command, execution, memory, delegated-agent, and wiki
  contracts remain authoritative unless a named accepted decision explicitly
  supersedes a product-presentation clause.
- Proposed identity and incident semantics remain non-operational until their
  implementation phases and receipts pass.
- Every unavailable factory capability retains an honest unconfigured or
  contract-only posture.

## Gate And Phase Mapping

| Phase gate | Required result | Phase |
|---|---|---|
| HUI-A1 | Current routes, runtimes, dependencies, identities, graphs, commands, tests, docs, and operations have accountable owners and pinned evidence | [Phase 1](./phase-01-current-state-authority-and-gap-baseline.md) |
| HUI-A2 | Named-human identity, scope, assurance, delegation, revocation, roles, and separation of duty are accepted without widening graph grants | [Phase 2](./phase-02-human-identity-and-authorization-authority.md) |
| HUI-A3 | Server-rendered HEEx/Datastar ownership and all affected product/security/wiki/operations contracts supersede conflicting runtime clauses | [Phase 3](./phase-03-runtime-contract-supersession-and-interface-freeze.md) |
| HUI-A4 / HUI1 | Contributor instructions, architecture checks, traceability, evidence ownership, and merged-candidate governance prove the new authority is enforceable | [Phase 4](./phase-04-governance-guardrails-and-authority-acceptance.md) |

## Phase Order

1. [Phase 1 - Current-State Authority And Gap Baseline](./phase-01-current-state-authority-and-gap-baseline.md)
2. [Phase 2 - Human Identity And Authorization Authority](./phase-02-human-identity-and-authorization-authority.md)
3. [Phase 3 - Runtime Contract Supersession And Interface Freeze](./phase-03-runtime-contract-supersession-and-interface-freeze.md)
4. [Phase 4 - Governance Guardrails And Authority Acceptance](./phase-04-governance-guardrails-and-authority-acceptance.md)

Receipts are written as
`docs/architecture/hypermedia-ui-milestone-a-phase-01-receipt.md` through
`hypermedia-ui-milestone-a-phase-04-receipt.md`. The Phase 4 receipt closes
HUI1 and is the only baseline that can authorize Milestone B.

## Parallelism

Inventory collection may run in parallel by route/runtime, identity/security,
graph/command, and operations/test ownership. Contract editing may run in
parallel only across disjoint documents after vocabulary and supersession
ownership are frozen. All branches reconcile against the same phase receipt;
no session may independently assign ontology/protocol versions or accept an
ADR.

## Completion Definition

Milestone A completes when all proposed decisions/specifications are accepted,
narrowed, deferred, or rejected explicitly; no accepted document silently
requires the superseded runtime; `AGENTS.md` and architecture checks enforce
the target; every term and authority path has one owner; and the Phase 4 merged
candidate receipt pins the full SHA/date with every HUI1 reopening condition.
