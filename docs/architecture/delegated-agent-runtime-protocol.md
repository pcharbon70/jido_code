# Delegated Coding Agent Runtime Protocol Specification

- Status: Approved and normative under accepted ADRs 0003 and 0004
- Specification version: `0.1.0`
- Owners: JidoCode Factory, runtime, security, and verification maintainers
- Profile specification: [Delegated coding agent profile and catalog](./delegated-agent-profile-catalog.md)
- Existing port: `JidoCode.Factory.Ports.ExecutionRuntime`

## Purpose And Boundary

This specification defines how one graph-authorized attempt delegates coding
work to one external CLI through JidoHarness. It upgrades the existing
developer-local deny-all/read-only boundary into a candidate-producing path
without granting the delegated agent graph, policy, verification, publication,
or merge authority.

The delegated CLI owns its internal prompts, model turns, planning, and tools.
JidoCode owns everything outside that opaque loop:

```text
graph admission and exact profile
  -> isolated workspace and protected credential attachment
    -> JidoHarness process lifecycle
      -> provider-owned internal coding loop
        -> bounded workspace result and candidate receipt
          -> independent fresh-checkout verification
            -> governed decision and human publication authorization
```

## Runtime Operations

The protocol retains the existing closed execution-runtime operations:

| Operation | Required behavior |
| --- | --- |
| `prepare` | Reauthorize and create only disposable local run identity; perform no provider call or workspace mutation |
| `start` | Reauthorize, construct the launch envelope, commit invocation-before-effect facts, and create the isolated process |
| `signal` | Deliver bounded steering or clarification input through protected stdin after current lease/fence checks |
| `status` | Return bounded normalized lifecycle observations; never infer provider-internal state |
| `cancel` | Commit semantic cancellation first, revoke permits, request adapter stop, kill the outer process namespace, and reject late output |
| `terminate` | Bounded cleanup after terminal adoption; destroy runtime-owned workspace and retention according to policy |

Provider-specific operations cannot expand this facade. A new provider
capability must map into these operations or require a versioned port change.

## Durable And Disposable Identity

The durable runtime identity is `(attempt IRI, fencing token, profile digest)`.
The graph also pins the source snapshot, context/delegated-input manifest,
adapter release, JidoHarness revision, CLI version, sandbox profile, credential
generation, budget, and candidate protocol.

The following are disposable observations only:

- PID and process-group identity;
- JidoHarness run and session references;
- provider session and event cursors;
- local workspace and journal paths;
- CLI caches and provider-internal conversation state; and
- streaming fragments before bounded adoption.

No disposable identifier is required to recover semantic authority after a
BEAM or worker restart.

## Attempt Lifecycle

The normalized lifecycle is:

```text
admitted -> preparing -> running -> awaiting_actor -> running
                         |              |
                         +-> candidate_ready
                         +-> cancelling -> cancelled
                         +-> failed
```

`timed_out` is a bounded runtime outcome classification that follows the
accepted failure transition; it does not add a second lifecycle state.
`ambiguous` classifies an external effect or result that cannot yet be proven;
it is not success or failure and does not create an invented attempt state.
Reconciliation uses invocation/effect identity before any retry. Terminal
states do not reopen. A new fence supersedes prior processes without rewriting
their history.

## Launch Envelope

The Factory resolves a closed launch envelope containing:

- attempt, task, actor, tenant, repository, lease, capability, and fence IRIs;
- exact source snapshot and base revision;
- delegated-input manifest IRI and digest;
- agent, harness, model-access, adapter, CLI, sandbox, network, workspace,
  candidate, verifier, policy, and tool-manifest revisions/digests;
- prompt or task instructions within accepted bounds;
- explicit omissions and provider-internal unavailable fields;
- disposable worktree mount identity;
- finite resource limits;
- credential release permit reference, never secret bytes;
- allowed provider endpoint/audience; and
- idempotent run/effect identity.

The prompt travels through stdin JSONL or an accepted broker-owned protected
file. It MUST NOT appear in argv, environment, process titles, diagnostics, or
retained launch metadata.

The runtime resolves the executable and fixed arguments from the accepted
application registry. Task or repository content cannot add arguments, tools,
skills, extensions, MCP servers, configuration directories, environment
variables, mounts, or endpoints.

## Workspace And Tool Boundary

The delegated process runs as an unprivileged identity in one disposable
copy-on-write worktree at the exact admitted base revision. It receives only
the mounts and limits in the signed sandbox profile.

For write-capable profiles:

- create, modify, and delete effects are limited to admitted repository paths;
- `.git` control data, external directories, sockets, devices, host mounts,
  publication credentials, and protected refs remain inaccessible;
- dependency/cache mounts are read-only or separately disposable and governed;
- registered checks are selected from the Factory catalog, even if invoked by
  a provider-specific harness bridge;
- arbitrary egress is denied; and
- the outer controller monitors byte, process, memory, disk, idle, wall, and
  output ceilings independently of CLI reporting.

Provider-internal tools remain untrusted opaque effects inside the sandbox.
Their events may improve diagnostics but do not prove complete mediation,
successful checks, or candidate validity.

## Credential Protocol

Before provider dispatch, the credential broker revalidates the exact profile,
adapter, actor, tenant, repository, attempt, lease, fence, audience, scope,
expiry, and revocation generation. It issues one bounded permit to the trusted
connector.

