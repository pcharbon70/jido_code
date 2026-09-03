# Hypermedia UI Milestone A Phase 2 Identity And Authorization Receipt

## Status

This receipt records the HUI-A2 implementation candidate prepared on
2026-09-03. ADR 0009 and the identity/authorization contract are accepted for
architecture authority only. Named-human adapters, multi-user route admission,
live delivery, approval UI, incident controls, exports, and release use remain
unavailable until their later milestone gates close.

Status remains **merge-pending**. The implementation pull request must pass
clean-checkout CI and merge before a documentation-only closure may pin the
full merge commit and authorize Milestone A Phase 3.

## Candidate Provenance

| Scope | Commit |
| --- | --- |
| Accepted HUI-A1 closure baseline | `133b66187828668b61a65b4d2ab5a9033fe56a15` |
| Section 2.1 | `3dfc6460a5348a384229a97d2a96a4c75e745c15` - accepted identity, assurance, session, and compatibility authority |
| Section 2.2 | `5213b771441cf74ae4caaf3a02e204fd39df5363` - frozen scope, role, delegation, and operation authorization matrix |
| Section 2.3 | `175af1a0096a9df3d770ffeae8118ca97be2c1b3` - deterministic approval, concurrency, and live revocation authority |
| Section 2.4 | Merge-pending implementation commit containing this receipt |
| Merged candidate | Merge-pending |

## Artifact Identity

| Artifact | SHA-256 |
| --- | --- |
| Identity and assurance manifest | `08aa65bb371ae1abc9ace8bea718acedf5a740205659a53935a77e08252fa726` |
| Authorization matrix manifest | `9737b22c91492eabf46e6f40fec8fca54eca07f324025fbfd51353b4b195fbcf` |
| Approval and revocation manifest | `a8a4266d6d790ee5f021d95637becec58687d9ad2e430ca8b150628312126c0c` |
| Policy scenario manifest | `00e9ad25109da6077292c8360cc65978f52bd61576a51588d201d946ad4ba125` |
| ADR 0009 | `8c60f5062bab31da0626df961d2af75beda599c27fee601ae0e50472e6f29180` |
| Identity and authorization contract | `9d1abdf7a4b44dd1073aba4ec02cc18a1e40bb2b640955a83e1ed02fb898e6cd` |
| Operation authorization document | `ae27faad7614ebfd7eb57e8d5eb912079926f546b1ed97b509928b5786d3f308` |
| Approval and revocation document | `00d10063350ea38f431e9f57b6e28aa722d6e5838c3ad8dd859a15e049c62c22` |
| HUI-A2 threat trace | `744e98c5c4ad31a3d914d2f4a047620e5ce0a422ae1ccdf872e5d7f29a3f51b2` |
| HUI-A2 validator source | `90c4ebda7619f27276027ea589a46e8ed77875ea1b183e688385970dae524996` |
| HUI-A2 integration test | `35bba77431fa017c2708dbe3a0559de95adb3864b70ac02e7f6d0e0fa38219f5` |

## Accepted Decision Tables

- Three disjoint principal classes and six immutable-reference identity record
  types separate humans, services, agents, authenticators, sessions,
  authentication/recovery, and audit evidence.
- `baseline`, `phishing_resistant`, and `action_bound_step_up` assurance have
  exact 12-hour, four-hour, ten-minute, and five-minute action-risk age
  ceilings. The qualified session profile has a 12-hour hard lifetime,
  30-minute idle lifetime, and five-minute warning.
- Bootstrap, recovery, break-glass, and identity-provider outage are closed
  exceptional flows. None restores a shared multi-user operator.
- Nine role labels own navigation/explanation only and contain zero grants.
  The authority builder has a closed trusted-input/output contract and rejects
  browser authority fields.
- Twenty-seven operation rows cover pages, fragments, queries, fields, search,
  detail, streams, patches, commands, exports, downloads, approvals, and
  incidents. Twenty-four rows resolve exact query/command protocol `2.11.0`
  capabilities; three future rows remain explicitly unavailable.
- Ten reauthorization points cover response start, query, field shaping,
  subscription, every patch, command construction/gateway, approval commit,
  export creation, and every retrieval.
- Six approval states and five guarded transitions bind a deterministic
  `hui_action_v1` digest, distinct current checkers, policy quorum, expiry,
  revisions, generations, lifecycle, and fence.
