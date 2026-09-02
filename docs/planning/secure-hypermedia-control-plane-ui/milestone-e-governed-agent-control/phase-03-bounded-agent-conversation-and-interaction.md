---
id: plan.jido_code_hypermedia_ui_milestone_e_phase_03
parent_plan: plan.jido_code_hypermedia_ui_milestone_e
status: proposed
intent: feature
---

# Milestone E Phase 3 - Bounded Agent Conversation And Interaction

This phase turns authorized `InteractionSession` and message records into a
chat-like attempt panel and activates only the existing bounded `answer` and
`steer` semantics. It does not create unrestricted provider chat, expose raw
transcripts, or confuse message recording with runtime consumption.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Deliver exact, secure, accessible human-agent interaction inside each attempt workspace.

  This phase closes HUI-E3 when a developer can select the correct authorized
  interaction, understand its durable messages and current clarification, and
  answer or steer through receipt-backed gateways across parallel attempts.

  - [ ] 3.1 Section - Implement the authorized conversation projection and identity binding.

    This section resolves each conversation from canonical attempt and
    `InteractionSession` relationships and returns only bounded fields the
    current principal may observe.

    - [ ] 3.1.1 Task {#huie-p03-projection} [repo: jido_code] [after: {#huie-p02-phase-receipt}] - Implement reviewed interaction-session, message, and clarification projections.

      This task preserves project, task, attempt, logical agent/profile,
      `InteractionSession`, provider thread, browser session, runtime, and
      process as distinct identities and never guesses their cardinality.

      - [ ] 3.1.1.1 Subtask - Query authorized sessions related to the exact attempt with purpose, state, safe participant/audience labels, current revision, provenance, freshness, completeness, and opaque references; require explicit selection when more than one session is visible.
      - [ ] 3.1.1.2 Subtask - Query server-paginated messages with sender class/ref, intent, sequence, recorded time, classification/redaction, reply relation, provenance, resulting command/receipt, and explicit gap/duplicate/late/truncated/stale/unavailable state.
      - [ ] 3.1.1.3 Subtask - Project the current clarification question, reason, audience, reply target, expiry, attempt/session/fence/profile bindings, answerability, and any observed continuation/outcome without inferring provider delivery or consumption.
      - [ ] 3.1.1.4 Subtask - Enforce page/count/time/byte limits and route/query/field/message/session authorization before labels, aggregates, existence, pagination cursors, or related-resource links are returned.

    - [ ] 3.1.2 Task {#huie-p03-state-model} [repo: jido_code] [after: {#huie-p03-projection}] - Define the closed conversation and delivery-state vocabulary.

      This task prevents browser transport or presentation state from becoming
      a semantic claim about the graph, command pipeline, provider, or agent.

      - [ ] 3.1.2.1 Subtask - Distinguish browser-local draft/submitting from durable message recorded, command admitted/rejected/conflicted/uncertain, continuation observed, and terminal agent outcome states.
      - [ ] 3.1.2.2 Subtask - Forbid `typing`, `read`, `seen`, live-provider-session, or consumed labels unless a future accepted durable observation contract admits them.
      - [ ] 3.1.2.3 Subtask - Map answer to the current bounded clarification through accepted `steer` semantics and expose steer only when the current Product/Factory gateway, lifecycle, profile, lease, and fence admit it.
      - [ ] 3.1.2.4 Subtask - Attribute continuation tokens and cost as reported, estimated, or unavailable for the exact attempt/profile/provider; never assign invented token cost to message text or report missing usage as zero.

  - [ ] 3.2 Section - Build the bounded conversation panel and accessible transcript.

    This section implements the HEEx/ShadcnUI interaction surface as an
    application-owned composite with useful native HTML and bounded Datastar
    enhancement.

    - [ ] 3.2.1 Task {#huie-p03-transcript-ui} [repo: jido_code] [after: {#huie-p03-state-model}] - Render session context, transcript, clarification, and related causal records.

      This task makes the current project, attempt, agent, session, audience,
      wait state, and freshness continuously understandable without turning the
      transcript into the evidence or approval record.

      - [ ] 3.2.1.1 Subtask - Render a stable session header/selector, semantic message list, safe sender/intent/time/status labels, reply context, redaction/gap/truncation states, load-earlier navigation, deep links, empty/error/unavailable states, and explicit current clarification card.
      - [ ] 3.2.1.2 Subtask - Render message content as escaped plain text with preserved line breaks and no executable HTML/Markdown, raw prompt/provider transcript, private reasoning, unrestricted tool output, credentials, graph IRI, sandbox path, or process/provider-session identifier.
      - [ ] 3.2.1.3 Subtask - Link authorized message, command receipt, runtime observation, timeline, effect, artifact, evidence, cost, and decision records while retaining their separate types and independent authorization.
      - [ ] 3.2.1.4 Subtask - Provide narrow/desktop layouts, logical document order, keyboard navigation, visible focus, screen-reader names/summaries, RTL, zoom/reflow, touch targets, forced colors, reduced motion, print behavior, and non-color status distinctions.

    - [ ] 3.2.2 Task {#huie-p03-live-ui} [repo: jido_code] [after: {#huie-p03-transcript-ui}] - Add bounded conversation pagination and live convergence.

      This task uses the page's one authorized multiplexed stream only as a
      revision hint and preserves human reading and composing state.

      - [ ] 3.2.2.1 Subtask - Register session header, transcript page, clarification, composer availability, and receipt-status fragment roots with closed signals and current authorized snapshot/revision bindings.
      - [ ] 3.2.2.2 Subtask - Re-query after coalesced hints and handle duplicate/reordered/dropped updates, gaps, reconnect, deploy/process restart, session expiry, and field/resource/role/scope revocation without leaking concealed messages.
      - [ ] 3.2.2.3 Subtask - Preserve focus, selected session, reading position, and safe same-scope draft; use a bounded new-updates indicator instead of auto-scroll, focus theft, token streaming, or message-by-message live announcements.
      - [ ] 3.2.2.4 Subtask - Keep ordinary GET pagination, links, forms, validation errors, previews, receipts, and recovery useful with JavaScript disabled or enhancement unavailable.

  - [ ] 3.3 Section - Implement the bounded answer and steer composer, admission, and recovery path.

    This section gives the chat-like panel two explicit server-derived modes and
    routes both through the same governed command and receipt boundaries that
    later Milestone E controls extend.

    - [ ] 3.3.1 Task {#huie-p03-composer} [repo: jido_code] [after: {#huie-p03-live-ui}] - Implement exact answer/steer forms and canonical previews.

      This task accepts bounded untrusted guidance but cannot widen authority,
      choose a provider/runtime, or manufacture a generic message operation.

      - [ ] 3.3.1.1 Subtask - Render separate `Answer current clarification` and `Steer attempt` modes only when admitted, with specific unavailable reasons, current session/audience/reply context, exact consequence, budget posture, byte count, and unique stable DOM/form identities.
      - [ ] 3.3.1.2 Subtask - Accept at most 4,096 bytes of normalized plain text with no attachments; repeat server-side empty/size/encoding/secret/classification checks and never trust browser sender, audience, session, sequence, capability, profile, or status fields.
      - [ ] 3.3.1.3 Subtask - Generate a canonical preview/action digest after reauthorizing and re-querying current actor, assurance, project, attempt, session, clarification, audience, reply target, state, revisions, sequence, lease/fence, profile, policy, expiry, and expected token/cost posture.
      - [ ] 3.3.1.4 Subtask - Preserve the draft only across safe same-identity/scope step-up or recoverable enhancement failure and clear it on identity, project, attempt, session, audience, authorization, or terminal-state change; never place content in URLs, logs, telemetry, or shared cross-tab storage.

    - [ ] 3.3.2 Task {#huie-p03-admission} [repo: jido_code] [after: {#huie-p03-composer}] - Admit answer/steer through typed Product/Factory gateways and reconcile durable outcomes.

      This task establishes the shared interaction-command kernel that Phase 4
      extends; web code never records graph messages directly or sends runtime
      process signals.

      - [ ] 3.3.2.1 Subtask - Add explicit non-GET answer and steer handlers with CSRF/Origin/Fetch Metadata, current authorization/assurance, closed params, rate limits, idempotency, action digest, expected revisions/sequence/fence/lease/profile, reason, and correlation bindings.
      - [ ] 3.3.2.2 Subtask - Invoke only accepted public gateways so interaction-message recording, semantic command admission, runtime continuation, and observations retain their separate commands, provenance, receipts, and failure states.
      - [ ] 3.3.2.3 Subtask - Render admitted/rejected/conflicted/expired/revoked/uncertain outcomes from durable receipts and fresh projections; on timeout or disconnect look up the original idempotency-bound receipt before permitting retry.
      - [ ] 3.3.2.4 Subtask - Resolve concurrent answer/answer, answer/steer, answer/cancel, stale-tab, replay, and duplicate races through compare-and-set semantics so at most one incompatible transition commits and every loser receives current safe state without protected winner details.

  - [ ] 3.4 Section - Phase 3 Integration Tests.

    This final section proves the conversation surface routes bounded human
    input to the correct agent interaction and remains scoped, causal,
    recoverable, accessible, and truthful under parallel operation.

    - [ ] 3.4.1 Task {#huie-p03-integration} [repo: jido_code] [after: {#huie-p03-admission}] - Execute the HUI-E3 conversation, delivery, security, and usability matrix.

      This task uses real graph projections and Product/Factory/runtime gateways
      with multiple projects, attempts, agents, interaction sessions, humans,
      tabs, and injected transport/runtime faults.

      - [ ] 3.4.1.1 Subtask - Exercise zero/one/many related sessions, explicit selection, message pages/replies/sequences/gaps/redaction/truncation, current/expired/superseded clarifications, admitted/unavailable steering, and reported/estimated/unavailable continuation cost.
      - [ ] 3.4.1.2 Subtask - Run clarification-to-answer and admissible steer through real gateways to fresh bounded continuation and observed outcome; prove running-state/profile/turn-exhaustion rejection and no false provider-session/read/typing/consumption claim.
      - [ ] 3.4.1.3 Subtask - Exercise cross-project/session/audience IDOR, hostile text/HTML/Markdown/expression/secret content, empty/oversized/malformed input, CSRF/Origin, stale digest/revision/fence/lease/profile, replay/idempotency, races, revocation, receipt concealment, and transport uncertainty.
      - [ ] 3.4.1.4 Subtask - Exercise no-JS and Datastar modes, pagination/live hints/reconnect/restart, draft/focus/scroll preservation and clearing, narrow layout, keyboard, supported screen reader, zoom, touch, RTL, reduced motion, forced colors, load/backpressure, `mix precommit`, and clean-checkout CI.

    - [ ] 3.4.2 Task {#huie-p03-phase-receipt} [repo: jido_code] [after: {#huie-p03-integration}] - Publish and pin the Phase 3 receipt.

      This task records HUI-E3 evidence in
      `docs/architecture/hypermedia-ui-milestone-e-phase-03-receipt.md`.

      - [ ] 3.4.2.1 Subtask - Keep HUI-E3 merge-pending on attempt/session/audience misrouting, unauthorized disclosure, raw transcript/reasoning exposure, unbounded content, unsupported chat semantics, direct graph/runtime bypass, false delivery state, duplicate effect, non-convergent uncertainty, lost draft/focus, or inaccessible conversation.
      - [ ] 3.4.2.2 Subtask - Record projection/session/message/form/gateway/receipt/runtime/browser/security/accessibility/load/fault evidence, failures, limitations, and every reopening condition.
      - [ ] 3.4.2.3 Subtask - Pin the full merged SHA/date and check the phase, Phase 3 Integration Tests section, receipt task, and pinning subtask before authorizing Phase 4.
