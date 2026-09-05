# Hypermedia UI Milestone C Phase 1 Receipt

## Status

Status: **merge-pending**

This receipt records the local HUI-C1 implementation candidate. It does not
accept HUI-C1 or authorize Milestone C Phase 2 until the implementation pull
request passes clean-checkout CI, merges, and a closure pull request pins the
full merged candidate and merge date.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-B4 closure baseline | `797e308bc16b609eb6273d07ae96ee47a4cc3512` - closure PR #116 |
| Accepted HUI-B4 implementation candidate | `63d2689321121775a46bf531d004ac4de44b81f2` - implementation PR #115 |
| Section 1.1 | `d169129c53f15745f0ebac87f625df3cc0fe130a` - named account and authenticator foundations |
| Section 1.2 | `2d08df156932fae479c485bae9a8d6bb79139555` - browser session lifecycle and security |
| Section 1.3 | `1a04872b1295ef4985bb51bae5cb45530e92a397` - trusted scope, authority, membership, and revocation construction |
| Section 1.4 | merge-pending - integration matrix, full verification, and receipt preparation |
| Implementation PR head | merge-pending |
| Merged candidate | merge-pending |

Merged candidate: merge-pending
Merge date: merge-pending

## Identity And Authenticator Evidence

`JidoCode.Identity.Store` is the exclusive named-human account,
authenticator, session, membership, delegation, resource-registry, revocation,
and audit authority for this phase. Durable snapshots use an HMAC-SHA-256
integrity envelope, atomic replacement, and owner-only file permissions.
Local credentials use PBKDF2-HMAC-SHA-256 with per-credential salts and
bounded failure lockout. Credential verifier material is separated from public
account/authenticator records.

One-time local bootstrap, governed named-account enrollment, sign-in,
credential rotation, independent recovery adapter integration, account
disablement, current-session logout, and logout-all have safe outcomes and
immutable audit evidence. Browser use of the legacy shared operator is
prohibited; that operator remains compatibility-API-only. Phishing-resistant
authentication, action-bound step-up, and recovery remain explicitly
unavailable when their production adapters are not composed.

## Browser Session Evidence

The browser cookie contains only the framework's encrypted/signed opaque
session reference and CSRF state. Production configuration pins Secure,
HTTP-only, host-only, path `/`, and SameSite=Lax behavior. Every protected
request validates server-held session and account state, hard and idle expiry,
authentication age, policy revision, and session/account generations.

Successful authentication renews and clears the anonymous session, rotates
the CSRF/session material, and refuses caller-elevated assurance. Credential
rotation, recovery, logout-all, disablement, administrative revocation, and
current-session logout invalidate future use. Browser writes require CSRF plus
same-origin/Fetch Metadata admission. Return paths accept only bounded local
paths. Session telemetry and audit omit cookies, credentials, verifier
material, nonce values, protected content, and reusable tokens.

## Scope And Authority Evidence

`JidoCode.Identity.AuthorityBuilder` is the single named-human constructor used
by the controller and retained compatibility UI boundary. It accepts a
validated server session reference and a closed route-owned request. Browser
actor, principal, role, tenant, project, graph, grant, delegation, assurance,
classification, environment, revision, and generation fields are rejected or
have no input path.

The constructor resolves current memberships, exact optional delegation,
opaque resource containment, route group, clearance, lifecycle, assurance,
policy revision, and all independent revocation generations before asking the
configured adapter for one exact current grant. A final atomic generation,
session, account, and resource-revision confirmation closes the local
revocation race before the decision is returned and audited. Adapter crashes,
malformed output, ambiguous current evidence, audit persistence failure, and
unconfigured graph authority fail closed.

Role labels are explanation only. Factory scope requires exact tenant-level
membership; project and child scopes require the exact project membership.
Project, attempt, interaction-session, candidate, wiki-preview, and graph
references remain distinct immutable registry records. Unknown, tampered,
cross-tenant, and cross-project references remain concealed.

The decision vocabulary is `allowed`, `concealed_not_found`, `redacted`,
`denied`, `unavailable`, `revoked`, and `step_up_required`. Reauthorization
hooks rebuild current state before response, query, field shaping, stream
subscription, protected patches, command construction and gateway admission,
approval commit, export creation, and every download retrieval.

## Membership, Delegation, And Revocation Evidence

