# ADR 0009: Human Identity, Scoped Authorization, And Separation Of Duty

- Status: Proposed
- Date: 2026-08-31
- Owners: JidoCode security, product, identity, and operations maintainers
- Decision scope: Human accounts, authentication assurance, product roles,
  graph capabilities, delegations, step-up, live revocation, and approval
  separation
- Depends on:
  [ADR 0001](./0001-graph-only-source-of-truth.md),
  [ADR 0004](./0004-delegated-agent-credentials-and-isolation.md), and
  [ADR 0008](./0008-server-rendered-heex-and-datastar-product-runtime.md)
- Research:
  [Secure hypermedia control plane](../research/12-secure-hypermedia-coding-factory-ui.md)
- Specifications:
  [Human identity and authorization contract](../architecture/human-identity-scope-and-authorization-contract.md),
  [UI threat model](../architecture/ui-security-privacy-and-threat-model.md), and
  [Incident control plane](../architecture/incident-control-plane-contract.md)

## Context

The current product reconstructs one configured operator identity from a
shared token/session. That posture is accepted only behind TLS and network
controls for a single operator. It cannot safely provide project membership,
role-reserved areas, independent verification, security audit, cost-only
observation, knowledge stewardship, step-up authorization, or separation of
duty for multiple humans.

JidoCode already has exact graph capabilities, grants, scopes, delegations,
resources, query authorization, and semantic-command checks. The product needs
named human identities and an understandable role model without replacing or
widening those exact graph decisions.

## Decision

JidoCode will authenticate named human principals and authorize every product
operation through a deny-by-default intersection of:

- subject identity, human/agent class, project membership, roles, exact grants,
  delegations, clearance, and authentication assurance;
- object factory, tenant, conceptual repository/project, task, attempt,
  interaction session, candidate, graph family, resource, and classification;
- action query, view, search, export, start, steer, answer, cancel, handoff,
  recover, verify, decide, publish, apply, administer, or incident operation;
  and
- environment time, authentication age, device/session posture, incident
  state, risk, lifecycle, policy revision, fence, and projection freshness.

### Roles And Exact Capabilities

Roles organize navigation, responsibility, and explanation. They do not grant
access by themselves and cannot union exact capabilities implicitly. The
initial product vocabulary will distinguish at least observer, project
developer, project maintainer, independent verifier, factory operator,
security auditor, factory administrator, knowledge steward, and cost observer
responsibilities.

Every route, projection, field, stream topic, command, export, and incident
operation maps to a closed current capability/query grant. Existing exact-
match and graph-owner rules remain binding.

### Trusted Identity Construction

One server-owned boundary constructs `current_scope`, `product_identity`, and
`authority` consistently for pages, fragments, streams, APIs, and commands.
Browser fields, signals, opaque references, hidden inputs, navigation state,
and cached permissions cannot supply or widen those values.

The current `Product.authority/1` behavior that fixes delegation fields to
`nil` must be replaced only by a trusted mapping from authenticated identity
and current graph grants. Delegation is never inferred from a role label.

### Authentication And Session Assurance

The product will support:

- named accounts and authenticated session inventory/revocation;
- phishing-resistant authentication where required by the selected assurance
  level;
- secure, HTTP-only, appropriately SameSite cookies;
- bounded idle and absolute lifetimes with accessible expiry warnings;
- recent step-up authentication for high-impact actions;
- session generation changes that terminate protected streams; and
- accessible authentication that permits password managers/paste and offers a
  non-cognitive alternative such as passkeys.

### Separation Of Duty

Independent verification, final decision, source application/publication,
security audit, identity/policy administration, complete-memory access,
incident reopen, and recovery/restore are separate capabilities. High-risk
policy may require two distinct current human principals. Administration does
not imply unrestricted project-content access.

### Canonical Approvals

An approval binds a current human principal and assurance level to one exact
server-derived action digest, target, project/environment, parameters,
candidate/effect, expected revisions/fence, policy version, expiry, and
idempotency key. Agent-authored rationale is escaped, labeled untrusted, and
cannot alter canonical transaction facts.

## Consequences

### Positive

- restricted product areas correspond to server-enforced scope rather than CSS
  visibility;
- operators can receive emergency operational authority without receiving
  unrelated project content;
- verification and approval independence becomes enforceable and auditable;
- role/session revocation can stop long-lived delivery; and
- cost, knowledge, audit, and administration duties can be narrow.

### Costs And Constraints

- account lifecycle, assurance, recovery, memberships, grants, delegations,
  step-up, session inventory, and audit need new implementation;
- existing single-token deployment requires an explicit migration and
  compatibility window;
- every product projection needs field-level classification and authorization
  review; and
- multi-user races require compare-and-set semantics and safe conflict
  receipts, not last-write-wins behavior.

## Alternatives Rejected

- **Use role-based navigation as authorization:** hidden links and disabled
  controls are forgeable presentation.
- **Give administrators all project content:** policy administration and data
  clearance are different responsibilities.
- **Authorize only the initial page:** fragments, streams, refreshes, commands,
  and exports can outlive or bypass that decision.
- **Keep a permission snapshot in a Datastar signal:** signals are untrusted and
  authorization changes over time.
- **Use one shared operator in a multi-user UI:** actions cannot be attributed,
  separated, revoked, or audited per human.
- **Let agent text define the approval transaction:** hostile content can spoof
  or manipulate human authorization.

## Compatibility And Rollback

The existing configured operator may remain only as an explicitly labeled,
network-isolated compatibility profile during migration. It cannot access
multi-user production routes or satisfy separation-of-duty gates. Migration
creates named identities and grants without rewriting historical actor facts.

Rollback disables new multi-user route admission and returns to the last
qualified isolated posture. It cannot merge principals, erase receipts, widen
the shared operator, revive revoked sessions, or reinterpret prior approvals.

## Acceptance Conditions

This ADR may move to `Accepted` only when:

1. identity, authentication, scope, authority, role, exact-capability,
   delegation, assurance, and session-generation schemas are specified;
2. one trusted mapping boundary is shared by controller, SSE, API, and command
   entry points;
3. every proposed role/action/lens is mapped to exact current or explicitly
   versioned capabilities and reviewed queries;
4. step-up, single-use approvals, two-person policy, session expiry, and live
   revocation are fail-closed and accessible;
5. cross-tenant/project/attempt/session/graph/role probes reveal no protected
   data, counts, labels, timing distinctions, or effects;
6. simultaneous authorized human commands commit at most one conflicting
   transition and return the current safe receipt to losers;
7. the compatibility operator cannot enter multi-user production posture; and
8. clean-checkout security, browser, recovery, and audit evidence is pinned at
   the merged candidate.
