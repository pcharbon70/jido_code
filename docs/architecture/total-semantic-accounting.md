# Total Semantic Accounting Protocol

## Event Heads And Bounded Segments

Execution command line `2.0.0` orders events by immutable predecessor, never by
caller-selected sequence or wall clock. A new attempt creates segment zero and
an `attempt_started` event at sequence zero. Every append consumes the exact
active head and writes one successor head plus one deterministic contiguous
event. The active head is the unique head without `hasSuccessor`; the command
precommit guard and graph-revision compare-and-swap make concurrent use of one
head conflict.

`run_event_segment` is the only Phase 1 reserved family activated by the MG2
candidate. `GraphRegistry` `2.1.0` keeps experience, content lifecycle, and
episode content disabled. Legacy command versions cannot target the segment
family, and closed segment graphs cannot accept late events.

Each closure independently checks the exact event set, per-type sets,
accounted resources, content-capture identities, contiguous inclusive range,
and effect starts/outcomes. It commits an ordered event-set digest, content
root, predecessor root, carried open-effect set, and final segment root. The
same command closes the segment, appends its root to the attempt, and may open
the successor segment with its carried effects. Missing or extra resources,
sequence gaps, duplicate starts, outcomes without starts, or implicit carried
effects fail closed.

The ratified 80-event and 80-segment limits reserve closure capacity. A caller
must close before the event limit. At the attempt segment/root limit,
continuation requires a new deterministic attempt bound to an explicit
continuation authority and the predecessor segment root; the protocol never
creates an unfinalizable oversized segment or attempt root.

## Episode And Body Capture Accounting

`CaptureManifest` `2.0.0` is created in the run root in the same atomic
`RecordExecutionAttempt` batch as segment zero and its sequence-zero head. It
pins the enabled profile and purpose, data-policy revision, expected event and
body classes, exact opaque body identities, protocol limits, and an expected
root commitment. A diagnostic or project-total profile cannot enter this path.

Every expected body is owned by exactly one source-event role and receives one
immutable `ContentCapture` shell in that event's segment. The shell separately
records capture outcome, representation, location, availability, retention,
hold, classification, purpose, policy, reconstruction, provider availability,
allowed uses, limitations, retention class, and any redaction receipt. The
accepted outcomes are `captured`, `omitted_by_policy`,
`unavailable_at_source`, and `capture_failed`; the representation is
independently `exact`, `deterministically_redacted`, `normalized`,
`commitment_only`, or `absent`.

Consistency checks do not collapse those dimensions. A digest-only capture is
not replayable even when it remains available; an absent body must say why and
cannot claim reconstruction; redacted content requires its receipt; external
availability is reported only for an external location; and semantic-history
policy still rejects exact tool output, raw prompts, and secret values.
Manifest closure compares the exact expected and captured body sets and commits
a completeness root. Missing, duplicate, foreign, or unlisted shells are a
closure conflict rather than an inferred omission.

## Immutable Execution Resources

Every command `2.0.0` runtime observation consumes the same segment head.
Model and tool starts and outcomes are separate deterministic resources; each
binds the attempt, lease, fence, context manifest/revision, resource revision,
semantic digest, predecessor head, and occurrence time. An outcome names its
exact start and closes that effect. It never adds a result property to mutate
the start resource.

New tool starts resolve only as `RecordToolInvocationStart`. The legacy
`RecordToolInvocation` name remains resolvable on the `1.6.0`/`1.8.0` history
lines but is absent from command line `2.0.0`. Before dispatch, a tool start
must bind a current capability, approval request, and effect journal. Missing
bindings, a stale fence, an inexact context, a reused start, an outcome without
a start, or `dispatch_state: dispatched` fails closed.

Attempt transitions, normalized proposals, sandbox events, artifacts,
messages, cancellation, retry, terminal, provider, and lifecycle observations
use the same sequence. Provider observations retain a provider-source identity
and contiguous source order and require an explicit attribution resource
before they can enter an attempt. Verification, decisions, publication,
deployment, incidents, and delayed review remain in their existing accepted
families; a segment event may link them under a validated family/role pair but
does not move or promote them.
