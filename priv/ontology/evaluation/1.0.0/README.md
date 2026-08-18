# Jido Evaluation Graph Ontology 1.0.0

## Status

This directory is a versioned **candidate ontology module**. It models the
evaluation graph topology proposed in
[`docs/research/08-coding-agent-evaluations-for-development.md`](../../../../docs/research/08-coding-agent-evaluations-for-development.md).

It imports the immutable Jido Factory ontology `1.0.0`; it does not alter that
release. The current application ontology loader and closed `GraphRegistry` do
not yet admit the proposed graph families. Importing or parsing these files
therefore grants no write capability and creates no operational graph.

## Files and namespaces

| File | Purpose |
| --- | --- |
| `evaluation.ttl` | OWL/RDFS classes, properties, graph-family contracts, and SKOS concepts |
| `shapes.ttl` | SHACL constraints for graph metadata, definitions, trials, evidence, aggregates, decisions, and protected references |

| Kind | Namespace |
| --- | --- |
| Ontology | `https://jido.run/ontology/evaluation/1.0.0` |
| Terms | `https://jido.run/ontology/evaluation#` |
| Concepts | `https://jido.run/ontology/evaluation/concept/` |
| Shapes | `https://jido.run/ontology/evaluation/shapes#` |
| Shapes graph | `https://jido.run/ontology/evaluation/shapes/1.0.0` |

## Proposed graph families

The ontology represents two new lifecycle boundaries:

| Family | Scope | Lifecycle | Writer | Contents |
| --- | --- | --- | --- | --- |
| `evaluation_catalog` | catalog identity and revision | immutable and complete | `evaluation_catalog_writer` | many profiles, targets, corpora, tasks, rubrics, oracle references, slices, and statistical plans |
| `evaluation_run` | evaluation-run identity | building, then permanently closed complete or incomplete | `evaluation_run_writer` | one frozen run and all of its trial assignments and observations |

There is deliberately no graph family per task, trial, grade, aggregate, or
decision. Those resources are placed according to authority and lifecycle:

- definitions belong to an evaluation catalog graph;
- raw run/trial observations belong to the corresponding evaluation-run
  graph;
- admitted grades, adjudications, aggregates, and proposed claims belong to
  the existing repository evidence graph;
- rollout policy and accepted transitions remain in existing policy/control
  graphs;
- rebuildable metrics and dashboards belong to derived graphs; and
- protected-data access, invalidation, and override events belong to the
  security-audit graph.

## Authority and security invariants

- `GraderResult`, `HumanGrade`, `Adjudication`, `MetricObservation`, and
  `AggregateResult` are measurement resources, not decisions. Their shapes
  reject decision or transition predicates.
- `RolloutDecision` specializes the existing governed `jf:Decision` and must
  identify its authority and admitted evidence.
- `AggregateResult` must identify the exact contributing trials, analysis
  revision, frozen inclusion digest, and metric observations.
- `ReviewFinding` is a structured claim with pinned trial/source revision,
  category, severity, optional file/range, impact, evidence, confidence, match
  state, and an executable reproduction for critical findings.
- `AnalysisClaim` specializes the accepted claim model with a pinned
  trial/source revision, claim type, positive/negative/unknown polarity,
  direct/derived/hypothesis/recommendation kind, evidence, and confidence.
- `ProtectedArtifactReference` is a closed shape containing only its RDF type,
  digest, artifact role, and access-policy revision. Raw hidden tests, expected
  patches, secret values, and oracle bytes stay in a capability-gated artifact
  store.
- An evaluation graph never links directly to memory and never causes a
  control transition. Curated regression tasks and lessons require separate
  reviewed commands.
- Large transcripts, patches, traces, and test output remain content-addressed
  artifacts. Graph resources store their digests and controlled references.

## Operational admission checklist

Before these terms can become authoritative application data, a reviewed
implementation must:

1. publish a new immutable factory ontology and shape release that imports or
   incorporates this module without rewriting `1.0.0`;
2. add `evaluation_catalog` and `evaluation_run` to a new closed
   `GraphRegistry` revision, including scope constructors, allowed links,
   writer capabilities, completeness, closure, and retention rules;
3. extend the executable shape catalog and validator with graph-family class
   placement and the critical SHACL invariants represented here;
4. add semantic commands for catalog publication, run creation, trial append,
   run closure, and evidence admission with exact graph-revision preconditions;
5. add protected query projections that cannot reveal sealed oracle material;
6. add migration/evolution classification and startup compatibility behavior;
   and
7. pass ontology parsing, semantic falsification, clean-checkout integration,
   authorization, leakage, stale-revision, and recovery tests.

Until that checklist is complete, these files are a concrete interoperable
schema and review target, not an alternate source of application authority.
