# Agent Attempt Workspace And Command Contract

- Status: Proposed under ADR 0011
- Specification version: `0.1.0`
- Owners: JidoCode product, Factory, runtime, verification, security, and cost
  maintainers
- Milestone: E — Governed Agent Control
- Decision: [ADR 0011](../adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md)

## Purpose

This specification defines the canonical attempt workspace, timeline, panels,
oversight stages, control vocabulary, approval presentation, receipts, costs,
parallel-human behavior, and recovery without conflating attempt,
`InteractionSession`, runtime process, provider thread, or browser session.

## Workspace Identity And Header

The route is bound to an opaque attempt ref and server-proven project/
repository containment. Its canonical header shows safe human labels and exact
current posture for:

- repository-backed project, task, attempt, candidate, and source revision;
- logical agent/profile digest, runtime/deployment/billing class, readiness;
- authority/capability summary, environment, lease/fence, and owner;
- projection graph/source revisions, completeness, freshness, and connection;
  and
- current cost/budget and attention state.

Graph IRIs, credentials, provider sessions, process IDs, sandbox paths, raw
prompts/reasoning/output, and unrestricted traces are not displayed.

## Lifecycle And Outcome Rails

The attempt rail maps the accepted states: prepared, starting, running,
waiting-tool, cancelling, cancelled, completed, failed, timed-out, abandoned,
recovered, and superseded.

The downstream outcome rail separately shows candidate, independent
verification, decision, draft publication, external human application/merge,
source re-observation, post-change verification, follow-up, and satisfaction.
Draft publication remains contract-only while no production provider exists.

## Causal Timeline

The bounded timeline correlates normalized plans, interaction-session events,
questions/answers, directives, admitted tool/workspace effects, artifacts,
checks, verifier evidence, costs, human commands, receipts, recovery, and
outcomes. Events retain causal/sequence identity, safe actor, source, time,
completeness, and gaps/truncation.

The default is a normally navigable list/table, not a live-announced raw log.
Only batched meaningful statuses enter polite live regions. Users can pause
nonessential visual updates and retain reading position; this does not pause an
agent and freshness is shown.

## Oversight Panels

- Before run: task, source, profile, authority, capabilities, acceptance,
  consent, billing, budget, and risk.
- Co-plan: plan, assumptions, context manifest, criteria, questions, and steer.
- During run: lifecycle, last meaningful effect, waits, timeline, budget,
  lease/fence, and admitted controls.
- After run: diff/artifacts, checks, verifier evidence, contradictions,
  decision, draft publication, external observation, and satisfaction.

Conversation is one interaction panel and cannot hide effects, evidence,
approvals, failures, costs, or receipts.

## Closed Control Vocabulary

The initial UI may expose only currently admitted operations:

| UI action | Current semantic/runtime mapping | Required binding |
|---|---|---|
| Steer | `steer` | current attempt, sequence, actor, lease/fence, profile |
| Answer | bounded answer represented through `steer` | current clarification and audience plus steer bindings |
| Cancel | `cancel` | current cancellable state and exact consequence |
| Handoff | `handoff` | current attempt and candidate-closure posture |
| Retry | accepted recovery classification represented through `start` | exact failed/recovery state; no ambiguous generic replay |
| Recovery | accepted recovery path represented through `start` | recovered fence/state and current provider posture |
| Authorize draft publication | publication gateway | immutable candidate, evidence/decision, policy, human step-up, action digest |

The stable runtime API remains admit, start, steer, cancel, status, and handoff.
Friendly labels do not create new operations. Pause/resume, emergency stop,
freeze, quarantine, bulk action, source merge, and incident reopen remain absent
until semantic contracts exist.

## Canonical Command Preview And Receipt

The trusted preview renders action, target, repository/environment,
parameters/effect, candidate/diff, blast radius, reversibility, policy, expected
revisions/fence, expiry, and action digest from server data. Escaped agent
rationale is visually separate untrusted support.

Submission uses CSRF, current identity/assurance, exact authorization,
idempotency, expected state/revisions/fence/profile, and bounded reason. Success
renders an immutable receipt and refreshed projection. Conflict/rejection
commits no effect and renders current safe posture. Lost transport reconciles
by receipt lookup.

## Parallel Humans And Tabs

Each tab maintains its own harmless filters/selection and authorized stream.
Two authorized humans racing conflicting steer/cancel/handoff/decision commands
use compare-and-set semantics. At most one transition commits; losers receive
the current safe state/receipt without last-write-wins or cross-scope detail.

## Cost And Budget

The workspace distinguishes reported/estimated/unavailable input, cached,
output, reasoning, total tokens, monetary cost, reservation, budget, remaining,
and forecast. Cost is attributed to exact attempt/profile/provider/outcome and
does not claim zero from missing observations.

## Acceptance And Reopening

Milestone E closes with gateway parity, lifecycle/outcome distinction,
timeline bounds, current-control mapping, canonical approval, step-up,
idempotency, receipt recovery, cancellation/retry ambiguity tests, two-human
races, parallel tabs, accessibility, and real-adapter evidence. It reopens if a
UI label invokes an uncontracted command, agent text becomes trusted approval,
optimistic success appears, attempt/session identities collapse, or execution
is presented as verification/decision/application/satisfaction.
