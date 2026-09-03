# Bounded Projections, Cache, And Subscriptions

Phase 5 projections are temporary consumer views over exact graph query
receipts. They improve ergonomics and delivery latency without becoming a
second source of truth.

## Projection Envelope

`ProjectionCatalog` maps each reviewed query version to one reviewed scalar,
table, timeline, tree, or bounded-subgraph shape. `Projection.build/4` accepts
only a complete `QueryResult` and emits a JSON-safe `ProjectionEnvelope` with:

- projection, query, and ontology versions;
- actor scope and a non-reversible authorization-scope digest;
- dataset and source graph revisions;
- generation time, completeness, freshness, truncation, warnings, and cursor;
- the complete consistency receipt and normalized parameter digest;
- decoded data containing no RDF or backend structs.

Canonical IRI values remain unchanged for semantic actions. Display labels are
derived separately and escaped. Decoders are fixed attributable copies; they do
not invent mutable status, drop revision provenance, select among contradictory
claims, or widen graph scope.

## Disposable Cache

`ProjectionCache` stores envelopes only in process memory. Keys include
projection/query versions, normalized parameter digest, authorization-scope
digest, graph revisions, ontology version, and consistency digest. Fetch also
requires an exact current context containing dataset revision and the same
authority and revision facts.

Every newer semantic commit may evict older entries. This deliberately favors
correctness over cache selectivity: ontology, policy grant, completeness,
source, or derived-rule changes cannot reuse an older entry. Eviction, reset,
process restart, or total cache loss is a miss followed by the same canonical
catalog query and projection decode. No durable cache database exists.

## Lossy Subscriptions

`ProjectionSubscription` permits only bounded factory, repository, goal, and
attempt scopes. It subscribes through `ChangeFeed`, tracks the last evaluated
dataset revision, and coalesces duplicate, reordered, or burst notifications to
the highest revision hint. The hint contains no answer: a supplied refresh
function must run the current authorized catalog query.

Reconnect explicitly compares the consumer's last revision with current graph
state and schedules a re-query, covering notification or mailbox loss.
Authority-context changes force another refresh; a revoked or narrowed actor
becomes inaccessible instead of retaining a cached projection. Process restart
uses the consumer's last known revision and the same re-query path.

## Hypermedia Delivery Adapter

The target controller and stream coordinator consume only complete authorized
`ProjectionEnvelope` values. A full page or fragment reauthorizes before query;
an SSE coordinator reauthorizes at admission, periodically, on revocation, and
before every protected patch. A `ChangeFeed` or PubSub message remains only a
refresh hint. It cannot be serialized as product truth or forwarded to the
browser as an authoritative revision. Unavailable results clear the affected
fragment rows, and reconnect begins from a current snapshot rather than a
process cache.
