# ADR 0011: Attention-Oriented Control Plane And Knowledge Lenses

- Status: Accepted for architecture authority; projection, interaction, and release gated
- Date: 2026-08-31
- Accepted: 2026-09-03 through HUI-A3 merged-candidate governance
- Owners: JidoCode product, Factory, Knowledge, security, and accessibility
  maintainers
- Decision scope: Product mental model, navigation, attempt workspaces,
  attention, graph-family representation, visualization, and control posture
- Depends on:
  [ADR 0001](./0001-graph-only-source-of-truth.md),
  [ADR 0003](./0003-first-class-delegated-coding-agents.md),
  [ADR 0005](./0005-repository-wikis-as-compiled-knowledge-projections.md),
  [ADR 0008](./0008-server-rendered-heex-and-datastar-product-runtime.md),
  and [ADR 0009](./0009-human-identity-scoped-authorization-and-separation-of-duty.md)
- Research:
  [Secure hypermedia control plane](../research/12-secure-hypermedia-coding-factory-ui.md)
- Specifications:
  [Product shell and information architecture](../architecture/secure-product-shell-and-information-architecture.md),
  [Attempt workspace and commands](../architecture/agent-attempt-workspace-and-command-contract.md), and
  [Graph lenses and visualization](../architecture/graph-lens-and-visualization-contract.md)

## Context

A parallel coding factory cannot be supervised effectively as a collection of
chat windows or raw process heartbeats. Operators and developers need to find
exceptions, understand meaningful progress, move between many project/attempt
contexts, correlate effects and evidence, and intervene through exact governed
controls.

JidoCode also has seventeen named-graph families spanning factory catalog and
policy, source, repository control, execution, evidence, memory, experience,
wiki, datasets, security audit, and derived diagnostics. A raw graph browser or
single node-link hairball would expose implementation identities, weaken query
authorization, overload users, and obscure provenance.

## Decision

This decision is binding product vocabulary and information architecture. It
does not claim that attention queries, attempt workspaces, conversation
adapters, lens projections, visualizations, acknowledgements, or operational
controls are implemented. Those capabilities remain unavailable until their
Milestones C through G gates close.

JidoCode will implement an **attention-oriented factory control plane** with
progressive disclosure from factory to repository-backed project, task,
attempt workspace, interaction session, evidence, and provenance.

### Product Identity And Routes

- `Project` initially means a presentation alias for one conceptual repository
  scope. A separate multi-repository Project resource requires a later ADR.
- An `Attempt workspace` is the durable human-facing route that correlates one
  execution attempt's plan, interactions, effects, candidate, verification,
  costs, authority, and receipts.
- Existing graph-native `InteractionSession` remains distinct. Its exact
  attempt cardinality and authorized audience are queried rather than inferred.
- Factory, project, attempt, review, wiki, graph lens, operations, and
  governance destinations use ordinary durable URLs and opaque bounded refs.

### Attention And Oversight

The default factory view leads with a reviewed **Needs attention** projection,
then factory health/capacity and a stable filterable attempt fleet. Attention
is derived from durable facts such as approvals, questions, failed checks,
stalled leases, recovery conflicts, budgets, stale critical projections, and
security incidents. Browser-local dismissal is not durable acknowledgement.

The attempt workspace supports before-run control, co-planning, real-time
supervision, and post-run review. Its canonical header and timeline distinguish
attempt lifecycle, last meaningful effect, wait reason, lease/fence, budget,
candidate, verification, decision, draft publication, external application,
re-observation, post-change verification, follow-up, and satisfaction.

Chat is a bounded interaction panel, not authority or the only evidence record.
It renders authorized durable `InteractionSession` messages and may submit only
the currently admitted `answer` or `steer` intent. It does not expose raw
provider transcripts, private reasoning, a caller-selected audience, or an
unrestricted multi-turn provider channel. Message recording, command admission,
runtime continuation, and observed agent output remain distinct receipt-backed
states.

### Knowledge Lenses

Graph families appear only through closed task-oriented lenses:

1. factory and capacity;
2. source;
3. project domain;
4. work and execution;
5. evidence and decision;
6. memory and experience;
7. wiki, guides, and dependencies;
8. cross-project datasets;
9. security and audit; and
10. derived diagnostics.

