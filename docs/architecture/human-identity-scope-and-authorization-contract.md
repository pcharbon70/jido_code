# Human Identity, Scope, And Authorization Contract

- Status: Accepted architecture contract under ADR 0009; implementation and release gated
- Specification version: `1.0.0`
- Owners: JidoCode identity, security, product, and audit maintainers
- Milestones: A, C, and G
- Decision: [ADR 0009](../adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md)

## Purpose

This specification defines the trusted server boundary that turns an
authenticated named human into current Product scope and exact graph authority.
It defines sessions, roles, memberships, delegations, step-up, approvals,
revocation, concealment, and audit without making UI visibility an access
control.

The machine-readable identity and assurance companion is
[`priv/architecture/hypermedia_ui/phase_a2_identity_and_assurance.json`](../../priv/architecture/hypermedia_ui/phase_a2_identity_and_assurance.json).
It pins the exact identity fields, assurance classes, session limits,
exceptional flows, audit fields, and deferred implementation gates accepted by
HUI-A2.

## Authority Status And Boundaries

This contract is binding for all later hypermedia identity and authorization
design. It creates no account store, authenticator, route, grant, delegation,
stream, command, or release capability. Named-human operation remains
unavailable until the corresponding Milestones C through G receipts prove the
real adapters and product surfaces.

The current configured operator remains an isolated single-operator
compatibility profile. It is not a named-human account, cannot enter a
multi-user production posture, cannot delegate human authority, and cannot
satisfy maker/checker, independent-verifier, recovery, or break-glass
separation.

Human accounts, service principals, and agent principals are disjoint. They
never share an identifier class or silently substitute for one another.

## Canonical Identity Records

| Record | Immutable identity | Required mutable state | Prohibited content |
| --- | --- | --- | --- |
| Human account | opaque `subject_ref` | status, tenant memberships, authenticator refs, account generation, policy revision | credentials, graph grants, role cache |
| Authenticator | opaque `authenticator_ref` bound to one subject | kind, phishing resistance, enrolled/verified/revoked times, revision | reusable secret or private key |
| Browser session | opaque `session_ref` bound to one subject | issued/last-seen/last-auth times, assurance, nonce, session/account generations, hard/idle expiry | credentials, grants, delegation, cached authorization |
| Authentication event | immutable `authentication_event_ref` | safe method class, assurance, outcome, time, correlation, policy revision | raw assertion, token, credential, recovery answer |
| Recovery event | immutable `recovery_event_ref` | initiator, subject, method class, approvals, outcome, generations, time | recovery secret, hidden evidence content |
| Audit event | immutable `audit_event_ref` | safe actor/action/object/outcome/policy/receipt refs and time | credential, raw token, hidden reasoning, unnecessary protected content |

Display names, email addresses, provider handles, and mutable account labels are
presentation attributes. Only the opaque subject reference identifies the
human principal in authority and audit records.

## Assurance And Action Risk

The accepted assurance vocabulary is `baseline`, `phishing_resistant`, and
`action_bound_step_up`. A higher label is not inferred from an authenticator
name: the trusted authentication adapter must supply a verified result under
the current policy revision.

| Risk class | Minimum assurance | Maximum authentication age | Additional rule |
| --- | --- | ---: | --- |
| Public or internal read | `baseline` | 12 hours | exact current resource grant still required |
| Confidential read, source inspection, ordinary admitted command | `phishing_resistant` | 4 hours | classification and environment must permit the operation |
| Publication/application, final decision, policy/identity administration, export, restore, high-risk incident action | `action_bound_step_up` | 10 minutes | bind the challenge to the canonical action digest; separation policy may require another principal |
| Secret reference administration or active severe-incident control | `action_bound_step_up` | 5 minutes | phishing-resistant authenticator, explicit consequence, current incident posture |

Production policy may shorten these maxima or require stronger assurance; it
may not lengthen or weaken them without advancing this contract. Step-up
failure, timeout, cancellation, downgrade, or target concealment commits no
command and reveals no target existence.

## Session Security Profile

The default qualified browser-session profile has a 12-hour hard lifetime, a
30-minute idle lifetime, a warning no later than five minutes before idle
expiry, and no sliding extension beyond the hard expiry. Login, recovery,
privilege elevation, authenticator replacement, and step-up rotate the session
identifier and CSRF material. Successful login renews and clears any anonymous
session before authenticated state is written.

