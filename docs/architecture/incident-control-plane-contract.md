# Incident Control Plane Contract

- Status: Accepted architecture contract under ADRs 0009 and 0011; controls remain unavailable
- Specification version: `1.0.0`
- Accepted: 2026-09-03 through HUI-A3 merged-candidate governance
- Owners: JidoCode security, operations, Factory, runtime, and audit maintainers
- Milestone: G — Security And Release Qualification
- Decisions:
  [ADR 0009](../adr/0009-human-identity-scoped-authorization-and-separation-of-duty.md)
  and [ADR 0011](../adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md)

## Purpose

This specification defines the restricted incident view and the semantic
resources required before freeze, revoke, quarantine, stop, recovery, or reopen
can be offered as product controls. It does not turn operational UI into an
authority bypass.

## Incident Resource And Lifecycle

An incident records exact factory/tenant/project/profile/provider/attempt scope,
classification, severity, detection source, opened time, owner, current state,
policy revision, evidence refs, affected capabilities, containment, recovery,
handoff, decisions, and receipts.

The proposed closed lifecycle is:

```text
detected -> triaged -> containing -> contained -> recovering
  -> monitoring -> resolved -> reviewed -> closed
```

Reopen creates an authorized transition with reason and current evidence.
Deletion or silent reset is prohibited.

## Read Posture

The restricted incident page correlates authorized security events,
operational symptoms, commands, effects, attempts, evidence, source outcomes,
cost/capacity, and recovery state without exposing unrelated project content.
An operator may receive stop authority and redacted metadata without source or
complete-memory access.

## Proposed Semantic Controls

Controls are unavailable until their ontology, capability, command, gateway,
runtime, receipt, and recovery contracts are accepted:

- freeze new attempt admissions within exact scope;
- revoke/narrow an exact capability, delegation, profile, or credential
  generation;
- cancel/stop through already admitted attempt/runtime semantics;
- quarantine a provider/profile/repository cohort;
- hand off incident ownership;
- record containment/recovery evidence;
- enter/leave monitored recovery; and
- reopen/close under separation-of-duty policy.

No control kills a PID, edits a graph directly, mutates source, erases audit,
or broadens scope from a filter selection.

## Authorization And Approval

Every control binds exact actor/assurance, incident, scope, action digest,
target set, current policy/state/revisions/fences/generations, consequence,
expiry, idempotency, reason, and receipt. Batch scopes are server-computed,
previewed, bounded, and authorize each target independently. Partial outcomes
are explicit.

High-risk revoke, restore, or reopen may require two current distinct
principals. Emergency operational authority does not imply project-content,
policy-admin, or final-review authority.

## Recovery And Evidence

Incident recovery follows existing graph and runtime recovery boundaries.
Disposable process state cannot prove containment or closure. Closing requires
current evidence, residual-risk disposition, restored/narrowed grants, stream
revocation verification, source/repository reconciliation where applicable,
owner handoff, and post-incident review/runbook actions.

## Fallback Before Command Admission

Until semantic controls are accepted, the incident surface is read-only and
links to versioned external operator procedures. It MUST label controls as
unavailable rather than render decorative or direct-process buttons.

## Qualification

Drills cover wrong-scope and stale incident refs, concurrent operators,
partial batch failure, duplicate commands, session/role revocation, runtime
non-cooperation, provider outage, deploy restart, audit integrity, two-person
approval, rollback, reopen, and least-disclosure operation.

## Acceptance And Reopening

The incident gate closes only when every operative control is a versioned
semantic command with exact capability, receipt, recovery, audit, runbook, and
drill evidence. It reopens on direct process/graph mutation, unbounded batch,
filter-derived authority, missing partial outcome, audit loss, false
containment/closure, or an operator receiving unnecessary project content.