Each lens uses reviewed bounded queries and exposes safe scope, revision,
freshness, completeness, contradiction, truncation, and provenance. The
product does not offer unrestricted SPARQL, graph-IRI selection, generic RDF
editing, or hidden cross-family joins.

Visualization follows the task: tables for inventory/comparison, trees for
containment, timelines for causality, matrices for dependencies/coverage,
small multiples for change, and bounded node-link diagrams for paths or small
neighborhoods. Every complex visualization has a synchronized accessible
table or outline.

### Controls

The UI renders only semantic controls admitted by current contracts. Friendly
labels map explicitly to gateway/runtime operations and receipts. The product
does not invent pause, emergency-stop, freeze, quarantine, bulk mutation, or
acknowledgement state before their semantic resources and commands exist.

## Consequences

### Positive

- developers can supervise parallel work by exception instead of reading every
  transcript;
- developers can answer or steer the correct bounded agent interaction without
  confusing a browser conversation with an attempt, provider session, or
  authority boundary;
- durable attempt routes support multiple browser tabs and interruption/
  resumption;
- execution, verification, decision, source application, and wiki activation
  remain visibly distinct;
- graph-backed knowledge becomes understandable without exposing arbitrary
  graph access; and
- safe provenance and projection state become consistent product vocabulary.

### Costs And Constraints

- attention, fleet, attempt timeline, review, cost, and graph-lens projections
  need new reviewed queries and components;
- conversation projections, session routing, composer admission, delivery
  reconciliation, and accessible transcript behavior require dedicated product
  work even though their semantic message and control primitives already exist;
- saved views, acknowledgement, assignment, incident, and bulk actions require
  semantic contracts before becoming durable;
- large collections need server pagination and bounded visualization; and
- usability, accessibility, role comprehension, and parallel-resumption tasks
  require human qualification.

## Alternatives Rejected

- **Chat-first navigation:** it hides effects, evidence, authority, cost, and
  cross-attempt state.
- **Process/PID dashboard:** liveness is not meaningful progress or durable
  attempt state.
- **Raw graph browser:** it bypasses the reviewed product query vocabulary and
  creates disclosure and cognitive-load risks.
- **One visualization for all graphs:** graph tasks require different
  representations and bounds.
- **Browser-local attention acknowledgement:** hidden cards do not create a
  durable, attributable workflow fact.
- **Call every attempt a session:** JidoCode already has a distinct
  `InteractionSession` identity.

## Compatibility And Rollback

Existing Factory, Repositories, Work, Execution, Outcomes, Knowledge, and Wiki
surface IDs remain usable as migration aliases where their authority contracts
stay intact. New routes can coexist as read-only projections before commands
move. Rollback restores the prior route presentation without changing graph
facts or accepting browser-local state.

## Decision Acceptance And Implementation Gates

HUI-A3 accepts the product vocabulary and mental model only after the route,
projection, interface, evidence, and supersession contracts pass architecture
validation and clean-checkout CI at its merged candidate. Product capability
remains gated. Milestones C through G must prove that:

1. project/repository, task, attempt, interaction-session, candidate, and
   receipt vocabulary and containment are explicit;
2. the attention projection has a closed durable source and does not invent
   acknowledgement state;
3. every route, lens, field, timeline event, visualization expansion, and
   control maps to exact reviewed-query and authorization contracts;
4. all ten projection states retain their accepted semantics, including
   clearing unavailable rows and concealing unknown/unauthorized resources;
5. all collections and graphs have count/byte/time/depth/pagination limits and
   accessible alternatives;
6. parallel tabs, scope switching, interruption/resumption, and concurrent
   human controls preserve isolation and compare-and-set outcomes;
7. the conversation panel binds every message and composer action to the exact
   authorized attempt, `InteractionSession`, audience, sequence, and admitted
   `answer` or `steer` operation without exposing raw provider transcripts or
   inventing delivery/read state;
8. controls do not overclaim currently unconfigured scheduler, loader,
   publication, wiki, provider, or runtime posture; and
9. usability, accessibility, security, clean-checkout, and merged-candidate
   evidence passes the signed qualification profile.
