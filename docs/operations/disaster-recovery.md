# Disaster Recovery And Integrity Repair

## Incident Matrix

| Condition | Immediate response | Recovery boundary |
| --- | --- | --- |
| Store unavailable or locked | stop admission; preserve path and owner process evidence | restart the sole owner; never delete locks |
| Corrupt metadata or graph integrity | fail stop and preserve the active dataset | restore a checksum-verified checkpoint |
| Disk full or write uncertainty | stop writes and look up the immutable commit receipt | expand local storage, then retry only per receipt policy |
| Failed/interrupted migration | remain in maintenance | restore rollback target or resume the exact graph plan |
| Lost backup | alert critical; create a verified checkpoint if the store is healthy | do not claim accepted RPO until redundancy returns |
| Stale external artifact | mark stale/incomplete | re-observe provider and repository state |
| Orphan runtime/worktree | deny semantic authority | clean disposable runtime and rebuild from active graph leases |
| Inconsistent asserted history | preserve evidence and fail stop | manual escalation; no destructive repair command |

## Restore Procedure

1. Quiesce semantic commands, scheduling, reconciliation, and execution.
2. Record current health, release digest, dataset revision, and candidate
   artifact ID. Preserve the damaged dataset read-only.
3. Run restore with the artifact ID repeated as confirmation. Raw paths are not
   accepted.
4. The store owner validates artifact identity, payload checksum, store/backend
   schema, retention floor, ontology metadata, and graph integrity in an
   isolated target.
5. Only after validation does it atomically switch the active dataset selector,
   reopen the quad store, write the restore activity, and resume readiness.
6. Trigger derived-graph rebuild, projection cache reset, scheduler and
   reconciler rediscovery, subscription reconnect, attempt recovery, provider
   observation refresh, and orphan runtime cleanup.
7. Run release verification, integrity, representative queries, product
   projection, and one controlled semantic command before restoring admission.

Schedulers, reconcilers, caches, PubSub delivery, runtime workers, and
worktrees are never restore inputs. Their correct state is reconstructed from
the graph and current external observations.

## Repair Policy

Permitted repair is limited to rebuilding replaceable derived graphs/caches,
restoring a verified checkpoint, or applying a versioned semantic migration
that preserves source history. Never rewrite immutable ontology, observation,
source revision, run, evidence, decision, memory, audit, or commit-receipt
history in place. Unknown lineage, failed checksums, contradictory asserted
history, unavailable legal-hold evidence, or an unresolvable receipt outcome
requires operator escalation and fail-stop posture.

## Recovery Objectives

The accepted objectives are a checkpoint no older than 24 hours and recovery
within 15 minutes. Local integration evidence restores, validates, switches,
and reopens isolated test datasets in under 5 seconds; retention tests prove an
RPO of zero relative to the selected checkpoint and reject pre-erasure restore.
Record production incident timestamps and backup age in the incident audit;
local timings are not a substitute for deployment measurements.