The cookie is Secure, HTTP-only, host-only, path `/`, and SameSite=Lax or
stricter; it has no Domain attribute. TLS is mandatory. Session state contains
only opaque identity, timestamps, nonce, assurance, and generation/revision
values. Logout revokes the current session; logout-all and account disable
increment the subject generation and terminally invalidate every session and
protected reconnect.

## Bootstrap, Recovery, Break-Glass, And Provider Outage

- Bootstrap is a one-time, locally controlled ceremony that creates the first
  named administrator subject and immediately expires its bootstrap material.
  It cannot create a shared account or bypass authenticator enrollment.
- Recovery requires an independently authenticated recovery path, rotates
  affected authenticators and all session generations, and produces immutable
  security/audit events. Knowledge questions and reusable recovery answers are
  prohibited.
- Break-glass creates a named, time-bounded, reason-bound emergency elevation
  under a distinct policy revision. It requires phishing-resistant step-up,
  cannot grant unrelated project content, cannot satisfy its own checker, and
  must trigger review and explicit expiry.
- Identity-provider outage denies new login, recovery, elevation, and expired
  session renewal. A still-current session may perform only operations already
  permitted by its exact grants and assurance. No shared operator fallback is
  activated for multi-user routes.

## Identity And Session Model

An authenticated session contains only opaque account/session identity,
creation/last-authentication times, assurance, nonce, and generation. It does
not contain reusable credentials, graph grants, project membership, cached
roles, or durable authorization outcomes.

For every request, the trusted authority builder resolves:

```text
authenticated account and session
  + current account status and assurance
  + current memberships, exact grants, and delegations
  + route-derived object and action
  + current environment and resource state
  -> current_scope + product_identity + authority + obligations
```

The same builder serves full pages, fragments, streams, APIs, commands, and
exports. It MUST NOT accept actor, role, tenant, project, graph, capability,
delegation, or authority fields from browser parameters or signals.

The closed builder and operation matrix are pinned in
[Hypermedia UI operation authorization matrix](./hypermedia-ui-operation-authorization-matrix.md)
and its machine-readable companion. The builder accepts only verified session
identity, server-resolved resource identity, current policy/graph state, and
server-observed request context. It returns a transient scope, product
identity, exact `AuthorityContext`, obligations, decision reason, policy
revision, audit correlation, and concealment/redaction posture. It never
returns a durable grant or browser-storable permission snapshot.

## Role Vocabulary And Capability Mapping

The initial role vocabulary is organizational metadata:

- observer;
- project developer;
- project maintainer;
- independent verifier;
- factory operator;
- security auditor;
- factory administrator;
- knowledge steward; and
- cost observer.

Every role view MUST expand to an explicit matrix of exact capability/grant,
resource scope, action, classification, environment, and obligations. A role
with no exact current grant yields no access. Exactly matching grants and graph
ownership checks remain authoritative.

Roles are navigation and explanation labels only. Combining role labels never
unions capabilities. Observer, project developer, project maintainer,
independent verifier, factory operator, security auditor, factory
administrator, knowledge steward, and cost observer each have an owned
navigation vocabulary in the matrix, but every `exact_grants` set is empty by
design. An operation succeeds only through the current graph capability,
membership, delegation, and resource decision.

Complete-memory content, security audit detail, identity/policy
administration, provider/credential operations, source publication/application,
verification, decision, incident control, backup/restore, export, and erasure
use distinct capabilities.

## Delegation Contract

A human delegation records an immutable delegation reference, issuer subject,
delegate subject, exact resource set, actions, graph families, environment,
valid-from/to interval, policy revision, delegation revision, attenuation
parent when present, and revocation generation. It is non-transitive by
default. A delegate cannot widen resources, actions, graph families,
environment, validity, assurance, classification, or obligations; attenuation
can only narrow them.

Delegation never follows a role label, project navigation, browser state, or
agent relationship. Agent execution continues to require the distinct
`delegated_agent_iri` and `delegation_iri` pair already enforced by
`JidoCode.Knowledge.Authorization`. Expired, revoked, ambiguous, multiply
matching, or revision-stale delegation denies the operation.

## Deny-By-Default Decision

