# Agent Attempt Workspace And Command Contract

- Status: Accepted architecture contract under ADR 0011; implementation gated
- Specification version: `1.0.0`
- Accepted: 2026-09-03 through HUI-A3 merged-candidate governance
- Owners: JidoCode product, Factory, runtime, verification, security, and cost
  maintainers
- Milestone: E — Governed Agent Control
- Decision: [ADR 0011](../adr/0011-attention-oriented-control-plane-and-knowledge-lenses.md)

## Purpose

This specification defines the canonical attempt workspace, timeline, bounded
conversation panel, oversight stages, control vocabulary, approval
presentation, receipts, costs, parallel-human behavior, and recovery without
conflating attempt, `InteractionSession`, runtime process, provider thread, or
browser session.

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

## Bounded Agent Conversation

The conversation panel is a chat-like view of authorized, durable semantic
interaction. It is not a raw provider transcript, a persistent provider socket,
or the attempt's source of truth. A panel is resolved from the current attempt
to an exact `InteractionSession`; when more than one authorized session is
related, the user selects one explicitly and the server never guesses from tab,
URL, message content, or provider state.

The closed projection contains only fields independently authorized for the
current principal:

- safe participant and audience labels plus exact session purpose/state;
- bounded messages with sender class, intent, sequence, recorded time,
  classification, reply relation, provenance, and resulting command/receipt;
- current clarification question, audience, expiry, and whether an answer is
  still admissible;
- gaps, redaction, truncation, stale/unavailable state, and pagination; and
- observed continuation and outcome state when durable runtime evidence exists.

Raw prompts, provider transcripts, private chain-of-thought, token-by-token
generation, unrestricted tool output, credentials, graph IRIs, provider session
IDs, process IDs, and sandbox paths are excluded. Message content is rendered as
escaped plain text with line breaks preserved; v1 does not execute HTML or
Markdown and accepts no attachments.

### Composer And Delivery

The composer exposes separate, state-derived modes rather than a generic Send
operation:

| Mode | Availability | Required binding |
|---|---|---|
| Answer | one current answerable clarification | attempt, session, clarification, audience, reply target, actor, sequence, revision, lease/fence, profile |
| Steer | current gateway/profile/state admits steering | attempt, session, audience, actor, sequence, revision, lease/fence, profile |

Both modes accept at most 4,096 bytes of normalized plain text, apply current
classification and secret-handling policy on the server, and use explicit
non-GET routes with CSRF, Origin/Fetch Metadata, authorization, idempotency, and
canonical action-digest checks. Browser-supplied session, audience, sender,
classification, sequence, capability, profile, or delivery state is never
trusted. Draft text is browser-local and non-authoritative; it may be preserved
across step-up but is discarded on scope, session, or identity change.

The UI distinguishes local draft/submission state from durable message
recording, semantic command admission, continuation observation, and terminal
agent output. It labels rejected, conflicted, expired, revoked, and
transport-uncertain submissions directly and reconciles uncertainty through
receipt lookup plus a fresh projection. It never claims that a message was
read, seen, delivered to a live process, or consumed by an agent unless an
accepted durable observation supports that exact claim. Typing indicators are
not part of v1.

### Conversation Delivery And Accessibility

Conversation history is server-paginated with closed count/time/byte bounds and
stable deep links. A Datastar fragment may add authorized new-message and state
updates through the page's single multiplexed stream, but loss, reordering,
duplication, reconnect, or revocation always converges by re-query. New content
does not steal focus or force scroll; the reader receives a bounded new-updates
indicator and can load or navigate messages using ordinary HTML without
JavaScript.

The transcript uses semantic lists and headings, exposes sender/intent/time/
status without color alone, keeps the clarification and composer labels
specific, preserves unsent text through recoverable enhancement failures, and
supports keyboard, screen reader, zoom/reflow, RTL, forced colors, and reduced
motion. Message-by-message live announcements and token streaming are
forbidden; only batched meaningful state changes use a polite status region.

Parallel projects, attempts, agents, sessions, humans, and tabs retain separate
authorized projections and drafts. Concurrent answers or answer-versus-steer/
cancel races use the same compare-and-set and receipt rules as every other
command; exactly one incompatible transition may commit.

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
does not claim zero from missing observations. A recorded message has no
invented token cost; any controller-reconstructed continuation reports,
estimates, or marks unavailable its exact attributable token and monetary cost.

## Acceptance And Reopening

Milestone E closes with gateway parity, lifecycle/outcome distinction,
timeline and conversation bounds, exact session/audience routing,
current-control mapping, canonical approval, step-up, idempotency, receipt
recovery, cancellation/retry ambiguity tests, two-human races, parallel tabs,
accessibility, and real-adapter evidence. It reopens if a UI label invokes an
uncontracted command, agent text becomes trusted approval, conversation content
crosses scope or classification, a reply reaches the wrong attempt/session/
audience, the UI invents read/delivery/provider-session state, optimistic
success appears, attempt/session identities collapse, or execution is presented
as verification/decision/application/satisfaction.
