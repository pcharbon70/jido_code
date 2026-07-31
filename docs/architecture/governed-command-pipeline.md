# Governed Command Pipeline

`JidoCode.Knowledge.Writer` remains the sole serialized product-mutation
boundary. It executes the following fixed sequence for a validated command
envelope:

1. resolve the exact command registry entry;
2. normalize RDF terms and fingerprint the logical change set without reading
   mutable state;
3. derive a stable actor/scope/command idempotency request and substrate commit
   identity;
4. recover an existing receipt or read one bounded consistent graph snapshot;
5. authorize the accountable actor and semantic capability;
6. evaluate expected revisions, lifecycle, topology, bounded guards, and the
   effective post-change shape contract;
7. assemble command, change-set, idempotency, provenance, audit, and semantic
   receipt resources; and
8. submit all domain and audit additions through one Phase 2 atomic batch.

No pre-commit stage writes RDF. Timeouts and unavailable dependencies fail
closed. A timeout that can leave response-loss ambiguity returns
`unknown_after_timeout`, which directs the caller to receipt recovery.

## Snapshot Bounds

The writer can request at most 20 registered named graphs and 10,000 effective
quads from `StoreServer`. The snapshot contains RDF data, graph-local metadata,
and dataset/graph revisions but no raw store handle. Authorization and
validation consume that same snapshot.

## Idempotency

The stable request identity is derived from actor, scope, command name/version,
and the bounded idempotency key. The substrate receipt stores the command IRI
and logical request fingerprint. Equivalent replay returns the original
revision receipt without another write. Divergent reuse returns a concealed
conflict before evaluating mutable preconditions.

## Audit Atomicity

Successful command activity, actor association, causation, validation versions,
request fingerprint, affected graph families, and outcome are RDF in the
period audit graph. These statements are additions in the same batch as the
domain effect. Rejected commands never receive a success audit. The pipeline
requires an initialized audit graph; secure creation is owned by Section 4.3.
