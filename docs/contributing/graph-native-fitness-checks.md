# Graph-Native Fitness Checks

Before adding a predicate, graph family, command, query, projection, adapter,
dependency, or route, answer every applicable check.

New browser-product work also follows the
[hypermedia product contribution contract](./hypermedia-product-work.md).

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
5. Does browser state contain only presentation preferences and bounded
   signals rather than graph authority, trusted revisions, or workflow
   persistence?
6. Does a target product route use explicit controllers/HEEx, closed requests,
   stable fragment roots, an application-owned coordinator for SSE, and native
   fallback without product LiveView/LiveVue/SaladUI runtime use?
7. If `phoenix_live_view` remains, does the exact consumer manifest prove it is
   qualified compile-time `Phoenix.Component`/HEEx use only?

## Product Security And Delivery Contract

1. Does the trusted boundary reconstruct named human identity, exact scope,
   assurance, delegation, policy revision, graph revisions, and incident
   posture without accepting browser-derived grants or revisions?
2. Does each route, fragment, stream, command, approval, export, and download
   repeat exact resource/action authorization and apply required concealment,
   redaction, step-up, and receipt behavior?
3. Are effects non-GET, CSRF- and Origin-protected, closed-schema,
   idempotent/revision-aware, command-gateway-owned, and receipt-driven?
4. Are Datastar signals untrusted and bounded, patch roots stable, expressions
   static, SSE reauthorized before each patch, and native fallback preserved?
5. Are assets local and pinned, CSP and escaping/sanitization explicit, inline
   scripts forbidden, and source/wiki/graph/log/agent content always data?
6. Do parallel sessions return explicit conflict/stale/revoked receipts and do
   accessibility, graph-lens alternatives, wiki isolation, and wiki cost
   accounting remain intact?

## Change And Evidence Contract

1. Is every exception narrow, reviewed, owned, evidenced, expiring, bound to an
   exact path and symbol, and paired with a reopening condition?
2. Do tests cover native/controller outcomes plus applicable enhancement,
   browser, accessibility, security, failure, revocation, and concurrency
   behavior using the real seam required by the evidence class?
3. Are dependency/source/license/lock/asset identities pinned, and are threat,
   capacity, CSP/proxy, operations, migration, and rollback records current?
4. Does each plan section have one commit, the phase one implementation pull
   request, and the post-merge closure transition required to pin its receipt?

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
private adapters, alternate durable store/queue, unbounded browser graph,
remote/CDN product asset, browser-derived authority, unallowlisted target
route/event, product LiveView/LiveVue/SaladUI use past its migration fence, or
unexplained compatibility consumer is release-blocking.
