# Hypermedia Product Governance Baseline

- Status: Accepted for architecture authority; implementation and release gated
- Specification version: `1.0.0`
- Accepted: 2026-09-03 through HUI-A3 merged-candidate governance
- Owners: JidoCode architecture, product, security, and operations maintainers
- Milestone: A — Architectural Authority
- Research: [Secure hypermedia control plane](../research/12-secure-hypermedia-coding-factory-ui.md)
- Decisions:
  [ADR 0008](../adr/0008-server-rendered-heex-and-datastar-product-runtime.md),
  [ADR 0009](../adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md),
  [ADR 0010](../adr/0010-shadcnui-as-product-component-primitive-layer.md), and
  [ADR 0011](../adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md)

## Purpose

This specification is the authority map for replacing the current
LiveView/LiveVue browser product with a secure HEEx/Datastar control plane. It
defines which accepted contracts survive unchanged, which presentation
decisions require explicit supersession, which current capabilities are not
production-composed, and which gates authorize each later milestone.

It creates no runtime, dependency, route, graph, query, command, role, or grant.

The accepted target is intentionally distinct from current operability. The
existing LiveView/LiveVue/SaladUI product remains the deployed compatibility
runtime until later route, consumer, and removal gates close. Dstar, Datastar,
ShadcnUI, named-human identity, attention projections, and knowledge lenses
receive no runtime credit from this architecture acceptance.

## Governing Baseline

The implementation baseline MUST pin:

- the full merged candidate containing the accepted versions of ADRs 0001–0007;
- ontology, SHACL, GraphRegistry, semantic command/query, Product projection,
  runtime, wiki, and authorization versions;
- the current architecture report and UI research digest;
- current browser routes, Plugs, LiveViews, LiveVue islands, component facades,
  assets, dependencies, tests, operations guides, and rollback owners; and
- the current readiness truth for scheduler/reconciler, managed service,
  coding loaders, delegated-agent rollout, publication provider, wiki gateways,
  identity provider, and live-delivery support.

No implementation section may claim a service is usable merely because a
module, contract, or accepted receipt exists.

## Contract Preservation And Supersession

| Existing contract | Preserved authority | Proposed supersession |
|---|---|---|
| Graph-only source of truth | TripleStore remains durable authority | None |
| Reviewed query catalog | Closed, bounded, authorized reads | Add product lens queries; no raw browser |
| Semantic command/gateway contracts | State, revision, lease/fence, profile, idempotency, receipt | Add web adapters only; commands remain semantic |
| Projection states | Ready, empty, stale, incomplete, contradicted, truncated, unauthorized, unavailable, maintenance, recovery | New HEEx components and patches preserve semantics |
| Change delivery/recovery | PubSub is a lossy hint; server reauthorizes/requeries | SSE coordinator replaces LiveView mailbox delivery |
| Product security/threat model | Classification, concealment, redaction, independent resource authorization | Extend for named humans, signals, SSE, CSP, approvals, multi-tab |
| Product surface/island contract | Closed surface vocabulary and web isolation | Supersede LiveView/LiveVue ownership and island rules |
| Repository wiki product contract | Scoped wiki reads, previews, cost, editions, guide/dependency behavior | Supersede LiveView stream/render requirements only |

Accepted gate-reopening conditions remain intact. A new ADR may supersede a
presentation decision but cannot silently weaken its graph, security,
projection, command, recovery, accessibility, or evidence invariant.

## Milestone Authority Map

| Milestone | Authorized work after prerequisite closure | Governing specifications |
|---|---|---|
| A | Accept decisions, pin baseline, reconcile vocabulary and supersession | This document; identity contract |
| B | Qualify immutable dependencies, assets, and consumer spike | ShadcnUI contract; Dstar/Datastar qualification |
| C | Implement named identity and read-only shell/projections | Identity contract; shell/IA contract |
| D | Add bounded Datastar requests, fragments, and SSE | Datastar interaction contract |
| E | Add bounded agent conversation, admitted attempt controls, and receipts | Attempt workspace/command contract |
| F | Add reviewed graph and wiki lenses | Graph-lens contract |
| G | Qualify security, incident, accessibility, usability, and release | Threat, incident, and qualification contracts |
| H | Remove superseded runtime and close rollback | Migration/rollback contract |

Each milestone owns a separate phased plan directory. Every implementation
phase has its own document and receipt; phase numbering restarts within the
milestone. A later phase cannot begin until the immediately preceding phase
receipt pins a full merged candidate, and a later milestone cannot begin until
the preceding milestone's final phase receipt is pinned.

## Non-Negotiable Invariants

1. TripleStore and governed external source observations remain authority.
2. Web code uses Product/Factory public projections and gateways, not raw
   Knowledge internals or SPARQL.
3. Browser state, signals, DOM, URLs, opaque refs, tab IDs, streams, caches, and
   process memory never grant authority or prove durable success.
4. Unknown and unauthorized resources retain concealed exterior behavior.
5. Unavailable projections clear their rows; only explicit stale projections
   may show bounded last-known data.
6. Every mutation commits through the semantic command pipeline before or with
   the governed effect and returns/reconciles an immutable receipt.
7. Attempts, interaction sessions, candidates, projects/repositories, browser
   sessions, provider threads, and OS processes remain distinct identities.
8. Conversation projects only authorized durable semantic messages and routes
   exact answer/steer intent through admitted gateways; browser or provider chat
   state never becomes authority or delivery evidence.
9. Current unconfigured/disabled/contract-only posture is rendered honestly.
10. No dependency is selected from a mutable branch at runtime or by graph or
   browser data.
11. Existing phase/receipt reopening conditions remain effective regardless of
    new checklist state.

## Evidence And Drift Control

The first implementation section MUST record SHA-256 digests for all proposed
ADRs, specifications, research, and plan documents. Architecture fitness checks
MUST reject:

- product `live` routes, LiveView modules/events/streams, and LiveVue islands
  after their milestone removal boundary;
- direct raw graph/query access from web modules;
- unallowlisted Dstar page/event dispatch or scripts;
- external/CDN UI assets;
- unpinned git dependencies;
- browser-derived actor, scope, graph, query, command, profile, fence, or
  trusted revision; and
- documentation that assigns current product authority to both old and new
  route owners without an explicit migration state.

## Gate A Acceptance

Milestone A closes only when:

1. ADRs 0008–0011 and all linked specifications are reviewed and accepted or
   explicitly narrowed;
2. all current UI/runtime/dependency/document/test/operation owners are
   inventoried;
3. vocabulary and scope collisions are resolved;
4. current readiness gaps are recorded as release blockers;
5. milestone-plan, phase, and specification mapping is complete;
6. architecture checks cover new prohibited boundaries; and
7. Milestone A Phase 4 integration passes and its receipt pins the merged
   candidate after Phases 1–3 have closed from their pinned receipts.

## Gate Reopening Conditions

Gate A reopens if a governing digest changes without review; an accepted
invariant is weakened; a route or dependency owner is omitted; current
operability is overstated; project/attempt/session vocabulary becomes
ambiguous; a later milestone begins without the prior receipt; or architecture,
precommit, or clean-checkout CI fails.
