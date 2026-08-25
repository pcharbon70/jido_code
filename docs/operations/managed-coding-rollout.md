# Managed Coding Rollout Operations

## Ownership and review

The managed coding service has named owners, independent release approvers, and
an on-call rotation. Operators review the service dashboard and retained graph
evidence on the declared cadence. Safety, authority, isolation, provenance,
quality, cost, and capacity alerts route to on-call and escalate under the
pinned escalation policy.

## Incident procedure

1. Disable new effects at the narrowest safe scope, or globally when scope is
   uncertain. Recovery and cancellation capacity must remain available.
2. Triage affected attempts, cancel and drain work, and revoke exposed or
   potentially exposed credentials.
3. Preserve graph facts and immutable artifacts. Quarantine candidates and
   pending draft publication without deleting prior evidence.
4. Notify affected tenants under the incident policy. Reconcile ambiguous
   effects, repair or roll back infrastructure/profile changes, and document
   every limitation.
5. Reenable only after an independent approver verifies containment, rollback,
   reconstruction, isolation, credential, drain, and alert drills.

## Supported operating envelope

Only the exact signed production profile and its tenant, repository, task,
language, dependency, network, actor, budget, and exclusion envelope are
supported. Shadow output is non-authoritative. Pilot output is limited to draft
branches and draft pull requests from accepted candidates with mandatory human
review and repository protections. Automatic approval, automatic merge, and a
general multi-agent topology are unavailable and outside Phase 6 authorization.