- Four compare-and-set outcomes permit at most one conflicting winner and give
  duplicates/losers/stale callers canonical safe receipts without redispatch.
- Account, session, role, delegation, project, tenant, graph, and incident
  revocation have independent monotonic generations and a five-state terminal
  protected-delivery model.

## Fixture And Threat Evidence

The machine corpus contains 52 deterministic scenarios: 26 authorization, 11
approval/concurrency, and 15 revocation/delivery cases. It traces all nine
accepted HUI-A2 threats and includes:

- representative page, field, stream, patch, command, approval, incident,
  export, and download decisions;
- cross-tenant, project, attempt, interaction-session, graph, and copied opaque
  reference probes;
- browser role-union attempts, expired delegation, stale step-up, concealed
  resources, field redaction, stale policy, and stale fence;
- maker/checker separation, duplicate and distinct checker quorum, expiry,
  invalidation, compare-and-set winner, idempotent duplicate, conflict loser,
  and pre-commit revocation; and
- every revocation dimension, safe fragment replacement, terminal stream
  close, reconnect suppression, export retrieval invalidation, and the honest
  offline-byte limit.

Review authority remains with the ADR/contract owners: JidoCode security,
identity, product, Knowledge, audit, and operations maintainers. Independent
real-adapter and browser security review remains a Milestone G release block.

## Verification Record

| Command or gate | Candidate result |
| --- | --- |
| Compiled protocol `2.11.0` query/command binding probe | Passed for all 24 current registry rows |
| Focused HUI-A2 schema, registry, policy, hostile, concurrency, and falsification suite | 7 tests, 0 failures |
| Existing authority, approval, authentication, memory-authorization, and query-concealment regression matrix | 36 tests, 0 failures |
| `mix architecture.check` | Passed with source, HUI-A1, and HUI-A2 gates returning zero findings |
| `mix precommit` | Passed; 1,165 tests, 0 failures, with formatting, unused-dependency, compile, and combined architecture gates clean |
| Dependency audits and production asset build | Pending clean-checkout CI |
| Clean-checkout CI | Merge-pending |

## Unresolved Risks And Accepted Limits

- The current product still authenticates one configured operator. HUI-A2
  narrows its compatibility posture but does not implement named accounts,
  authenticators, per-human audit, or multi-user route admission.
- No named-human authority builder is composed across controller, fragment,
  stream, API, export, and command adapters. Milestones C through G own that
  implementation and qualification.
- The future approval-commit, incident-control, and browser export-retrieval
  bindings have no versioned semantic registry entry and remain unavailable.
- No product stream or patch adapter implements live revocation. The state
  model is binding for future implementation but receives no runtime credit.
- Existing backend approval contracts remain authoritative for their current
  qualified scope; they do not satisfy named-human quorum or browser release.
- The server cannot erase protected bytes already delivered to an offline or
  malicious client.

## Gate HUI-A2

Status: **merge-pending**

HUI-A2 remains open until clean-checkout CI passes, the implementation pull
request merges, and a closure receipt pins the exact merge SHA and date.
Milestone A Phase 3 is not authorized from this merge-pending candidate.

HUI-A2 reopens regardless of checklist state if human, service, and agent
principal classes conflate; a shared human or compatibility operator enters a
multi-user posture; a browser field, role label, navigation item, cached
decision, opaque reference, open connection, or signed link grants authority;
an operation is missing from the matrix; a current registry binding or graph
capability widens; a future binding is advertised as available; delegation is
implicit, transitive, ambiguous, expired, revoked, or stale; session or
assurance ceilings weaken; bootstrap, recovery, break-glass, or provider outage
restores shared authority; concealment, redaction, or safe reason output leaks
protected existence, count, label, role, grant, delegation, graph, or policy
facts; self approval or duplicate humans make quorum; an action digest omits a
bound consequence, revision, generation, lifecycle, expiry, idempotency, or
fence; stale approval commits; more than one conflicting effect wins; a loser
lacks the canonical safe current receipt; account, session, role, delegation,
project, tenant, graph, or incident revocation leaves future delivery,
reconnect, export, or download open; prior browser bytes are falsely claimed
erased; any HUI-A1 reopening condition triggers; or architecture checks,
documentation validation, precommit, or clean-checkout CI fails at the exact
candidate.
