# ADR 0001: Graph-Only Source Of Truth

- Status: Accepted
- Date: 2026-07-31
- Owners: JidoCode maintainers
- Decision scope: Application architecture and persistence
- Research: [Graph-Native Managed Repository Factory](../research/01-graph-native-managed-repository-factory.md)
- Baseline: [Current-State Inventory](../architecture/current-state-inventory.md)

## Context

JidoCode is intended to operate a managed repository factory. Repository facts,
intent, policies, goals, work dependencies, execution provenance, evidence,
decisions, and learned knowledge form a connected and evolving knowledge model.
A record-oriented application database would make those relationships and
their epistemic/provenance context secondary, while a separate graph would
become a derived copy rather than the authority.

The starting repository has no application database or durable product model.
This permits the knowledge graph boundary to be established before product
state exists.

## Decision

All durable application-owned knowledge, control state, workflow state,
user-authored state, and factory history MUST be represented in one embedded
`TripleStore` dataset opened with `schema: :quad`.

The dataset is the only application-owned source of truth. JidoCode MUST NOT
add Ecto tables, Ash resources, DETS, Mnesia, JSON or RDF snapshot files,
durable queues, prompt-memory databases, per-entity stores, or any other
parallel persistence path for product state.

### Graph Semantics

- RDF resources and predicates are the durable domain model.
- Named graphs are authority, provenance, lifecycle, and retention boundaries;
  they are not table names.
- Durable relationships are RDF edges, not foreign-key-shaped literals.
- Change is append-first. Corrections, transitions, invalidations,
  supersessions, and decisions retain provenance and transaction time.
- Assertions carry explicit epistemic state when truth, confidence,
  contradiction, or acceptance matters.
- Derived or inferred graphs are rebuildable and never silently become
  asserted truth or execution authority.
- Runtime success cannot satisfy a goal. A policy-authorized decision evaluates
  evidence and records acceptance, rejection, waiver, or follow-up.

### Boundary Qualifications

The following state is outside the application-owned graph without weakening
the source-of-truth rule:

1. Git repositories, Git providers, CI systems, issue trackers, and artifact
   providers are external authorities. JidoCode records their identity,
   revisions, observations, provenance, and decisions in the graph.
2. Local clones, build directories, and sandboxes are disposable working
   material. They are reconstructable from graph identity plus external source
   revisions and MUST NOT contain the only copy of product knowledge.
3. Credential bytes remain in environment variables, operating-system
   keychains, or dedicated secret providers. The graph stores only opaque
   references, scope, policy, fingerprints, and lifecycle audit.
4. Operational logs, metrics, traces, PubSub events, and process state are
   diagnostics or delivery mechanisms. A bounded result that affects a future
   decision must be adopted into the graph as evidence or knowledge.
5. The browser theme value `phx:theme` is an allowed device-local presentation
   preference. It cannot influence authorization, work, evidence, or decisions.
6. Large or binary artifacts remain provider-owned initially. The graph records
   an immutable URI, digest, media type, size, provenance, and verification
   result. An application-owned blob store requires a superseding ADR.

There are no other persistence exceptions at acceptance time.

### Plane Authority

The planes are logical authority boundaries over the same quad dataset, not
separate databases:

- The **knowledge substrate** owns store lifecycle, graph topology,
  transactions, semantic writes, validation, queries, reasoning, backup,
  restore, export, and committed-change delivery.
- The **data plane** reports observations, source semantics, execution
  provenance, artifacts, claims, and evidence. It cannot authorize or accept.
- The **control plane** owns enrollments, desired outcomes, policies, goals,
  plans, approvals, leases, cancellations, retries, and decisions through
  authorized semantic commands.
- The **reconciliation plane** compares desired and observed state and emits
  explainable proposals or derived assertions. It does not self-authorize.
- The **execution plane** contains ephemeral Jido/OTP workers, tools, and
  sandboxes operating under graph-visible leases and bounded context.
- The **projection plane** exposes reviewed, parameterized, bounded reads.
  Projections and caches are disposable.
- The **presentation plane** uses the repository-owned LiveView shell, SaladUI
  components, and bounded LiveVue islands. It has no raw store access.

### Route And Model Ownership

This repository owns its route and workbench contract. The current `/`
LiveView route is the baseline. The route surface and object-shaped record model
from `mikehostetler/jido_code` are compatibility references only and MUST NOT be
copied as architectural authority.

Small structs are allowed for validated command envelopes, query/projection
results, typed errors, and adapter payloads. They must be reconstructable and
must not be serialized or treated as aggregate roots. Generic CRUD stores and
record codecs are prohibited.

## Consequences

### Positive

- provenance, time, authority, contradiction, and cross-repository
  relationships remain first-class;
- restart and recovery have one durable boundary;
- product, agent, and operator surfaces can share reviewed graph projections;
  and
- architecture tests can detect a second persistence model early.

### Costs And Constraints

- semantic command and query design must precede convenience CRUD APIs;
- operational closed-world queries must declare complete graph/revision
  boundaries explicitly;
- graph evolution requires ontology, shape, query, and migration governance;
- large binary ownership remains external unless this ADR is superseded; and
- loss or incompatibility of the store causes durable operations to fail
  closed rather than falling back to another database.

## Alternatives Rejected

- **Relational/Ash source of truth with a derived graph:** provenance and graph
  semantics would not be authoritative.
- **Graph for knowledge plus a workflow database:** goal, lease, attempt, and
  decision history could diverge across stores.
- **Per-repository databases:** cross-repository reasoning and global policy
  would require reconciliation across authorities.
- **Filesystem or prompt memory as product state:** replay, authorization,
  provenance, and recovery would be ambiguous.

## Enforcement

Implementation must enforce this decision through module dependency rules,
source scans for prohibited persistence, a single supervised store owner,
semantic command APIs, bounded query APIs, and integration tests that inject
forbidden examples. Any exception requires a new ADR before code is merged.
