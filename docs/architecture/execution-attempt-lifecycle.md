# Execution Attempt Lifecycle

An execution attempt is a graph activity bound to one task, accepted plan,
exact source snapshot, context digest, actor/agent capability, execution lease,
and fencing token. The run graph and repository control graph are committed in
one semantic command before a runtime effect is allowed.

## Start Contract

`RecordExecutionAttempt` creates an open, building `run/{attempt}` graph and
atomically:

- records the attempt, bounded instruction, context digest, exact input graph
  revisions, runtime version, omissions, and optional retry predecessor;
- appends prepared and starting attempt transitions;
- advances the task from leased to executing;
- advances the lease from active to executing while preserving its expiry;
- checks the current lease fence, task/lease/plan endpoints, exact graph
  revisions, absent run graph, and absence of another non-terminal attempt.

The factory coordinator dispatches runtime start only after a committed or
idempotent receipt. A lost response produces a status-recovery action. A
definite start failure invokes a separately supplied semantic failure recorder;
the attempt is retained and transitioned to failed instead of being deleted.

## Transition Contract

Attempt transitions are append-only and require the current attempt
predecessor, exact run/control revisions, and current lease fence. The states
are prepared, starting, running, waiting-tool, cancelling, cancelled,
completed, failed, timed-out, abandoned, recovered, and superseded. Bounded
runtime sequence, outcome, usage digest, and safe diagnostics can be attached
to a transition.

Cancellation is a committed `RequestExecutionCancellation` transition before
the runtime cancellation callback. Its eventual acknowledged, forced,
timed-out, failed, or ineffective result is a later attributable transition.

Completion is only a runtime outcome. It moves the task to awaiting evidence;
it does not satisfy a goal, accept evidence, or adopt knowledge.

## Retry Contract

A retry is a new attempt IRI linked with `retryOf`; prior run graphs are never
reset or overwritten. Retry policy considers failure class, attempt count,
budget, cancellation, source and plan freshness, constraints, policy,
capability, and lease state. Material context changes require reconciliation.
Exhausted, unsafe, repeated, ambiguous, or unclassified failures require an
explicit decision. A new lease and fence are required whenever the prior lease
is no longer active for execution.
