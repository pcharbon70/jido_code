# ADR 0003: First-Class Delegated Coding Agents

- Status: Accepted
- Date: 2026-08-26
- Owners: JidoCode runtime and product maintainers
- Decision scope: Coding-agent taxonomy, runtime selection, and product identity
- Depends on: [ADR 0001](./0001-graph-only-source-of-truth.md)
- Related evidence: [Harness Phase 5 receipt](../architecture/harness-phase-05-receipt.md)
- Specifications:
  [Delegated agent profile catalog](../architecture/delegated-agent-profile-catalog.md),
  [runtime protocol](../architecture/delegated-agent-runtime-protocol.md), and
  [product and qualification](../architecture/delegated-agent-product-and-qualification.md)

## Context

JidoCode has two materially different ways to perform coding work:

1. a host-controlled `Jido.Agent` strategy that owns the context-model-tool
   loop and uses ReqLLM for bounded model interactions; and
2. a delegated coding CLI, such as Codex, Claude Code, Gemini CLI, OpenCode,
   or Pi, whose internal model loop and provider-dependent tools execute
   through JidoHarness.

The first path is represented by the accepted managed-coding profile. The
second has a strong process adapter, lifecycle normalization, cancellation,
privacy, and recovery boundary, but it is not a usable product agent class.
The only admitted JidoHarness profiles are developer-local Pi deny-all and
read-only profiles, both marked `managed_eligible: false`. All upstream
finite-run adapters and all write-capable delegated profiles remain blocked.

Treating only modules that `use Jido.Agent` as agents obscures the product
boundary developers care about. Conversely, wrapping a delegated coding CLI
inside a second model-driven `Jido.Agent` would create overlapping planners,
tool loops, retry behavior, and state. The Factory needs one semantic agent
identity while permitting different disposable execution mechanisms.

## Decision

JidoCode will recognize two first-class coding runtime classes:

- `host_controlled` — JidoCode owns the coding loop through a disposable
  `Jido.Agent`; individual model interactions use an accepted
  `ModelAccessProfile` and the ReqLLM gateway.
- `delegated_cli` — an accepted external coding agent owns its internal loop
  inside an isolated worker; JidoCode controls its outer admission, context
  envelope, workspace, credentials, budgets, process lifecycle, cancellation,
  candidate capture, verification, decision, and publication boundaries.

Both classes are selected by an immutable graph-owned profile. A task, model,
repository file, environment variable, provider response, CLI configuration,
or runtime process cannot select or change the class. Profile resolution
happens before execution and is bound to the task, repository, actor, tenant,
capability, lease, fencing token, source snapshot, and signed profile digest.

A delegated CLI is a first-class product agent without becoming a
`Jido.Agent` module. The JidoHarness adapter implements the existing
Factory-owned execution-runtime port. Provider-specific CLIs are admitted as
versioned delegated-agent profiles, not as arbitrary executable names or
runtime-selected modules.

### Shared Authority Boundary

The two runtime classes share these non-negotiable boundaries:

1. `TripleStore` remains the sole durable application authority.
2. The Factory admits work and resolves the exact profile, lease, fence,
   capabilities, budgets, and source snapshot.
3. Runtime state, provider sessions, CLI journals, worktrees, sandboxes, and
   process identifiers are disposable.
4. The runtime may propose and materialize candidate changes only inside the
   admitted workspace.
5. Independent fresh-checkout verification evaluates the captured candidate.
6. A policy-authorized decision accepts or rejects evidence.
7. Publication is a separate human-authorized effect, and human merge remains
   mandatory.
8. Memory promotion remains a separately governed semantic command.

### Product Identity And Catalog

The product will expose one scope-filtered agent catalog. Each offering is a
bounded projection of an immutable profile and reports, at minimum, display
identity, runtime class, provider, access and billing modes, deployment class,
capability summary, supported task classes, readiness, rollout stage, profile
digest, and material limitations.

The catalog never exposes credential references, executable paths, adapter
modules, sandbox paths, provider sessions, raw graph handles, or profiles that
the current actor cannot select. A display name such as “Codex” is not an
authority token; admission always uses the exact profile IRI and digest.

### Non-Nesting Rule

A `host_controlled` attempt MUST NOT invoke a `delegated_cli` runtime as an
internal tool by default, and a delegated CLI MUST NOT invoke the native
managed-coding agent. Any future composition is a multi-agent topology and
requires the existing multi-agent evaluation and acceptance gates.

### Incremental Admission

Agent providers graduate independently. Enabling one exact Codex profile does
not enable Claude, Pi, Gemini, another model, another authentication mode, a
different CLI version, or a broader tool profile. There is no generic
“JidoHarness enabled” switch and no fallback between providers or runtime
classes.

The existing Pi deny-all and read-only profiles retain their developer-local,
non-managed status until superseded by separately qualified profiles. This ADR
does not itself enable any currently blocked adapter.

## Consequences

### Positive

- developer-facing coding CLIs become explicit product agents rather than an
  invisible adapter option;
- native and delegated execution share one governed task-to-candidate flow;
- each provider, credential mode, capability set, and deployment class can be
  qualified and disabled independently;
- the implementation avoids nested planning loops and duplicate authority;
  and
- future agent catalog and task-submission surfaces can describe capabilities
  honestly.

### Costs And Constraints

- the managed-coding profile, ontology, shapes, reviewed queries, release
  contract, and product projections need compatible new revisions;
- delegated providers reveal less internal context, turn, token, and tool
  detail than the host-controlled path, and those fields must remain marked
  unavailable rather than inferred;
- every enabled CLI/version/tool profile needs provider-specific cancellation,
  candidate-capture, privacy, and qualification evidence; and
- profile proliferation requires strict lifecycle, supersession, and rollout
  governance.

## Alternatives Rejected

- **Treat JidoHarness as an implementation detail only:** developers cannot
  discover, select, reason about, or govern actual coding-agent offerings.
- **Wrap every CLI in a `Jido.Agent`:** this creates nested loops and ambiguous
  retry, cancellation, tool, and state ownership.
- **Use one generic delegated profile for all CLIs:** provider capabilities,
  authentication, cancellation, journals, and candidate formats are not
  interchangeable.
- **Let repository configuration select the CLI:** repository content is
  untrusted and cannot choose an effect mechanism or credential surface.
- **Replace the native ReqLLM agent:** the host-controlled loop offers stronger
  mediation and remains valuable for supported tasks.

## Implementation Acceptance And Reopening Conditions

The architectural decision is accepted, but delegated-write selection remains
disabled until one exact profile proves:

1. versioned ontology and shape changes for the delegated profile and catalog;
2. semantic commands and reviewed queries with scope, revision, and authority
   tests;
3. a runtime resolver proving exact, no-fallback dispatch for both classes;
4. at least one write-capable developer-local delegated profile completing an
   isolated task-to-candidate-to-verification flow;
5. product/API conformance for discovery, readiness, selection, submission,
   control, evidence inspection, and publication handoff;
6. negative tests for stale fences, revoked profiles, adapter drift, runtime
   class substitution, prompt injection, late results, and cross-actor access;
   and
7. a new release contract that explicitly names enabled profiles and preserves
   human publication authorization and merge.

Until these conditions pass and the implementation pull request merges, the
current managed-coding release contract and its disabled delegated-write
posture remain authoritative. The decision reopens if either runtime class can
be selected outside an exact graph-owned profile, if fallback crosses runtime
or provider boundaries, if disposable runtime state becomes durable authority,
or if a delegated process gains verification, publication, or merge authority.