The seven independent route groups are developer, reviewer, operations,
security, cost, knowledge, and administration. Membership and delegation reads
are bounded, validity-aware, policy-aware, and deterministic. Membership,
delegation, and resource identities cannot be rebound through an existing
opaque reference. Delegation attenuation cannot widen subject binding,
resources, actions, graph families, environment, validity, assurance,
classification, or obligations; multiple exact delegation matches deny.

Account, session, role, delegation, project, tenant, graph, and incident
dimensions publish privacy-safe monotonic invalidation events. Membership,
delegation, account, session, registry, graph, and incident transitions each
advance the applicable current generation. Stale compare-and-increment inputs
are rejected. Notifications are hints only; authorization always rereads
server state.

## Integration Verification

The focused local matrix passes 51 tests with zero failures across
account, authenticator, session, authority, resource isolation, controller,
CSRF/Origin, return-path, and retained compatibility UI behavior. It covers
all role explanations and route groups, exact grants, redaction, concealed
resources, unavailable and malformed adapters, assurance escalation refusal,
membership/delegation expiry and revocation, immutable reference binding,
all resource kinds, several named humans and tabs, concurrent revocation,
stale generations, and every reauthorization checkpoint.

The executable HUI-C1 evidence pins the accepted HUI-B4 predecessor, unchanged
dependency/component/asset evidence, production identity/session posture,
closed authority vocabulary, route/resource/revocation matrices, section
commits, and exact source digests. Architecture checking rejects predecessor
drift, browser authority, source drift, reordered phase completion, weakened
invariants, and false receipt lifecycle claims.

Strict production compilation passed with warnings as errors. The repository
`mix precommit` gate passed 1,270 tests with zero failures. Its existing
test-only warnings remain visible and are not production compile warnings.
Clean-checkout CI remains merge-pending and must pass before acceptance.

## Configuration, Exceptions, And Limitations

The production named-human graph-authority adapter is explicitly
`JidoCode.Identity.Authority.Unconfigured`; it returns `unavailable`. The
deterministic static, delegation-required, malformed, and crashing adapters
are test-only fixtures. No HUI-C1 test adapter or bootstrap credential is a
production authority claim.

There are no HUI-C1 architecture exceptions. This phase does not authorize a
new product page, fragment, SSE coordinator, field, query, semantic command,
approval, export, or download. It does not claim a production identity
provider, phishing-resistant authenticator, step-up ceremony, recovery
provider, graph-grant adapter, incident evaluator, two-human approval, or
assistive-technology/browser release matrix. Those capabilities remain
unavailable until their later gates close.

## Gate HUI-C1 Reopening Conditions

HUI-C1 remains merge-pending and reopens if HUI-B4 reopens; if shared-operator
browser authority returns; if a human, service, agent, recovery actor, or
compatibility operator is conflated; if any browser parameter, header, signal,
DOM value, cookie value, URL, navigation item, disabled control, role, or
cached decision supplies actor, authority, assurance, grant, delegation,
scope, classification, environment, revision, incident, fence, or generation;
if credentials, verifier material, cookies, reusable tokens, protected
content, or hidden policy facts enter logs, telemetry, audit, HTML, or browser
storage; if bootstrap is reusable or remotely invocable; if recovery is not
independent; or if unavailable authentication is presented as ready.

The gate also reopens if session fixation, rotation, CSRF, Origin, Fetch
Metadata, secure cookie, idle/hard expiry, authentication-age, account/session
generation, logout, logout-all, credential-event, disablement, administrative
revocation, or safe-return behavior regresses; if a role or route group becomes
an exact grant; if a tenant membership crosses into a project; if resource
kinds or immutable bindings collapse; if delegation widens, becomes
transitive, expires without denial, revokes without denial, or matches
ambiguously; if clearance, assurance, policy, lifecycle, containment, graph
revision, incident posture, or exact adapter evidence is skipped; if unknown
and unauthorized concealed exteriors diverge; if redaction occurs after
rendering; or if adapter/persistence failure opens access.

Finally, the gate reopens if account, session, role, delegation, project,
tenant, graph, or incident generation ceases to advance monotonically; if a
protected response, query, field, stream, patch, command, approval, export, or
download skips its required current reauthorization; if a concurrent
revocation can return a stale confirmed grant; if predecessor digests,
identity/session/policy versions, source digests, test fixtures, exceptions,
limitations, or any reopening condition drift; or if strict compilation,
architecture/privacy/security tests, `mix precommit`, or clean-checkout CI
fails at the candidate.
