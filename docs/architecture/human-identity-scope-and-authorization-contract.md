# Human Identity, Scope, And Authorization Contract

- Status: Proposed under ADR 0009
- Specification version: `0.1.0`
- Owners: JidoCode identity, security, product, and audit maintainers
- Milestones: A, C, and G
- Decision: [ADR 0009](../adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md)

## Purpose

This specification defines the trusted server boundary that turns an
authenticated named human into current Product scope and exact graph authority.
It defines sessions, roles, memberships, delegations, step-up, approvals,
revocation, concealment, and audit without making UI visibility an access
control.

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

Complete-memory content, security audit detail, identity/policy
administration, provider/credential operations, source publication/application,
verification, decision, incident control, backup/restore, export, and erasure
use distinct capabilities.

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

The contract closes only with named-account real-adapter evidence and zero
cross-scope disclosure. It reopens if any browser field becomes authority; a
role widens exact grants; session revocation leaves future delivery open; a
high-risk action bypasses current assurance or separation; aggregates leak
concealed data; or controller, SSE, API, and command identities diverge.
