# Delegated Coding Agent Profile And Catalog Specification

- Status: Approved and normative under accepted ADRs 0003 and 0004
- Specification version: `0.1.0`
- Owners: JidoCode runtime and product maintainers
- Decisions:
  [ADR 0003](../adr/0003-first-class-delegated-coding-agents.md) and
  [ADR 0004](../adr/0004-delegated-agent-credentials-and-isolation.md)
- Extends: harness contract `1.0.0` and managed-coding contract `7.0.0`

## Purpose

This specification makes delegated coding CLIs discoverable, selectable, and
governable as product agents without treating their processes or provider
sessions as durable authority. It defines the semantic profile, closed adapter
registry, lifecycle, catalog projection, and exact selection rules needed to
move beyond the current Pi deny-all and read-only developer-local profiles.

This specification proposes additive resources and new contract revisions. It
does not reinterpret an existing `HarnessProfile` or enable a blocked adapter.

## Terms

| Term | Meaning |
| --- | --- |
| `ManagedCodingProfile` | Existing signed product envelope for task, actor, repository, model, tool, sandbox, verifier, budget, and rollout constraints |
| `ModelAccessProfile` | Existing graph resource binding access mode, provider, credential reference/class, billing, readiness, and revocation generation |
| `HarnessProfile` | Existing graph resource pinning workflow, prompt, model-access, tool-catalog, policy, and budget revisions |
| `DelegatedAgentProfile` | New immutable resource binding one external coding agent and JidoHarness adapter release to exact execution, capability, sandbox, candidate, and rollout contracts |
| `DelegatedAdapterRelease` | New immutable identity for one reviewed provider adapter, CLI compatibility range, JidoHarness revision, executable registry key, protocol, and evidence digest |
| `AgentOffering` | Disposable, scope-filtered product projection joining an enabled profile with current readiness and material limitations |

## Runtime Classification

The closed `runtimeClass` vocabulary is:

- `host_controlled` — resolved to the accepted native managed-coding runtime;
- `delegated_cli` — resolved to `JidoCode.Runtime.JidoHarnessAdapter`; and
- no other value.

`runtimeClass` is an authority-bearing field. It is part of the signed profile
digest and cannot be supplied by a task prompt, repository configuration,
browser display identifier, runtime process, or provider response.

## Delegated Agent Profile

`DelegatedAgentProfile` is immutable. A material change creates a new revision
that links to the prior profile through supersession; it never mutates the old
profile in place.

### Required Fields

| Field | Contract |
| --- | --- |
| `iri` | Deterministic resource identity for owner, stable agent key, provider, deployment class, and revision |
| `revision` | Positive monotonic revision within the stable agent key |
| `displayName` | Human-readable text, 1–128 UTF-8 bytes; never used for dispatch |
| `agentKey` | Closed lowercase identifier, 1–64 bytes, such as `codex_subscription` |
| `runtimeClass` | Exactly `delegated_cli` |
| `provider` | Closed provider identifier registered by the release |
| `harnessProfile` | IRI of one adopted `HarnessProfile` |
| `modelAccessProfile` | IRI of one enrolled `ModelAccessProfile` whose access mode is `delegated_cli` |
| `adapterRelease` | IRI of one accepted `DelegatedAdapterRelease` |
| `deploymentClass` | `developer_local` or `managed_fleet` |
| `authenticationKind` | Closed value compatible with the access profile and deployment class |
| `billingMode` | Closed value identical to the referenced access profile |
| `promptTransport` | Protected stdin or broker-owned protected file; argv is forbidden |
| `sessionPolicy` | `none` or an exact bounded session protocol with ownership and retention |
| `capabilityClass` | One closed class defined below |
| `toolManifestDigest` | SHA-256 of the complete provider/CLI tool exposure and disabled-extension configuration |
| `workspacePolicyRevision` | Exact disposable worktree and path policy revision |
| `sandboxProfileRevision` | Exact isolated-worker image, mount, namespace, and resource-limit contract |
| `networkPolicyRevision` | Exact egress destinations, protocols, and data classes |
| `credentialDelivery` | `local_reference`, `workload_exchange`, or `attaching_proxy`, compatible with ADR 0004 |
| `candidateProtocolRevision` | Exact patch, tree, artifact, and terminal receipt schema |
| `verificationProfileRevision` | Independent fresh-checkout verifier contract |
| `budget` | Finite run, turn, wall, idle, output, process, memory, disk, and cost/reporting dimensions |
| `taskClasses` | Non-empty closed list of qualified task classes |
| `languageClasses` | Non-empty closed list of qualified language/build envelopes |
| `owner`, `tenantBindings`, `repositoryBindings`, `actorBindings`, `capabilityBindings` | Exact authority and selection scope |
| `state` | Existing `disabled`, `enabled`, `revoked`, or `superseded` vocabulary |
| `rolloutStage` | Existing `disabled`, `evaluation`, `shadow`, `pilot`, or `production` vocabulary |
| `approvedAt`, `expiresAt`, `signer` | Approval provenance and finite validity |
| `profileDigest`, `signedDigest` | Deterministic full material digest and its authorized signature |