Every operation intersects the authenticated subject/session, account status,
current membership, exact graph grant, optional exact delegation, assurance
and authentication age, resource containment, classification, environment,
lifecycle, policy revision, graph revisions, incident posture, and fence when
the operation is fenced. Missing or non-unique evidence denies.

Decision output uses only the closed outcomes `allowed`,
`concealed_not_found`, `redacted`, `denied`, `unavailable`, `revoked`, and
`step_up_required`. Unknown and unauthorized concealed resources share an
exterior class. Redaction is permitted only after the enclosing resource is
authorized. Safe reasons identify policy categories, not protected resource,
grant, role, graph, or delegation facts.

## Authentication Assurance And Step-Up

The authentication profile declares supported authenticators, phishing-
resistance, recovery, enrollment, session lifetimes, idle warning, and step-up
age. High-risk actions require a current assurance result bound to the action
request. Step-up MUST preserve safe unsent form state and remain accessible to
password managers, paste, passkeys, and non-cognitive alternatives.

Failure, timeout, cancellation, or downgrade of step-up commits no command and
does not reveal whether a concealed target exists.

## Authorization Enforcement Points

Authorization runs:

1. before full-page routing/rendering;
2. before a Dstar/SSE response starts;
3. before every reviewed projection and field composition;
4. before topic subscription and every emitted protected patch;
5. before semantic command construction and again in the gateway;
6. before export, download, or signed-link construction; and
7. before audit/incident/complete-memory detail is rendered.

Cached navigation may improve usability but is not an enforcement point.

## Live Revocation

Account disable, role/grant/delegation change, membership removal,
classification change, incident policy, or session revocation increments the
relevant generation and publishes an independent revocation event. Protected
streams also have hard expiry and periodic checks; they do not wait for a graph
projection hint.

Revocation stops future delivery and best-effort replaces protected fragments
for connected clients. The server does not claim it can erase bytes already
delivered to an offline or malicious browser.

## Canonical Approval And Separation Of Duty

Approval records contain principal, assurance, action digest, target, scope,
parameters/effect, expected revisions/fence, policy revision, reason, expiry,
idempotency, and result receipt. Agent/source text is supporting content and
cannot supply these fields.

Policy can require two distinct principals for exact actions. The verifier,
decider, publisher/applicator, security administrator, or incident reopen actor
MUST satisfy explicit independence rules rather than a UI role label.

## Concealment And Field Security

Unknown and unauthorized resources share status/body/timing classes within the
qualified envelope. Aggregates query only authorized rows; the server does not
compute global counts and hide individual records. Protected labels, graph
family names, sibling previews, candidate existence, source snippets, memory
content, and telemetry are removed before HEEx rendering.

## Audit

Audit records distinguish authentication, authorization decision, semantic
command, external effect, security event, and user-facing activity. They record
safe actor/action/object/time/outcome/policy/receipt identities and omit
credentials, raw tokens, hidden reasoning, and unnecessary protected content.

## Verification Matrix

- account enrollment, disable, recovery, and authenticator replacement;
- idle/absolute timeout, warning, step-up, cancellation, and safe form restore;
- role/grant/delegation/membership changes across pages, streams, and commands;
- IDOR and cross-tenant/project/attempt/interaction-session/graph probes;
- field-level redaction, aggregate side channels, unknown/unauthorized parity;
- two-human conflicting commands and separation-of-duty races;
- stream hard expiry, revocation, reconnect suppression, and offline limits;
- audit completeness, integrity, classification, and retention; and
- accessible authentication across the supported browser/AT matrix.

## Acceptance And Reopening

The architecture contract is accepted by HUI-A2 only with its exact manifests,
policy fixtures, deterministic state models, architecture checks, and pinned
merged-candidate receipt. Named-human product use remains unavailable until
real-adapter evidence and zero cross-scope disclosure close the later
implementation and release gates.

The contract reopens if any browser field becomes authority; an identity class
is conflated; a role widens exact grants; a session lifetime or assurance age
exceeds the accepted ceiling; bootstrap, recovery, break-glass, or provider
outage restores shared authority; session revocation leaves future delivery
open; a high-risk action bypasses current assurance or separation; aggregates
leak concealed data; or controller, fragment, stream, API, export, and command
identities diverge.
