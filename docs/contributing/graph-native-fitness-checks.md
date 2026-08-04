# Graph-Native Fitness Checks

Before adding a predicate, graph family, command, query, projection, adapter,
dependency, or route, answer every applicable check.

## Semantic Contract

1. Is the predicate relationship-oriented, namespaced, documented, shaped,
   and compatible with the current ontology release?
2. Does a new graph family declare scopes, writer capability, mutability,
   completeness, retention, and allowed links in `GraphRegistry`?
3. Does a command use a closed type/version, server-owned graph targets,
   actor/scope authority, optimistic revisions, provenance, validation, and an
   immutable receipt in one atomic commit?
4. Does a query use the reviewed catalog, typed parameters, graph/scope
   authorization, row/byte/depth/time limits, consistency, and safe errors?
5. Is a projection bounded, revision-labeled, stale/incomplete-aware,
   reconstructable, and free of raw RDF/store handles?

## Boundary Contract

1. Does the module belong to Knowledge, Factory, Integrations, Runtime, Web, or
   the narrow root application layer, with dependencies flowing only in the
   accepted direction?
2. Is every struct a transient contract rather than a persisted entity,
   aggregate, foreign-key join, or generic CRUD record?
3. Are adapter/provider outputs observations until graph policy and semantic
   commands accept them?
4. Are credentials, source bodies, prompts, raw model/tool output, private
   paths, and personal data rejected or classified/redacted before output?
5. Does browser state contain only presentation preferences and bounded island
   props/events rather than graph authority or workflow persistence?

## Required Verification

Run focused tests, then:

```bash
mix compile --warnings-as-errors
mix architecture.check
mix jido_code.release audit
mix hex.audit
npm audit --omit=dev
mix precommit
```

Update ontology fixtures/checksums, command/query catalogs, capacity limits,
threat model, runbooks, and migration contract when their boundary changes.
Any direct RocksDB/TripleStore handle outside Knowledge, raw SPARQL outside its
private adapters, alternate durable store/queue, unbounded browser graph, or
compatibility facade is release-blocking.
