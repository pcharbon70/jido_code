# Hypermedia UI Milestone C Phase 1 Receipt

## Status

Status: **accepted-at-merged-candidate**

This receipt accepts the HUI-C1 implementation at the merged candidate below.
Implementation PR #117 passed clean-checkout CI and merged on 2026-09-05.
Milestone C Phase 2 is authorized only from this pinned baseline while every
reopening condition below remains in force.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-B4 closure baseline | `797e308bc16b609eb6273d07ae96ee47a4cc3512` - closure PR #116 |
| Accepted HUI-B4 implementation candidate | `63d2689321121775a46bf531d004ac4de44b81f2` - implementation PR #115 |
| Section 1.1 | `d169129c53f15745f0ebac87f625df3cc0fe130a` - named account and authenticator foundations |
| Section 1.2 | `2d08df156932fae479c485bae9a8d6bb79139555` - browser session lifecycle and security |
| Section 1.3 | `1a04872b1295ef4985bb51bae5cb45530e92a397` - trusted scope, authority, membership, and revocation construction |
| Section 1.4 | `5a95c5a655e5f11951a172501ce8b537d08d312c` - integration matrix, full verification, and receipt preparation |
| Implementation PR head | `0cfc67ea0537fdf5833f9fbd483cc653a7e4b06d` - PR #117 clean-checkout candidate |
| Merged candidate | `4a6fa78443463a8c8cd8ed039119cef8ba6e3b1b` - PR #117 |

Merged candidate: `4a6fa78443463a8c8cd8ed039119cef8ba6e3b1b`
Merge date: `2026-09-05`

## Identity And Authenticator Evidence

`JidoCode.Identity.Store` exclusively owns named-human accounts,
authenticators, sessions, memberships, delegations, resources, revocations,
and audit for this phase. Its atomically replaced, owner-only snapshots use an
HMAC-SHA-256 envelope; local credentials use salted PBKDF2-HMAC-SHA-256 with
bounded lockout and private verifier material.

Bootstrap is one-time and local. Enrollment, sign-in, rotation, independent
recovery, disablement, logout, and logout-all produce immutable audit evidence.
The legacy shared operator is API-only. Uncomposed phishing-resistant,
action-bound step-up, and recovery adapters remain explicitly unavailable.

## Browser Session Evidence

The encrypted/signed browser cookie holds only an opaque session reference and
CSRF state, with Secure, HTTP-only, host-only, path `/`, and SameSite=Lax
configuration. Each protected request checks server-held account/session state,
hard/idle expiry, authentication age, policy revision, and generations.

Authentication renews the session and refuses caller-elevated assurance.
Rotation, recovery, logout-all, disablement, administrative revocation, and
logout revoke future use. Writes require CSRF and same-origin/Fetch Metadata;
return paths are bounded and local. Telemetry and audit omit secrets, cookies,
nonces, protected content, and reusable tokens.

## Scope And Authority Evidence

`JidoCode.Identity.AuthorityBuilder` is the sole named-human constructor for
controllers and the retained compatibility boundary. It accepts a verified
server session plus a closed route-owned request; browser identity, scope,
grant, delegation, assurance, classification, revision, and generation values
have no authority path.

It resolves current membership, exact optional delegation, resource
containment, route group, clearance, lifecycle, assurance, policy, and every
revocation generation before requesting one exact adapter grant. A final atomic
session/account/generation/resource-revision check closes the revocation race.
Malformed, ambiguous, crashing, unavailable, or unpersistable evidence denies.

Role labels are explanation only. Factory scope requires exact tenant-level
membership; project and child scopes require the exact project membership.
Project, attempt, interaction-session, candidate, wiki-preview, and graph
references remain distinct immutable registry records. Unknown, tampered,
cross-tenant, and cross-project references remain concealed.

Decisions are `allowed`, `concealed_not_found`, `redacted`, `denied`,
`unavailable`, `revoked`, or `step_up_required`. Required response, query,
field, stream, patch, command/gateway, approval, export, and download boundaries
rebuild current authority.

## Membership, Delegation, And Revocation Evidence

Developer, reviewer, operations, security, cost, knowledge, and administration
are independent route groups. Bounded current membership and delegation reads
cannot rebind opaque identities. Delegation cannot widen subject, resource,
action, graph family, environment, validity, assurance, classification, or
obligations; ambiguous exact matches deny.

Account, session, role, delegation, project, tenant, graph, and incident
dimensions publish privacy-safe monotonic invalidation events. Membership,
delegation, account, session, registry, graph, and incident transitions each
advance the applicable current generation. Stale compare-and-increment inputs
are rejected. Notifications are hints only; authorization always rereads
server state.

## Integration Verification

The focused 51-test matrix passes account, authenticator, session, authority,
isolation, controller, CSRF/Origin, redirect, compatibility, exact-grant,
redaction, concealment, adapter-failure, assurance, expiry/revocation,
immutable-binding, multi-user/tab, race, stale-generation, and reauthorization
cases. Executable evidence pins HUI-B4, dependency/component/asset evidence,
production posture, vocabularies, matrices, section commits, and source digests;
architecture checks reject drift, browser authority, reordered completion,
weakened invariants, and false lifecycle claims.

Strict production compilation passed with warnings as errors. The repository
`mix precommit` gate passed 1,270 tests with zero failures. Its existing
test-only warnings remain visible and are not production compile warnings.
PR #117 clean-checkout CI passed: Dialyzer job `101294558289` in 1m51s and
verification job `101294558445` in 18m35s.

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

HUI-C1 is accepted at the merged candidate above and reopens if HUI-B4 reopens;
if shared-operator
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
