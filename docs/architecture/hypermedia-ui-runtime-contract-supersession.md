# Hypermedia UI Runtime Contract Supersession And Interface Freeze

- Status: Accepted architecture contract under ADRs 0008–0011; implementation
  and release gated
- Specification version: `1.0.0`
- Accepted: 2026-09-03 through HUI-A3 merged-candidate governance
- Owners: JidoCode architecture, product, web, security, Knowledge, Factory,
  operations, release, accessibility, wiki, and documentation maintainers
- Machine contracts:
  [`phase_a3_supersession_matrix.json`](../../priv/architecture/hypermedia_ui/phase_a3_supersession_matrix.json)
  and
  [`phase_a3_interface_registry.json`](../../priv/architecture/hypermedia_ui/phase_a3_interface_registry.json)

## Authority And Availability

This contract freezes the target interfaces that Milestones B through H must
implement. It creates no dependency, route, process, graph resource, grant,
query, command, stream, or release capability. The current product remains the
compatibility implementation recorded by the HUI-A1 inventory until an exact
route and consumer cutover passes its later gate.

The target owners are ordinary Phoenix controllers and HEEx for pages and
fragments, application controllers for semantic actions, and one
application-owned authorized delivery coordinator over Dstar/SSE for live
patches. Datastar and Dstar are transport helpers only. TripleStore, governed
external observations, reviewed queries, semantic gateways, and immutable
receipts retain durable authority.

## Supersession Rules

HUI-A3 supersedes presentation-specific ownership in the accepted product
surface, repository wiki, delegated-agent product, security, projection,
delivery, operations, install/rollback, contributor, and module-boundary
contracts. It preserves their graph-only truth, exact scope and concealment,
projection states, command and receipt semantics, lossy-hint recovery,
accessibility, evidence, retention, and reopening conditions.

Historical receipts, architecture audits, inventories, and operator guidance
that accurately describe the deployed compatibility runtime remain historical
or current-state evidence. They are not target requirements and must not be
rewritten. A current document may name both runtimes only when it labels the
compatibility owner, target owner, migration fence, and removal condition.

Repository wiki semantics remain especially binding: explicit enrollment,
default-off posture, per-repository and same-repository-session isolation,
one logical maintainer profile per enabled repository, deterministic-only
operation without model calls, immutable editions, exact source/candidate
identity, token reservation and attributable usage/cost, hard aggregate
budgets, opt-out, review/activation separation, and deterministic release
evidence cannot be weakened by the new presentation runtime.

## Frozen Surface

The machine interface registry is normative for target page, fragment, action,
stream, export, and incident route templates; HTTP methods; request classes;
signal namespaces; projection states; patch roots; safe outcomes; native
fallback; and reauthorization points. Browser input never selects an interface
version, route owner, module, graph/query/command identity, actor, authority,
trusted revision, fence, or durable outcome.

Unknown or unauthorized resources use concealed exterior behavior. An
unavailable projection clears its affected rows. Essential reads remain
navigable by ordinary anchors, and essential actions use ordinary forms with a
server-rendered validation/confirmation/result path where policy permits.
Streaming is enhancement: initial connect and reconnect obtain a current
snapshot, and terminal revocation stops privileged reconnect.

## Interface Versioning And Compatibility

Every shared interface has one owner, semantic version, implementation
milestone, compatibility rule, and consumer list. Additive optional output is
compatible only when old readers ignore it safely and concealment, bounds,
classification, and defaults do not change. A required field, route/method,
meaning, state, authorization, patch root, signal rule, or default change is
breaking and requires a new major version plus migration and rollback proof.

Feature flags are trusted server-side rollout policy. They select one route
owner and immutable route/asset/config manifest before request admission. A
browser cannot choose the owner. One action cannot dual-write to old and new
presentation paths, and a route cannot have two mutable browser authorities.
Shadow comparison may execute two read-only projections only when both use the
same authorized canonical input, neither result mutates state, only the
selected owner renders, and differences are bounded evidence.

Old readers receive the last compatible representation or an explicit
`upgrade_required`/`unavailable`; they never receive reinterpreted fields.
Deprecation begins only after all consumers are named and compatible. Removal
requires the exact consumer manifest to be empty, required evidence accepted,
the rollback window closed, and the last qualified artifact retained.

## Parallel Ownership And Migration Fences

Milestone A owns architecture documents and manifests. B owns dependency,
asset, and consumer qualification. C owns identity composition, target page
routes, shell, and read projections. D owns signal/fragment schemas and stream
coordination. E owns attempt actions, previews, receipts, and recovery. F owns
lens and wiki adapters. G owns incident, audit/export, browser/security,
accessibility, usability, load, proxy, and release evidence. H alone owns final
route/socket/runtime/dependency removal.

Parallel worktrees may consume a published interface version but cannot assign
the same next version concurrently. The interface owner lands version changes
first; consumers then rebase on that merged candidate. Shared router, endpoint,
layout, asset entrypoint, facade, and release-manifest edits belong to the
owning milestone and are reconciled sequentially.

## Accepted Limits And Reopening

Dstar, Datastar, and ShadcnUI remain absent and unqualified. Named-human
identity, target routes, streams, attempt controls, lenses, incident controls,
and exports remain unavailable. LiveDashboard remains a development-only
compatibility consumer requiring removal, replacement, or separate approval
before a literal zero-LiveView claim.

HUI-A3 reopens if a preserved invariant weakens; presentation ownership is
ambiguous; a route, interface, version, owner, consumer, migration fence,
rollback dependency, or evidence class is missing; old and new owners share
mutable browser authority; a browser selects authority or interface meaning;
wiki enrollment/isolation/cost/budget/release semantics drift; an unavailable
capability is advertised; a removal occurs from a milestone label instead of
the exact consumer/evidence manifest; or architecture, precommit, or
clean-checkout CI fails at the pinned candidate.
