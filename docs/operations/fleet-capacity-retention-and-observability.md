# Fleet Capacity, Retention, And Observability

This runbook defines the Phase 10 operating envelope. The graph remains the
only durable coordination and product state. Scheduler process state,
telemetry, benchmark samples, and UI projections are disposable.

## Fleet Coordination

Every scheduler cycle re-queries candidates, active leases, and the fleet
policy projection. `JidoCode.Factory.Fleet.Policy` intersects graph policy
with trusted runtime ceilings; graph policy can narrow but cannot widen those
ceilings. `JidoCode.Factory.Fleet.Admission` then applies global, cohort,
repository, provider, capability, rate, budget, risk, and campaign limits.

Ordering is deterministic: emergency policy, starvation state, priority,
fairness sequence, then task IRI. A deferred result contains fixed reason codes
and the next wait count. The owning semantic command records that result in the
graph; the scheduler keeps no durable queue. Reconciliation wakeup storms are
coalesced and every acquisition failure is isolated to its candidate.

## Retention

`JidoCode.Knowledge.Retention.Policy` covers every graph family plus command
receipts, validation reports, decisions, accepted knowledge, goals, policy,
audit, and derived caches. The planner walks links from active decisions,
knowledge, goals, policy, audit roots, and legal holds before selecting exact
statements.

Retention execution is available only through `JidoCode.Knowledge.Admin` and
`JidoCode.Knowledge.Maintenance`. It requires the exact plan ID as confirmation,
creates a checkpoint, enters retention maintenance, and atomically writes the
audit activity while deleting at most 900 exact statements. Optimistic dataset
and graph revisions prevent stale plans. Integrity must pass before the
operation returns success. The receipt includes the checkpoint, checksum,
counts, affected graph count, and derived graphs that must be rebuilt.

Ordinary semantic commands cannot select the retention operation metadata, and
the atomic writer rejects every unregistered removal class. The audit activity
records a minimum restore revision; restore reads that graph-authoritative floor
and rejects older checkpoints before staging them. Create a post-retention
checkpoint for recovery, then rebuild derived projections from retained
authoritative graphs.

## Service Objectives

| Objective | Release threshold |
| --- | ---: |
| Readiness | ready |
| Availability | at least 99.9% |
| Unresolved commit outcomes | 0 |
| Recovery point / backup age | at most 24 hours |
| Recovery time | at most 15 minutes |
| Authoritative projection freshness | at most 5 minutes |
| Bounded query p95 | at most 500 ms |
| Fleet queue depth | at most 200 |
| UI projection error ratio | at most 1% |

Telemetry uses fixed stage, outcome, state, and error enums. Trace correlation
is a 32-character hash reference derived from the semantic correlation IRI.
Metrics do not tag arbitrary IRIs. Store-unavailable snapshots and VM metrics
remain emit-able without reading the graph.

## Supported Capacity

The maximum supported profile is 500 repositories, 50,000 snapshots, 250,000
source symbols, 1,000,000 observations, 50,000 goals/tasks, 100,000 runs,
500,000 evidence statements, 100,000 memory assertions, 1,000,000 audit
statements, and 500,000 derived statements. At 80% of any maximum, require
pagination and surface a soft-limit warning. Above a maximum, reject admission
without partial writes or a current-state claim.

Operational limits are 100-row default pages, 500-row maximum pages, 5-second
queries, 120-second maintenance calls, 1,000 scheduler candidates, and 900
retention removals per atomic commit. Run the bounded operation matrix with:

```bash
mix jido_code.capacity --profile small
mix jido_code.capacity --profile medium
mix jido_code.capacity --profile maximum
```

The benchmark covers startup/recovery, ingestion, writes, bounded queries,
reconciliation, eligibility, reasoning, backup/restore, retention, UI
projection, concurrent access, provider storms, scheduler fairness,
long-running attempts, cold/warm cache, and store compaction. Any callback that
exceeds its deadline is terminated and the run fails as a bounded failure.

The 2026-08-04 local bounded-harness baseline completed all 17 classes. The
worst p95 was 9 microseconds for `small`, 58 microseconds for `medium`, and 808
microseconds for `maximum`; the maximum profile correctly reported soft-limit
pressure. These synthetic timings verify harness growth and deadline behavior.
Embedded-store startup, backup/restore, retention, scheduler restart, and
concurrent command behavior are measured by their owning integration suites.
