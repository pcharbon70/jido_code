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
