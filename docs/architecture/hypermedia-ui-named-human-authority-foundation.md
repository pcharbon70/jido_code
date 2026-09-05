# Hypermedia UI Named-Human Authority Foundation

- Status: HUI-C1 implementation evidence; acceptance remains merge-pending
- Contract: `docs/architecture/human-identity-scope-and-authorization-contract.md`
- Operation matrix: `docs/architecture/hypermedia-ui-operation-authorization-matrix.md`
- Runtime owner: `JidoCode.Identity.Store`
- Trusted constructor: `JidoCode.Identity.AuthorityBuilder`

## Boundary

The HUI-C1 browser boundary accepts only an opaque server-side session
reference and a closed `AuthorityRequest` constructed from route-owned atoms
and an opaque resource reference. It rejects extra fields. Actor, principal,
tenant, project, role, grant, delegation, assurance, classification,
environment, policy revision, graph revision, incident posture, and generation
values have no browser input path.

Each protected request validates current session, account, membership,
delegation, resource, route, clearance, lifecycle, and assurance state before
asking the graph adapter for one exact grant. Roles remain explanation only.

The production adapter is deliberately
`JidoCode.Identity.Authority.Unconfigured` in this phase. It returns
`unavailable`. Tests compose the explicit
`JidoCode.TestSupport.StaticHumanAuthorityAdapter` fixture. Named-human browser
access therefore cannot claim production graph authority until a later gate
composes and proves the production adapter.

## Resource Registry

`JidoCode.Identity.Resource` immutably binds kind, tenant, optional project,
parent, graph scope, classification, environment, lifecycle, and revision.
Factory, project, attempt, interaction session, candidate, wiki preview, and
graph children stay inside parent containment.

Factory authorization requires a tenant-level membership. Project and child
authorization requires an exact project membership; tenant membership is not
silently promoted to project clearance. Unknown and unauthorized references
both use the concealed-not-found exterior outcome.

## Membership And Delegation

Memberships bind one immutable subject/tenant/project tuple to bounded role
explanations, independently bounded route groups, clearance, validity,
revision, and status. The seven route groups are developer, reviewer,
operations, security, cost, knowledge, and administration. Their route plugs
repeat current authority construction before admission.

Human delegations bind immutable parties and exact resources, actions, graph
families, environment, validity, policy, assurance, classification,
obligations, revision, and revocation generation. Attenuation only narrows;
expired, revoked, stale, or multiple matches deny.

Account enrollment and all membership, delegation, registry, and external
generation mutations are reachable only through
`JidoCode.Identity.Administration`. That boundary requires a server-created
governed identity-administration context at action-bound step-up. HUI-C1 adds
no browser route capable of constructing that context.

## Decisions And Reauthorization

The closed outcomes are `allowed`, `concealed_not_found`, `redacted`,
`denied`, `unavailable`, `revoked`, and `step_up_required`. Safe reasons never
include hidden roles, grant facts, sibling resource identity, delegation facts,
or adapter errors.

`AuthorityBuilder.reauthorize/4` supports the accepted checkpoints before
response start, query execution, field shaping, stream subscription, every
protected patch, command construction, command-gateway execution, approval
commit, export creation, and each export/download retrieval. Each invocation
rebuilds authority from current server state.

## Revocation

Account, session, role, delegation, project, tenant, graph, and incident
changes publish privacy-safe monotonic `RevocationEvent` generations. External
graph and incident owners use exact compare-and-increment transitions. Cached
scope and notification data are never authority; consumers reauthorize.

## Limitations And Reopening Conditions

HUI-C1 reopens if a browser value supplies authority, a role or route group is
treated as an exact grant, a tenant membership crosses into a project, a
resource binding changes identity, a delegation widens or matches ambiguously,
an expired or revision-stale record remains current, adapter failure opens
access, any enforcement point skips current reconstruction, a revocation
generation is non-monotonic, or protected identity/grant/session material is
logged or persisted in browser state.