- `developer_local` attaches the narrowest proven reference to an existing
  user login after consent and billing acknowledgement.
- `managed_fleet` uses workload exchange or an attaching proxy; it never mounts
  a shared provider cache or exports reusable material to the CLI environment.

Repository-controlled descendants must be unable to read, copy, refresh, or
invoke the credential outside the accepted provider request path. A provider
that cannot meet this invariant cannot use a write-capable or managed profile.

## Observation And Accounting Protocol

Every adopted observation is bounded and correlated with attempt, fence,
profile, run, sequence, and time. Allowed observation classes include:

- process and provider lifecycle;
- bounded usage and cost when the provider reports them;
- clarification request and actor response;
- workspace changed/not-changed indication;
- normalized changed-path summary;
- check request and independently observed check receipt;
- terminal state;
- workspace, patch, tree, and artifact digests; and
- explicitly unavailable accounting dimensions.

Raw prompts, raw provider transcripts, hidden reasoning, provider-private
context, unbounded tool output, secret-bearing errors, and reusable credentials
are not adopted. Durable memory capture follows the existing total-accounting
and content-policy contracts; unavailable internal data remains unavailable.

Invocation-before-effect and terminal-or-ambiguous accounting applies to the
outer CLI launch, every JidoCode-controlled broker/check/candidate effect, and
publication. JidoCode must not fabricate complete internal tool accounting for
the delegated provider loop.

## Candidate Capture

Candidate capture is controller-owned and runs only after the delegated process
reaches a bounded completion or explicit handoff point. It compares the
workspace against the exact base revision and produces:

- normalized patch digest and bounded patch artifact reference;
- resulting tree digest;
- ordered changed-file identities and operations;
- generated artifact identities and digests;
- source snapshot, attempt, fence, profile, adapter, CLI, sandbox, policy,
  tool-manifest, and candidate-protocol identities;
- independently observed registered-check receipts, if any;
- secret-scan evidence;
- terminal summary digest; and
- complete/partial accounting statement with explicit omissions.

The delegated agent cannot supply authoritative values for these fields. The
controller recomputes them from the isolated workspace. Symlink escapes,
special files, out-of-scope paths, oversized diffs, forbidden generated files,
secret findings, dirty base state, or digest mismatch quarantine the candidate
and prevent handoff.

A candidate is only an immutable proposal. It does not imply verification,
acceptance, publication authorization, goal satisfaction, or knowledge
adoption.

## Verification And Publication Handoff

The verifier receives the immutable candidate and reconstructs a fresh checkout
from the exact source revision in a separate environment. It does not reuse the
delegated workspace, provider session, CLI process, or CLI-reported check
success.

Only verifier evidence enters the governed decision boundary. An accepted
candidate may proceed to a separately authorized draft-publication effect.
Neither the delegated runtime nor JidoHarness receives provider publication or
merge credentials. Human merge remains mandatory.

## Steering And Clarification

Steering and clarification responses are graph-scoped interaction messages.
Before delivery, the Factory checks actor, attempt, current state, audience,
lease, fence, profile, sequence, and size. Messages are untrusted input and
cannot alter the profile, adapter, sandbox, tools, credentials, policy,
verification requirements, or publication authority.

Provider-specific session continuation is allowed only when the accepted
profile declares a bounded session protocol. Otherwise a signal is rejected or
creates a new graph-authorized attempt; the runtime never silently invents a
session.

## Cancellation, Failure, And Recovery

Cancellation order is mandatory:

1. commit cancellation intent in the graph;
2. revoke outstanding credential and effect permits;
3. request native adapter cancellation;
4. terminate the outer process group or worker namespace within the bound;
5. destroy or quarantine the workspace and journal retention;
6. reject all late callbacks, streams, files, artifacts, and terminal results
   using the current fence; and
7. commit the attributable terminal or ambiguity observation.

After restart, the Factory re-queries graph state. It never reopens a provider
session from an ephemeral registry. Depending on committed facts and current
compatibility it may reconstruct a new runtime, supersede, propagate
cancellation, abandon, or retry later. Generic retry after a possibly completed
external effect is forbidden.

## Required Conformance Matrix

Every enabled adapter/profile pair MUST pass:

1. exact version, executable-registry, prompt-channel, fixed-argument, and
   disabled-extension conformance;
2. positive candidate generation within the declared language/task envelope;
3. malformed input, output, event, candidate, and artifact rejection;
4. unauthorized actor, repository, capability, profile, and credential denial;
5. stale fence, expired lease, revoked credential, superseded profile, and
   adapter-drift denial before process/effect creation;
6. cancellation of cooperative, stalled, and resistant descendant processes;
7. late stream, file, event, callback, candidate, and terminal-result rejection;
8. process crash, BEAM restart, worker loss, provider outage, partial output,
   and ambiguous-effect reconciliation;
9. prompt, credential, journal, cross-actor, cross-repository, and host-path
   canary non-disclosure;
10. sandbox escape, symlink, special-file, output-flood, fork, disk, memory,
    time, and egress containment;
11. independent fresh-checkout verification that distrusts CLI-reported checks;
    and
12. proof that no path can approve, publish, merge, adopt memory, or mutate
    policy from the delegated process.