### Capability Classes

The initial closed capability classes are:

| Class | Workspace behavior | Intended use |
| --- | --- | --- |
| `deny_all` | No CLI tools | Readiness and prompt-channel conformance only |
| `bounded_read_only` | Read/search/list within the exact worktree | Analysis and privacy qualification |
| `workspace_write` | Read plus create/edit/delete only inside the disposable worktree | Candidate-producing developer use |
| `workspace_write_registered_checks` | Workspace write plus checks selected from the Factory-owned catalog | Full coding qualification |

These classes describe the outer authority ceiling. Provider-internal tool
events may be incomplete observations and MUST NOT be represented as fully
mediated host tool invocations unless the adapter proves that property. Shell,
filesystem, process, and network containment are therefore enforced by the
sandbox even when the CLI owns its internal tool loop.

No class includes graph access, arbitrary host filesystem access, provider
publication, protected-branch writes, policy mutation, evidence acceptance,
memory adoption, or merge authority.

## Delegated Adapter Release

Each `DelegatedAdapterRelease` MUST pin:

- provider and adapter key;
- JidoHarness source revision and archive digest;
- JidoHarness protocol version;
- CLI product and exact version or closed compatible version set;
- executable registry key, resolved only by application configuration;
- prompt, input, event, status, cancellation, and candidate protocols;
- supported capability and deployment classes;
- journal and session behavior;
- native and outer cancellation enforcement;
- normalized observation completeness and explicitly unavailable fields;
- conformance-corpus digest;
- security/evaluation evidence digest;
- state, approval, expiry, signer, and supersession identity.

Executable paths, adapter modules, commands, and environment fragments are
resolved from an application-owned closed registry keyed by the accepted
release. The graph never supplies code or arbitrary command arguments.

## Compatibility Rules

A profile is coherent only when:

1. the `ModelAccessProfile.accessMode` is `delegated_cli`;
2. provider, billing, and credential properties match across referenced
   resources;
3. the adapter release supports the declared CLI, deployment, credential,
   candidate, and capability classes;
4. the `HarnessProfile` tool catalog, workflow, prompt, policy, and budget pins
   match the delegated profile digests;
5. developer-local profiles use `local_reference` and are never
   `managed_eligible`;
6. managed-fleet profiles use `workload_exchange` or `attaching_proxy` and
   have current production isolation evidence;
7. every binding contains the requesting actor, tenant, repository, and
   capability at admission time;
8. profile approval and readiness evidence are current and unexpired; and
9. no referenced resource is revoked, disabled, superseded, missing, or
   outside the current graph revision.

There is no compatibility fallback. Any mismatch returns a bounded
`incompatible`, `unauthorized`, `unavailable`, or `stale` result before process
creation.

## Semantic Commands And Queries

An implementation plan MUST introduce versioned commands equivalent to:

