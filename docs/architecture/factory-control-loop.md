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

## Policy And Applicability

Policies are immutable versioned resources in the factory policy graph. Each
policy has one owner, scope, policy kind, effective interval, controlled
priority and conflict posture, reviewed evaluator identity/version, and a
closed list of graph inputs. RDF contains evaluator references, never
executable policy code. Desired-posture, authorization, and acceptance
policies remain separate kinds and cannot be resolved as one conflict set.

Repository cohorts are policy resources with either explicit static members
or an allowlisted query evaluator. Query-derived `CohortMembership` resources
exist only in a replaceable derived graph. Its metadata binds the membership
to the evaluator, rule revision, and exact catalog, source, observation, and
policy graph revisions. A source revision change makes the derived view stale;
it does not silently reinterpret the old membership.

Applicability explanations cite the cohort, repository, bounded membership
path, evaluator version, declared source revisions, completeness, and any
incomplete reasons. Query authorization checks the cohort graph's owner scope,
so a repository-scoped caller cannot enumerate a factory-scoped cohort.

## Obligations

A policy obligation is an append-only repository-control resource derived from
the policy version, applicable scope, desired outcome/dimension, and exact
source revision set. It cites the triggering gap, applicability evidence,
constraints, acceptance requirements, and validity. Reconciliation reuses the
same identity for the same semantic input and produces a different identity
when the relevant context changes.

Obligation lifecycle is an accepted transition chain: proposed, active,
satisfied, waived, superseded, or retired. An obligation is neither an
approved goal nor an executable task; later reconciliation and decision paths
connect those resources explicitly.

## Capability Boundary

Capability declarations record a holder, actor/agent/tool/sandbox kind,
provider and version, declared or observed mode, supported scopes and effects,
limits, evidence, completeness, validity, and lifecycle. Possession and
availability do not grant authority. Scheduling additionally requires an
explicit complete authorization view for the task scope.

Capability hierarchy is rebuildable classification in a derived graph. Every
classification carries source and evaluator revisions and is projected with
`authority?: false`. An inferred broader capability can aid matching but
cannot supply an authorization grant or make an incomplete capability view
schedulable.

Query catalog version 1.3 adds policy/cohort/obligation/capability descriptions,
governance transition history, applicability, strict capability, and derived
hierarchy reads. Governance projections preserve the evaluated graph revision,
derived source revisions, declared derivation source references, completeness,
freshness, bounds, and query version.
