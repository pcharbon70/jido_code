---
id: plan.jido_code_hypermedia_ui_milestone_e
status: proposed
intent: feature
milestone: E
program: program.jido_code_secure_hypermedia_control_plane_ui
source:
  - docs/architecture/agent-attempt-workspace-and-command-contract.md
  - docs/architecture/semantic-command-contract.md
  - docs/architecture/governed-command-pipeline.md
  - docs/architecture/change-delivery-and-command-recovery.md
---

# Milestone E Plan - Governed Agent Control

This six-phase plan turns the read-only attempt route into a durable oversight
workspace with a normalized causal timeline and a bounded human-agent
conversation panel, then exposes only already accepted semantic controls
through exact command gateways, canonical previews, step-up, idempotency,
conflict handling, and receipts. Review, evidence, cost, wiki-generation
accounting, and concurrent-human behavior are qualified before the control
plane is accepted.

Back to program: [Secure Hypermedia Control Plane UI](../README.md)

## Goal

Close program Gate HUI5 so authorized developers can understand and safely
influence parallel attempts without conflating an attempt with an
`InteractionSession`, browser session, provider thread, candidate, runtime, or
process—and without inventing unsupported pause, emergency, bulk, or approval
semantics.

## Gate And Phase Mapping

| Phase gate | Required result | Phase |
|---|---|---|
| HUI-E1 | Attempt identity, trust header, lifecycle/outcome rails, summaries, resume state, and live fragments compose from authorized durable projections | [Phase 1](./phase-01-attempt-workspace-identity-and-summary.md) |
| HUI-E2 | A normalized bounded causal timeline correlates plans, interactions, effects, artifacts, evidence, decisions, receipts, costs, and retries without losing distinctions | [Phase 2](./phase-02-causal-timeline-evidence-and-resume.md) |
| HUI-E3 | An authorized bounded conversation panel routes exact answer/steer input to the correct attempt, agent, `InteractionSession`, clarification, and audience with truthful receipt/runtime state | [Phase 3](./phase-03-bounded-agent-conversation-and-interaction.md) |
| HUI-E4 | Accepted steer, answer, cancel, handoff, retry/recovery, and draft-publication commands use explicit handlers, previews, step-up, CAS, idempotency, and receipts | [Phase 4](./phase-04-governed-command-adapter-and-previews.md) |
| HUI-E5 | Review/evidence, budget/cost/wiki-token, parallel-tab, concurrent-human, separation-of-duty, and transport-loss workflows converge correctly | [Phase 5](./phase-05-review-cost-budget-and-concurrent-humans.md) |
| HUI-E6 / HUI5 | Real-gateway, browser, security, accessibility, load, fault, recovery, and role-usability evidence accept the governed workbench | [Phase 6](./phase-06-agent-control-qualification-and-acceptance.md) |

## Phase Order

1. [Phase 1 - Attempt Workspace Identity And Summary](./phase-01-attempt-workspace-identity-and-summary.md)
2. [Phase 2 - Causal Timeline, Evidence, And Resume](./phase-02-causal-timeline-evidence-and-resume.md)
3. [Phase 3 - Bounded Agent Conversation And Interaction](./phase-03-bounded-agent-conversation-and-interaction.md)
4. [Phase 4 - Governed Command Adapter And Previews](./phase-04-governed-command-adapter-and-previews.md)
5. [Phase 5 - Review, Cost, Budget, And Concurrent Humans](./phase-05-review-cost-budget-and-concurrent-humans.md)
6. [Phase 6 - Agent Control Qualification And Acceptance](./phase-06-agent-control-qualification-and-acceptance.md)

Receipts use
`docs/architecture/hypermedia-ui-milestone-e-phase-01-receipt.md` through
`hypermedia-ui-milestone-e-phase-06-receipt.md`. The final receipt closes HUI5
and authorizes knowledge-lens implementation only from the accepted control
baseline.

## Parallelism And Boundaries

Workspace view models and timeline presentation may develop in parallel after
the event vocabulary is pinned. Conversation projection and component work may
develop in disjoint slices only after attempt-to-`InteractionSession` identity,
audience, and query ownership are frozen. Phase 3 establishes the shared
answer/steer interaction-command kernel; each later command family may develop
in a disjoint module/route slice only after that adapter and receipt contract
merges. All controls for the same attempt still resolve through current domain
revision/fence/idempotency semantics; parallel implementation sessions and
parallel humans never receive last-writer-wins authority.

## Completion Definition

Milestone E completes when all accepted controls have gateway parity and no
unsupported control appears; bounded conversation routes messages to the exact
authorized attempt/session/audience and distinguishes recording, admission,
runtime observation, and uncertainty; every action is current-scope/current-
state, step-up and idempotency aware; transport uncertainty resolves through
receipt lookup; reviews cannot approve stale/self-authored work; token/cost
data, including agent continuation and wiki generation, is attributable; and
conflicting humans/tabs receive deterministic safe outcomes.
