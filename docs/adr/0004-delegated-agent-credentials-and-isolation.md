# ADR 0004: Delegated-Agent Credentials And Isolation

- Status: Accepted
- Date: 2026-08-26
- Owners: JidoCode security, runtime, and operations maintainers
- Decision scope: Authentication, credential delivery, sandboxing, and managed deployment
- Depends on: [ADR 0003](./0003-first-class-delegated-coding-agents.md)
- Related contracts:
  [Product security and threat model](../architecture/product-security-privacy-and-threat-model.md),
  [Harness Phase 4 receipt](../architecture/harness-phase-04-receipt.md), and
  [Harness Phase 5 receipt](../architecture/harness-phase-05-receipt.md)

## Context

Developer coding CLIs commonly authenticate through an existing local
subscription login, reusable OAuth material, a provider-managed credential
cache, or an API credential. Those mechanisms are designed for an interactive
developer workstation, not necessarily for untrusted repository code running
inside a managed sandbox.

JidoCode's current developer-local Pi profiles record only an opaque reference
to an existing login and make no managed-fleet security claim. Managed
delegated execution remains blocked because no provider-specific credential
helper or credential-attaching proxy has proven that the CLI can authenticate
while its repository-controlled descendants cannot read, copy, refresh, or
reuse the credential.

Granting a coding CLI broad host environment access would undermine the
accepted sandbox, secret, tenant-isolation, and publication boundaries. At the
same time, requiring all developers to abandon subscription CLIs would make the
harness path materially less useful.

## Decision

JidoCode will support two explicitly different delegated deployment classes:

- `developer_local` permits explicit use of an existing local provider login
  only inside an attested isolated worker. It is an acknowledged local trust
  exception, is never silently selected, and does not inherit managed-fleet
  claims.
- `managed_fleet` requires a provider-specific credential helper, workload
  exchange, or credential-attaching proxy that proves least-privilege delivery
  without exposing reusable credential material to the CLI's repository tool
  descendants.

Every delegated-agent profile binds exactly one deployment class,
authentication kind, billing mode, provider audience, credential class, and
credential-delivery mechanism. Changing any of them creates a new profile and
requires independent qualification.

### Universal Rules

For both deployment classes:

1. Secret bytes MUST NOT enter RDF, model context, prompts, argv, retained
   journals, telemetry, diagnostics, PubSub, browser state, candidate
   artifacts, or test fixtures.
2. The graph stores only a `CredentialReference`, class, audience, scope,
   ownership, expiry policy, fingerprint, and monotonic revocation generation.
3. Credential release is authorized at the effect linearization point against
   actor, tenant, repository, provider, attempt, lease, fence, profile digest,
   adapter identity, audience, scope, expiry, and revocation generation.
4. The launch environment is replaced by a minimal allowlist. Ambient host
   environment inheritance is forbidden.
5. The sandbox receives no graph handle, publication credential, merge
   credential, SSH agent, Docker socket, unrelated repository, or host
   filesystem access.
6. Provider egress is denied except through the profile's accepted endpoint or
   attaching proxy. Repository-controlled arbitrary egress remains denied.
7. Provider, authentication, billing, or credential fallback is forbidden.
8. Cancellation or lease expiry revokes outstanding release permits before
   process termination; late provider or workspace results are fence-rejected.

### Developer-Local Rules

A developer-local launch additionally requires:

- an authenticated actor's explicit, unexpired consent for the exact profile;
- a billing acknowledgement when a live request may consume subscription or
  metered capacity;
- an attestation for the exact worker image, disposable worktree, mounts,
  network policy, process boundary, and credential-reference mode;
- a clear product label that the profile is local, opt-in, and not managed;
- no automatic background scheduling; and
- destruction of the workspace, process namespace, and controller-owned
  journal retention at the configured terminal boundary.

A local login cache may not be mounted wholesale. The provider-specific
adapter must use the narrowest proven attachment supported by that provider.
If the provider cannot isolate reusable material from repository descendants,
the profile remains disabled or read-only.

### Managed-Fleet Rules

A managed-fleet launch additionally requires:

- short-lived, attempt-bound, audience-bound material or an attaching proxy;
- no readable or writable shared login cache;
- serialized refresh ownership outside the untrusted process tree;
- tenant-separated credential references and worker identities;
- provider-specific revoke, rotation, outage, and ambiguous-use procedures;
- production sandbox, credential, egress, cancellation, and exfiltration
  evidence; and
- operator grants and rollout approval for the exact profile.

Static reusable credentials delivered to the CLI environment are not eligible
for managed delegated execution. A provider that cannot meet the helper,
exchange, or attaching-proxy boundary cannot receive a managed profile.

## Consequences

### Positive

- developers can use subscription coding agents without pretending local
  authentication has managed-fleet isolation guarantees;
- provider onboarding has a precise security target;
- compromise of repository-controlled descendants does not automatically
  disclose reusable provider or publication authority; and
- credentials, billing, and rollout remain independently auditable.

### Costs And Constraints

- each provider may require a different helper or proxy implementation;
- some CLIs may remain developer-local or disabled because their credential
  cache cannot be safely separated;
- readiness and live-smoke probes require explicit consent and provider-aware
  handling; and
- local convenience is constrained by sandbox and egress policy.

## Alternatives Rejected

- **Mount the developer's home or provider configuration directory:** this
  exposes unrelated secrets and durable provider state.
- **Copy login tokens into the worker environment:** repository descendants
  can read and reuse them.
- **Use a single shared fleet login:** it defeats tenant, actor, billing, and
  revocation attribution.
- **Fall back to an API key or another provider:** it silently changes trust,
  billing, capability, and evaluation assumptions.
- **Trust the CLI to hide its own credentials:** the CLI and its descendants
  are inside the effect boundary, not the authorization boundary.

## Implementation Acceptance And Reopening Conditions

The credential and isolation decision is accepted, but a write-capable
provider profile remains disabled until it proves:

1. credential canaries are absent from argv, environment visible to tool
   descendants, prompts, journals, output, artifacts, and diagnostics;
2. the authenticated provider action succeeds through the declared helper,
   exchange, or attaching proxy;
3. stale fence, expired permit, revoked generation, wrong audience, wrong
   actor, wrong repository, and wrong adapter requests fail before release;
4. cancellation terminates the full process namespace and prevents later
   credential use or result adoption;
5. provider outage and ambiguous authentication outcomes reconcile without
   fallback;
6. credential rotation and incident disable drills pass; and
7. the deployment-class label and residual risks are visible to the operator
   before launch.

Acceptance of a developer-local provider profile does not accept its
managed-fleet counterpart. Each deployment class requires separate evidence.
The decision reopens if reusable material reaches a repository-controlled
descendant, if authentication or billing falls back, if credential release is
not bound to the current lease and fence, or if developer-local evidence is
used to claim managed-fleet isolation.
