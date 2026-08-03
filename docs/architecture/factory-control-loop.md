# Factory Control Loop

## Authority Boundary

The factory control loop persists only RDF in registered TripleStore named
graphs. Desired propositions and reusable constraints live in the factory
policy graph. Goals, plans, tasks, dependencies, accepted transitions, and
decisions live in the repository control graph. Elixir structs and maps in the
control modules are bounded command or projection values and are disposable.

Observed claims remain in immutable observation graphs and inferred facts
remain in replaceable derived graphs. Reusing the same RDF proposition does
not merge those epistemic categories: graph family, resource type,
provenance, and command authority preserve the distinction.

## Desired And Work Graphs

`AssertDesiredOutcome` records a reified proposition or capability target,
scope, priority concept, validity interval, governing policies, expected
evidence, and typed constraints. Conflicting authored outcomes are retained.
A caller must cite a decision already in the policy graph or explicitly
supersede every cited conflict.

`ProposeGoal` derives a stable goal identity from repository scope, addressed
resources, and a semantic key. One goal can address many findings or outcomes,
and one evidence resource can be referenced by many goals.

`ProposePlan` records a bounded task graph, exact source/policy/observation
graph revision references, source snapshot, planner identity/version,
assumptions, expected effects, and verification strategy. Dependency cycles
are rejected unless every participating task explicitly permits iteration.
Required verification and approval nodes and capability coverage are checked
before proposal.

`AdoptPlan` is a separate control decision. It advances the plan and all tasks
from proposed to approved only when the goal endpoint and every exact input
graph revision still match. Invalid assumptions require a new plan instead of
silently mutating the proposal.

Lifecycle state is resolved from accepted `StateTransition` chains. There is
no mutable status literal. `WorkItem` is reserved for a bounded projection of
a goal/task neighborhood and is not a persisted RDF class.

## Vocabulary Contract

The Phase 7 work slice uses these bounded operational predicates in addition
to the ontology 1.0 baseline:

| Predicate | Meaning | Cardinality guidance |
| --- | --- | --- |
| `priority` | Controlled desired-outcome priority concept | exactly one |
| `expectedEvidence` | Evidence type or resource required for acceptance | one or more |
| `constrainedBy` | Constraint governing an outcome, goal, or task | zero or more |
| `targetCapability` | Capability that should become available | zero or one |
| `includesTask` | Task included by an immutable plan proposal | one or more |
| `alternativeTo` | Explicit alternative task path | zero or more |
| `requiresArtifact` | Input artifact required by a task | zero or more |
| `sourceSnapshot` | Exact repository snapshot used for planning | exactly one |
| `sourceGraphRevision` | Graph revision reference used as plan input | two to ten |
| `planner` | Planner actor or agent | exactly one |
| `originActivity` | Activity that proposed a goal | exactly one |
| `expectedEffect` | Expected plan effect | one or more |
| `verificationStrategy` | Bounded strategy identifier | exactly one |
| `transitionDomain` | Controlled lifecycle domain for a transition | exactly one |
| `conflictsWith` | Explicitly retained conflicting intent | zero or more |
| `iterationAllowed` | Declares that iterative dependency structure is intentional | zero or one |
| `taskKind` | Controlled constraint or task kind | exactly one |

## Read Boundary

Query catalog version 1.2 adds desired-outcome, goal-neighborhood, task-DAG,
blocker, transition-history, work-lens, and plan-context queries. Every query
uses one caller-authorized named graph and fixed limits. Work projections carry
the exact dataset and graph revisions, completeness, freshness, truncation,
warnings, and applied bounds.
