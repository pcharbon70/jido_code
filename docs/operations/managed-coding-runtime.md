# Managed Coding Runtime Operations

The managed coding runtime fails closed when concurrency, tenant, repository,
provider, sandbox, verifier, or adapter limits are exhausted. Work is admitted
immediately, deferred in a bounded expiring queue, or rejected before durable
admission. Reserved global slots remain available for recovery and cancellation.

## Degradation and response

- Sustained pressure: stop ordinary admission, preserve reserved control capacity,
  drain fairly by tenant, and investigate the saturated dimension.
- Stuck attempts or missing outcomes: disable new effects for the affected adapter,
  reconcile from graph evidence, and quarantine ambiguity rather than replaying it.
- Orphaned leases or workspaces: fence the attempt, reconstruct only from pinned
  inputs, and clean or quarantine disposable material under retention policy.
- Fence conflicts or evidence gaps: stop the attempt and require authorized
  resolution. Never edit or discard prior evidence.

## Safe drain, restart, and emergency disable

Disable new admission first, allow bounded in-flight effects to finish, cancel
remaining attempts through the durable cancellation protocol, and verify capacity
has been released. After restart, run graph-driven discovery and recovery before
re-enabling admission. Adapter emergency disablement must retain recovery,
cancellation, audit, and operator-resolution capacity.
