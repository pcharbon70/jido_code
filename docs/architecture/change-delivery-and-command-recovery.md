# Change Delivery And Command Recovery

## Post-Commit Feed

JidoCode.Knowledge.Writer invokes ChangeFeed only after CommandPipeline returns
a newly committed durable semantic receipt. Replay, validation failure,
authorization failure, conflict, timeout, and unavailable outcomes publish
nothing. PubSub failure is treated as a dropped optimization and never changes
the durable command result.

Each ChangeEvent contains only:

- the committed dataset revision;
- affected registered graph family names and their new revisions;
- the already-authorized semantic scope IRI;
- the fixed command-registry class; and
- the semantic receipt IRI.

Events omit statement bodies, raw graph IRIs, actors, principals, delegations,
grants, reasons, idempotency keys, failure details, prompts, source text, and
secrets. The topic uses the fixed jido-code:changes:v1 prefix followed by a
64-character SHA-256 encoding of the validated scope IRI. Arbitrary caller
text is never copied into the topic.

## Subscriber Contract

PubSub is a lossy wake-up channel, not an event log. A subscriber retains the
last dataset revision whose authorized projection it evaluated. A hint with a
newer revision causes a bounded graph re-query from that known revision. Equal
or older hints are ignored. Subscribers may coalesce hints and must behave
correctly when messages are dropped, duplicated, delayed, or reordered.

Correctness comes from graph revision comparison and the query result. Event
order, delivery, process memory, and PubSub membership have no authority.
Subscription is exposed to product code only after its owning query boundary
has admitted the scope; this phase provides the internal feed primitive.

## Command Status

Command recovery accepts the original validated CommandEnvelope, not an
idempotency key alone. The lookup reconstructs both the stable request commit
IRI and semantic receipt IRI, reads the current factory policy graph and
bounded target snapshot, and authorizes at a trusted lookup time. Revoked,
expired, ambiguous, or widened authority returns the fully concealed
inaccessible result.

After authorization, the lookup combines two graph facts:

1. the immutable substrate commit receipt in the system graph; and
2. the command's semantic outcome in its bounded monthly audit graph.

The bounded projection distinguishes unknown, staged, committed, rejected,
superseded, and inaccessible. A fingerprint or command-IRI mismatch is
concealed. Corrupt or contradictory graph evidence fails rather than being
interpreted as absence.

The accepted Phase 2 atomic transaction strategy has no staging graph or
separate commit marker. Staged is therefore an explicit protocol state that
cannot occur for this backend. There is no process-local staging state to
reconcile. An absent substrate receipt and absent semantic outcome is unknown;
callers may then submit or retry the same retained identity. Rejected and
superseded states require their own persisted, authorized audit receipt and
are never inferred from a transient error response.
