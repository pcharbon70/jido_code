# Execution Runtime Boundary

Phase 8 treats execution runtimes, agents, process registries, tools, and
sandboxes as disposable effect mechanisms. `TripleStore` remains the only
durable source of truth for execution identity, lifecycle, provenance, and
recovery.

## Dependency Decision

The accepted runtime set for the Phase 8 baseline is:

| Dependency | Pin | Role |
| --- | --- | --- |
| `jido` | `2.3.2` | supervised agent runtime behind the product port |
| `req` | `0.6.3` in `mix.lock` | HTTP adapter dependency compatible with Jido 2.3 |
| runtime contract | `1.0.0` | product-owned prepare/start/signal/cancel/status/terminate API |

Jido's agent registry, dynamic supervisor, runtime store, queues, and agent
state are not product persistence. The configured Jido storage adapter is ETS,
the application does not call hibernate or thaw, and loss of all Jido state is
a supported recovery condition. Jido modules are restricted to
`JidoCode.Runtime` by the architecture checker.

## Product Contracts

`JidoCode.Factory.ExecutionRuntime` is the only factory-facing runtime facade.
It accepts a bounded `Execution.Request` containing semantic attempt, task,
lease, actor, capability, snapshot, context digest, runtime version, and fence
identity. It contains no graph handles, process identifiers, provider session
objects, sandbox paths, or secret values.

Every facade operation invokes `ExecutionAuthority` immediately before the
adapter callback. The default authority fails closed unless a bounded fence
validator is supplied. Runtime events and outputs have sequence, time, outcome,
usage, digest/reference, and diagnostic bounds.

The related adapter boundaries are:

- execution runtime: prepare, start, signal, cancel, status, terminate;
- model providers: invoked only through runtime/tool capabilities;
- tools and sandboxes: receive attempt, lease, fence, constraints, and bounded
  inputs, never a graph handle;
- clocks: injected into runtime events and command construction;
- secrets: resolved by reference immediately before an authorized effect and
  never placed in context, events, diagnostics, or graph literals;
- cancellation: graph command first, adapter propagation second, attributable
  outcome transition last.

## Context And Supervision

Execution context is assembled from reviewed query version `1.6.0` with exact
graph revisions. It enforces item, byte, and token budgets; accepted/fresh and
non-contradictory knowledge; visibility; secret rejection; deterministic
truncation; explicit omissions; snapshot/lease/plan consistency; and effect
subset checks. Its normalized SHA-256 digest is durable only when an attempt
start change set commits.

`JidoCode.Runtime.Supervisor` owns a Jido instance, an attempt registry, and a
`DynamicSupervisor`. Local worker keys are SHA-256 mappings of attempt IRI plus
fence. Duplicate workers for one key are rejected. Workers and Jido agents can
be stopped and recreated from the same graph-derived request without a domain
change.

## Upgrade And Mixed Attempts

New attempts require the exact current runtime contract and Jido version.
Existing attempts retain their recorded version. Recovery resumes an attempt
only when that exact adapter version is still available; otherwise it records
an abandoned or superseded transition rather than interpreting state with a
new runtime. Runtime upgrades therefore do not mutate old run graphs or make
mixed-version behavior implicit.

## Interaction Boundary

Interaction sessions and sent messages are graph resources with scope,
participants, audience, authority, purpose, chronology, classification,
provenance, and lifecycle transitions. Messages can represent proposals,
clarifications, steering requests, or cancellation requests and may reference
a separately authorized semantic command. They cannot directly mutate goals,
tasks, leases, or attempts. UI drafts and transient prompt assembly remain
ephemeral.
