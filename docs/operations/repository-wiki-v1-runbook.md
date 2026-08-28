# Repository Wiki Deterministic V1 Runbook

This runbook operates the opt-in repository-wiki service without treating a
maintainer process, scheduler queue, cache, search index, render artifact, or
workspace as durable truth. The existing TripleStore, accepted source
snapshots, and content-addressed artifacts remain authoritative.

Hosted synthesis is unavailable in V1. An incident that appears to involve a
production model call is a release-blocking invariant violation, not a normal
provider outage.

## Observe Before Acting

Use the authorized repository Wiki `Usage & cost` and `Operations` views. Pin
the evaluated time, repository/tenant scope, enrollment revision, cancellation
generation, source fence, current edition, compiler/profile digests, lease
fence, outstanding reservations, terminal usage, and dataset/graph revisions.
Never copy page bodies, prompts, credentials, private dependency endpoints,
absolute paths, raw graph names, or SPARQL into incident notes or telemetry.

The expected deterministic posture is:

- model calls, input/output/cached/reasoning tokens, measured model cost,
  unknown model liability, and live model reservations are all zero;
- manual and automatic deterministic attempts may report local elapsed time,
  input bytes, metadata calls, graph growth, and retained storage;
- an Off repository admits no new compilation or maintainer work; and
- a current edition is selected only by its exact repository enrollment
  pointer and current source fence.

## Enrollment And Manual Regeneration

1. Confirm the repository is in the actor's reviewed scope and is currently
   Off or Manual at the observed enrollment revision.
2. Select only `manual_deterministic`; confirm retained-read and retention
   posture independently from generation.
3. Commit the semantic configuration transition before requesting work.
4. Request one deterministic regeneration using the new enrollment revision,
   current source fence, and pinned compiler/profile digest.
5. Verify terminal zero-model usage, lint, review, closure, and the atomic
   activation receipt. A browser success message is not activation evidence.

## Automatic Maintenance

1. Require accepted manual pilot evidence for the same profile tuple.
2. Transition to `automatic_deterministic` explicitly. Do not infer enrollment
   from an existing edition or surviving worker.
3. Confirm one current logical owner/lease for the repository, bounded fleet
   capacity, and no stale cancellation generation.
4. Watch source-to-activation age, coalescing, queue pressure, deterministic
   failures, lease expiry, coverage, and terminal accounting.
5. On restart, recover only from graph state under the original source,
   enrollment, cancellation, lease, compiler, and profile fences.

## Stale Edition Or Repeated Failure

1. Compare the edition source fence with the authoritative accepted source.
2. Inspect explicit gaps, blocking lint, missing artifacts, dependency
   metadata state, and recovery dependency readiness.
3. Supersede stale attempts; never resume them under a newer fence.
4. For a transient dependency failure, retry only within the fixed profile
   bound. For an incompatible profile or missing artifact, leave the wiki
   visibly stale/incomplete and require a new authorized attempt.
5. Escalate repeated deterministic failures and abandoned editions without
   weakening lint, review, or activation requirements.

## Disable And Teardown

1. Commit the exact successor Off enrollment and newer cancellation generation.
2. Only after the commit, stop admission, cancel pending triggers, request
   active effect cancellation, revoke leases, and stop the optional owner.
3. Reject every late compilation, preview, callback, recovery, or activation
   result under the old generation.
4. Release unconsumed reservations. Preserve invoked, usage-pending,
   usage-unknown, accounting, and audit evidence.
5. Retained edition readability follows the separate read/retention policy;
   no retained artifact becomes current by surviving teardown.

## Reservation And Usage Reconciliation

1. Resolve the exact attempt, invocation-before-effect record, reservation,
   accounting fence, price revision, currency, and repository/tenant scope.
2. If provider usage is absent after the bounded retrieval window, mark usage
   unknown and retain conservative liability. Never fabricate zero.
3. Deduplicate callbacks by terminal usage identity. Do not charge twice or
   refund a consumed/unknown liability without a reviewed adjustment.
4. Keep currencies separate. Do not sum money across currencies in a scalar
   fleet total.
5. Deterministic attempts must remain exact zero across every model-token and
   model-cost field; local resource accounting is reported separately.

## Graph Repair

1. Put the knowledge store into its accepted maintenance posture and preserve
   the failing dataset and latest verified backup.
2. Run integrity, ontology, shapes, GraphRegistry, semantic protocol, and
   repository-wiki current-edition checks.
3. Repair only through registered migration or semantic command paths. Never
   edit a repository wiki graph, current pointer, reservation, or usage record
   directly.
4. Rebuild disposable navigation, search, fleet, and cost projections only
   after authoritative graph verification passes.
5. Reopen the RW gate if any current/source/accounting/isolation invariant was
   violated, even if the product appears healthy after repair.

## Backup And Restore

Follow [Knowledge store backup and restore](./knowledge-store-runbook.md) and
[Disaster recovery](./disaster-recovery.md) for the authoritative store.

After restoring a verified checkpoint:

1. enumerate repository wiki graphs from the registry, bounded by the fleet
   recovery profile;
2. verify exactly one current edition per enrolled repository and match its
   repository, tenant, source, enrollment, cancellation, compiler, and profile
   fences;
3. recompute reservation, terminal usage, window rollup, and accounting
   digests from immutable graph records;
4. rebuild disposable navigation/search/render projections;
5. restart only eligible automatic maintainers after dependencies are ready
   and no live lease exists; and
6. record content-free restore evidence and alert on any drift. A drifted
   repository remains degraded and process-free.

## V1 Synthesis-Unavailable Incident

The expected response for every production synthesis request is `unavailable`
before invocation commit, adapter dispatch, network activity, or token-bearing
effect. Verify that the production adapter and price catalogs remain empty and
that repository synthesis opt-in cannot select a profile.

If any hosted provider, model, price, credential, endpoint, adapter, prompt, or
fallback becomes selectable—or any token/cost is observed—disable wiki
generation fleet-wide through the accepted control, preserve accounting/audit
evidence, reject activation, and reopen RW4/RW5. Re-enablement requires a
separate accepted synthesis qualification decision; this runbook grants no
such authority.

## Alert Disposition

| Alert | Immediate disposition |
| --- | --- |
| stale current edition | verify source fence; enqueue a new exact attempt only if enrolled |
| repeated deterministic failure | stop bounded retries; inspect explicit dependency/gap state |
| abandoned edition | keep inactive; reconcile retention and attempt terminality |
| expired lease | acquire only after expiry under current enrollment/cancellation fences |
| queue pressure | preserve fairness/capacity bounds; do not create a durable local backlog |
| stuck reservation | reconcile invocation and terminal usage before release or retry |
| usage pending/unknown | retain conservative liability and audit provenance |
| restore drift | keep repository degraded; rebuild nothing from caches or process state |
| cross-scope invariant | conceal affected projections, disable consequential work, reopen RW5 |
