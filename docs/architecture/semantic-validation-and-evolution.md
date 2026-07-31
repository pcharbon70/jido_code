# Semantic Validation And Evolution

## Operational Shapes

The `1.0.0` ontology package contains SHACL-compatible node and property shapes
for named graph metadata, locators, claims, transitions, leases, evidence,
decisions, credential references, validation results, and migration activity.
The shapes IRI and shape version are independent from the ontology term
namespace even though both initial versions are `1.0.0`.

RDFS and OWL declarations remain open-world semantic guidance. The shape
catalog and `JidoCode.Knowledge.Validation.Validator` define the closed-world
subset required for write admission: graph placement, allowed classes,
required predicates, cardinality, datatype, controlled concept, node-kind,
provenance, and protected literal rules.

## Pre-Commit Validation

`JidoCode.Knowledge.Commands.Graphs` validates metadata and payload before it
constructs a `WriteBatch`. Validation runs over existing committed statements
supplied by the internal command adapter plus proposed additions, so a shape
can be satisfied across the effective transaction snapshot. A batch is never
submitted when the report does not conform.

The validator fails closed for:

- malformed RDF terms, blank nodes, wrong graph placement, and unregistered
  graph families;
- classes not admitted by the target graph family;
- missing or duplicate required predicates and wrong datatypes;
- literal object-property joins and unknown controlled epistemic concepts;
- unknown ontology or shape versions and ambiguous graph completeness;
- credential-value predicates, private-key material, and common token/password
  literal forms; and
- an expired monotonic validation deadline.

Each issue contains only a deterministic result IRI, focus IRI, shape IRI,
predicate path, stable code, severity, and a bounded constant message. Reports
never echo source literals or triples. Results are capped at 100 and proposed
datasets at 10,000 quads.

## Quarantine

Failed imports remain invisible. `Validation.Quarantine` accepts only a
nonconforming bounded report and creates a registered monthly security audit
graph containing the report projection. It never accepts or copies rejected
source statements. The same graph command and validator apply to the audit
write, and its capability is fixed to `security_auditor`.

## Evolution And Migration

Ontology changes are classified as `additive_compatible`, `validation_only`,
`behaviorally_stricter`, `transform_required`, or `breaking`. Changed term
meaning cannot reuse an ontology version. Transform-required plans must name a
semantic transformer version and rollback posture.

`JidoCode.Knowledge.Commands.Migrations` creates a new target graph and records
the migration activity in the same atomic batch. It records source and target
graphs, source and target ontology releases, transformer version, actor,
start/end time, source/target counts, validation report, and rollback posture.
The source graph is only referenced and is never removed or rewritten.

The semantic startup gate activates after the current ontology graph exists.
It rejects unregistered graphs, missing graph metadata, unknown ontology
versions, and incomplete graph state before readiness. Substrate-only datasets
remain supported for recovery and compatibility tests until an ontology
release is admitted.
