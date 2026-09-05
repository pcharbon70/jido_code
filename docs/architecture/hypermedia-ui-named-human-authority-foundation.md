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

For each protected request, the constructor validates the current named-human
session and account, reads current memberships and delegations, resolves one
server-owned resource record, applies route-area admission, checks clearance,
resource lifecycle, and assurance, and then asks the configured graph-authority
adapter for one exact operation grant. A role label is emitted only as an
explanation. It is neither a grant nor a union rule.

The production adapter is deliberately
`JidoCode.Identity.Authority.Unconfigured` in this phase. It returns
`unavailable`. Tests compose the explicit
`JidoCode.TestSupport.StaticHumanAuthorityAdapter` fixture. Named-human browser
access therefore cannot claim production graph authority until a later gate
composes and proves the production adapter.

## Returned Values

An allowed decision returns transient values only:

- a named-human product identity whose actor and principal are the immutable
  human subject IRI;
- an exact resource scope with tenant, optional project, resource kind,
  classification, environment, session/account generations, policy revision,
  and all revocation generations;
- the existing `JidoCode.Knowledge.AuthorityContext`;
- one adapter-supplied exact grant reference, an optional exact human
  delegation reference, bounded obligations, and bounded graph revisions; and
- an audit correlation reference plus explicit concealment and redaction
  posture.

None of these values is stored in the cookie or persisted as a cached
authorization result. Adapter exceptions, malformed responses, non-unique
memberships or delegations, missing evidence, and audit persistence failure
fail closed.

## Resource Registry

`JidoCode.Identity.Resource` binds an opaque immutable reference to one kind,
tenant, optional project, parent, graph scope, classification, environment,
lifecycle, and registry revision. The closed kinds are factory, project,
attempt, interaction session, candidate, wiki preview, and graph. Child
resources must remain inside the parent's tenant and project containment.
Reusing a resource reference cannot change its kind or containment binding.

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

Human delegations bind immutable issuer and delegate subjects to exact
resources, actions, graph families, environment, validity, policy revision,
assurance, classification, obligations, revision, and revocation generation.
An attenuated child must preserve the parent binding and can only narrow
resources, actions, graph families, validity, classification, and environment;
it may strengthen assurance or add obligations. Current reads omit expired,
revoked, and policy-stale delegations. Multiple exact matches deny.

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
dimensions use monotonic generation transitions. Changes publish privacy-safe
`RevocationEvent` messages on the application-owned PubSub topic. Generation
events contain only bounded subject/resource references, the dimension,
previous and next counters, policy revision, and time. Sessions and cached
scope comparisons cannot treat a notification as authority; they reauthorize
against current state.

Membership changes advance role and tenant generations plus project generation
when applicable. Delegation changes advance delegation generation. Registry
changes advance tenant or project generation. Account and session lifecycle
events retain their independent generations. External graph and incident
owners must publish exact compare-and-increment transitions; stale transitions
are rejected.

## Limitations And Reopening Conditions

This foundation does not authorize a new product page, stream, field,
semantic command, approval, export, or download. It does not implement a
production identity provider, phishing-resistant authenticator, step-up
ceremony, recovery provider, graph-grant adapter, incident evaluator, or SSE
coordinator. Each remains explicitly unavailable until its later receipt.

HUI-C1 reopens if a browser value supplies authority, a role or route group is
treated as an exact grant, a tenant membership crosses into a project, a
resource binding changes identity, a delegation widens or matches ambiguously,
an expired or revision-stale record remains current, adapter failure opens
access, any enforcement point skips current reconstruction, a revocation
generation is non-monotonic, or protected identity/grant/session material is
logged or persisted in browser state.