- `RegisterDelegatedAdapterRelease`;
- `RegisterDelegatedAgentProfile`;
- `TransitionDelegatedAgentProfile`;
- `RecordDelegatedAgentReadiness`; and
- `RevokeDelegatedAgentAccess` through the existing model-access revocation
  generation where applicable.

Commands require expected dataset and graph revisions, idempotency identity,
principal, actor, scope, reason, authorization, validation, provenance, and
audit. Registration guards all referenced profiles/releases as present and the
new immutable subject as absent. Transition guards the exact current state,
revision, and predecessor.

Reviewed queries MUST include:

- `SelectableAgentOfferingsByScope` — bounded by actor, tenant, repository,
  task class, language, capability, and current time;
- `DelegatedAgentProfileDetail` — exact profile revision with material
  limitations but no credential or runtime secrets;
- `DelegatedAgentReadinessByProfile` — latest current readiness evidence for
  the exact adapter, credential generation, sandbox, and provider; and
- `DelegatedAgentProfileHistory` — bounded chronological transitions and
  supersession lineage for operators.

## Catalog Projection

An `AgentOffering` projection contains only:

- opaque presentation reference;
- display name and description;
- runtime class;
- provider and declared model/agent family;
- deployment, access, authentication, and billing classifications;
- capability summary;
- supported task and language classes;
- readiness summary with observation time and expiry;
- rollout stage;
- profile revision and digest;
- limitations and consent/billing requirements; and
- whether the current scope can select it.

The projection MUST NOT reveal credential reference IRIs, owner-global catalog
entries outside scope, executable keys, adapter module names, process details,
provider sessions, graph handles, raw SPARQL, or hidden profiles.

## Selection Algorithm

For each admission request, the Factory:

1. resolves the submitted opaque offering reference within the actor's scope;
2. loads the exact graph profile and all referenced immutable resources;
3. verifies profile signature, lifecycle, rollout, expiry, bindings, task and
   language envelopes, source snapshot, lease, fence, and capability;
4. verifies current adapter, CLI, credential-generation, sandbox, network, and
   readiness evidence;
5. computes the exact effective authority as the intersection of task policy,
   repository policy, actor grant, profile ceiling, adapter support, sandbox
   policy, and current rollout stage;
6. commits admission and the resolved profile digest before runtime dispatch;
   and
7. dispatches only through the registry entry bound to the accepted adapter
   release.

An empty candidate set fails closed. Multiple eligible profiles require an
explicit product selection or an accepted deterministic policy; provider cost,
availability, or model output cannot silently choose one.

## Current And Target Catalog

| Offering | Current posture | Required transition |
| --- | --- | --- |
| Native ReqLLM single agent | Accepted exact profile | Represent in the unified catalog without changing its runtime authority |
| Pi RPC deny-all | Developer-local, non-managed | Retain for conformance/readiness only |
| Pi RPC read-only | Developer-local, non-managed | Retain for analysis/privacy qualification only |
| Write-capable Pi | Absent | New profile, adapter evidence, candidate protocol, live qualification |
| Codex, Claude, Gemini, OpenCode, Amp, Grok, Kimi | Built-in adapters blocked | One independently pinned and qualified profile per provider/CLI |
| Z.AI | Blocked, including unproven native cancellation | Cancellation and full profile evidence before any admission |

## Conformance Requirements

Tests MUST prove:

- deterministic identity and digest stability;
- closed vocabularies and required-field bounds;
- orphan, duplicate, stale-revision, mismatched-provider, mismatched-billing,
  mismatched-deployment, and expired-profile rejection;
- no-fallback dispatch under missing executable, provider outage, or readiness
  failure;
- scope-filtered catalog non-disclosure;
- prompt/repository content cannot influence profile or adapter selection;
- revocation and supersession immediately remove selection eligibility;
- old attempts retain exact historic identity without becoming restart
  authority under an incompatible release; and
- native and delegated offerings produce the same bounded product identity
  shape while retaining honest runtime-class differences.
