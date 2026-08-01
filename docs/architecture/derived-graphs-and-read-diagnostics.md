# Derived Graphs And Read Diagnostics

Derived graphs are disposable semantic products over exact asserted graph
revisions. They may accelerate inference and projection, but their metadata,
staleness, and replacement history remain explicit in the authoritative store.

## Governed Lifecycle

`DerivationRequest` binds operation, actor authority, target graph, rule-set IRI
and revision, query version, ontology/shape versions, exact source graph
revisions, optional prior derivation, reason, and bounded RDF statements.

`PublishDerivedGraph` is an additive command protocol at version `1.1.0`. The
Phase 4 twelve-command `1.0.0` registry remains unchanged. Bootstrap grants now
include the existing graph registry's `reasoner` capability.

Within the serialized `Writer`, `DerivedGraphManager`:

1. reads target, source, prior, policy, and audit state under the store owner;
2. verifies exact source and prior derivation revisions;
3. builds complete graph metadata and content in isolation;
4. runs semantic validation against the isolated replacement;
5. submits replacement, provenance, audit, graph revisions, and receipt through
   one governed semantic command.

The substrate permits removals only for this exact command class and version.
It compiles bounded delete and insert templates into one TripleStore SPARQL
MODIFY operation backed by one RocksDB write batch. Ordinary maintenance removal
batches remain rejected.

Source revision mismatch makes a derived graph stale. Strict reads fail with a
consistency receipt; warning reads expose stale freshness and rebuild guidance.
`mark_stale` replaces lifecycle metadata while retaining content for diagnosis.
Rebuild publishes a new rule revision under an expected prior derivation.
Logical deletion removes derived content and leaves an invalidated metadata
tombstone, preserving auditability without allowing consumers to treat the graph
as current. Asserted source graph revisions never change during these actions.

## Read Diagnostics

`ReadDiagnostics` reduces query or projection receipts to bounded operational
facts:

- query/projection and catalog versions and digests;
- evaluated dataset revision and redacted graph revision summary;
- consistency status and gaps, completeness gaps, freshness, and truncation;
- cache disposition and a stable safe error code;
- one action: re-query, restore completeness, rebuild a derived graph, continue
  with a cursor, reauthorize, or escalate integrity failure.

Ordinary diagnostics expose graph counts and revision bounds, not graph IRIs.
Privileged diagnostics expose authorized graph families and revisions, still not
raw graph names. No diagnostic contains SPARQL text, backend IDs, source bodies,
credentials, paths, secrets, prompts, stack traces, or arbitrary exception
details.
