---
id: plan.jido_code_repository_wikis_phase_04
parent_plan: plan.jido_code_repository_wikis
status: approved
intent: feature
---

# Repository Wikis Phase 4 - Maintainer Automation, Budgeting, And Accounting

This phase adds optional per-repository maintenance, automatic deterministic
updates, and complete token/cost governance. It implements and adversarially
tests model-backed reservation and accounting boundaries while keeping every
hosted synthesis provider and price profile disabled for V1.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Automate bounded wiki maintenance and prove complete cost governance.

  This phase proves RW4 by coordinating at most one current maintainer owner
  per repository, coalescing update work, enforcing opt-out, and recording
  terminal zero-token or measured usage for every admitted attempt.

  - [ ] 4.1 Section - Define generation profiles, price catalogs, budgets, and reservations.

    This section ensures the factory can answer whether a generation attempt
    is allowed and funded before any token-bearing effect can occur.

    - [ ] 4.1.1 Task {#rwi-p04-generation-profiles} [repo: jido_code] [after: {#rwi-p03-phase-receipt}] - Implement the closed generation and price profile catalogs.

      This task separates deterministic compiler identity from any future
      provider/model synthesis identity and price schedule.

      - [ ] 4.1.1.1 Subtask - Register manual and automatic deterministic profiles with compiler, renderer, resolver, limits, zero-token behavior, eligibility, and immutable component digests.
      - [ ] 4.1.1.2 Subtask - Define disabled synthesis profile shapes with exact provider, model, region, tokenizer/accounting basis, prompt/template digest, tool policy, retention policy, and maximum input/output/cache/reasoning tokens.
      - [ ] 4.1.1.3 Subtask - Define immutable price profiles with currency, effective interval, input/output/cached/reasoning unit prices, rounding, source provenance, and supersession.
      - [ ] 4.1.1.4 Subtask - Make profile resolution closed and fail-safe; graph values cannot select modules, endpoints, credentials, prompts, prices, tokenizers, or fallback providers.
      - [ ] 4.1.1.5 Subtask - Publish V1 with no enabled hosted synthesis or provider/model price profile and prove unavailable profiles cannot be selected indirectly.

    - [ ] 4.1.2 Task {#rwi-p04-budget-reservation} [repo: jido_code] [after: {#rwi-p04-generation-profiles}] - Implement repository-scoped budget and reservation admission.

      This task reserves worst-case liability atomically before a token-bearing
      attempt and prevents concurrent sessions from overspending one budget.

      - [ ] 4.1.2.1 Subtask - Define repository, tenant, actor, profile, period, per-attempt, token, and currency budget limits with exact revision and effective interval.
      - [ ] 4.1.2.2 Subtask - Compute worst-case token and monetary liability from the exact generation and price profiles using deterministic checked arithmetic and explicit rounding.
      - [ ] 4.1.2.3 Subtask - Atomically reserve against committed usage plus live reservations using revision/fence preconditions, idempotency, expiration, and stable duplicate/insufficient/stale outcomes.
      - [ ] 4.1.2.4 Subtask - Bind reservation to actor, tenant, repository, session, source revision, edition attempt, profile, provider/model, price revision, prompt digest, and invocation-before-effect identity.
      - [ ] 4.1.2.5 Subtask - Reject missing, disabled, expired, mismatched, cross-scope, underfunded, or already-consumed reservations before any model invocation.

    - [ ] 4.1.3 Task {#rwi-p04-usage-accounting} [repo: jido_code] [after: {#rwi-p04-budget-reservation}] - Implement durable token usage and cost accounting.

      This task makes every admitted attempt terminally attributable, including
      deterministic work, failures, cancellation, and missing provider usage.

      - [ ] 4.1.3.1 Subtask - Record deterministic attempts with exact zero input, output, cached, and reasoning tokens; zero model cost; local work metrics; trigger; source; edition; and profile identity.
      - [ ] 4.1.3.2 Subtask - Define normalized measured usage for input, output, cached input, reasoning, total, provider request, model, region, currency, price revision, and raw evidence digest.
      - [ ] 4.1.3.3 Subtask - Calculate attributable cost with checked decimal arithmetic, price effective-time rules, explicit rounding, and separate reserved, measured, charged, refunded, and unknown values.
      - [ ] 4.1.3.4 Subtask - Commit one terminal accounting state for success, rejected-before-effect, failed-before-effect, failed-after-effect, cancelled, timed-out, usage-pending, or usage-unknown.
      - [ ] 4.1.3.5 Subtask - Reconcile reservation release/consumption idempotently and prevent retries, duplicate callbacks, late results, or process restarts from double charging or erasing liability.

  - [ ] 4.2 Section - Coordinate one optional maintainer owner per enrolled repository.

    This section introduces a disposable runtime owner without making process
    identity, mailbox state, queue state, or timers durable truth.

    - [ ] 4.2.1 Task {#rwi-p04-maintainer-profile} [repo: jido_code] [after: {#rwi-p04-usage-accounting}] - Implement closed maintainer profiles and eligibility.

      This task controls when a repository may run a maintainer and which
      deterministic actions that owner may coordinate.

      - [ ] 4.2.1.1 Subtask - Define maintainer profile identity, supported generation modes, trigger classes, debounce, coalescing, concurrency, limits, retry, backoff, lease, heartbeat, cancellation, and recovery rules.
      - [ ] 4.2.1.2 Subtask - Require current automatic enrollment, exact repository scope, eligible deterministic generation profile, current policy, worker readiness, and no disable fence before ownership admission.
      - [ ] 4.2.1.3 Subtask - Keep manual repositories process-free except during an admitted request and keep off repositories process-free with no queued work.
      - [ ] 4.2.1.4 Subtask - Resolve every executable behavior from closed application registries and immutable profile digests rather than graph-selected modules or repository configuration.

    - [ ] 4.2.2 Task {#rwi-p04-maintainer-coordinator} [repo: jido_code] [after: {#rwi-p04-maintainer-profile}] - Implement the per-repository maintainer coordinator and leases.

      This task serializes ownership and current-source transitions while
      allowing the factory to run many different repositories concurrently.

      - [ ] 4.2.2.1 Subtask - Start maintainers under a named DynamicSupervisor/Registry tuple keyed by canonical tenant and repository identity.
      - [ ] 4.2.2.2 Subtask - Acquire a graph-backed lease with generation and fence before work; renew under current enrollment/profile revision and reject stale owners after takeover.
      - [ ] 4.2.2.3 Subtask - Enforce at most one current owner and one current-source transition per repository while allowing bounded previews and unrelated repositories in parallel.
      - [ ] 4.2.2.4 Subtask - Treat mailbox, local debounce state, timers, cursors, caches, and task processes as disposable projections rebuilt from graph state.
      - [ ] 4.2.2.5 Subtask - Expose bounded status, health, lease age, queued/coalesced trigger count, active attempt, last result, and disabled reason through reviewed queries.

  - [ ] 4.3 Section - Schedule automatic deterministic updates and coalesce parallel triggers.

    This section turns accepted repository changes into bounded work without
    rebuilding once per coding session or accepting a stale trigger.

    - [ ] 4.3.1 Task {#rwi-p04-scheduling} [repo: jido_code] [after: {#rwi-p04-maintainer-coordinator}] - Implement deterministic trigger admission, debounce, and coalescing.

      This task combines many source events into the minimum safe sequence of
      source-fenced wiki updates.

      - [ ] 4.3.1.1 Subtask - Accept only controller-authenticated repository-change, accepted-document, dependency-metadata, policy, compiler, manual, recovery, and scheduled-refresh triggers.
      - [ ] 4.3.1.2 Subtask - Normalize triggers to canonical repository, source, policy, profile, classification, priority, and idempotency identities before enqueueing.
      - [ ] 4.3.1.3 Subtask - Debounce bursts and coalesce superseded source revisions while retaining causal provenance for every contributing event.
      - [ ] 4.3.1.4 Subtask - Maintain bounded per-repository pending work with fair fleet-wide concurrency and back-pressure; never use an unbounded process mailbox as the queue of record.
      - [ ] 4.3.1.5 Subtask - Reclassify against current graph/source state immediately before admission and skip no-op, disabled, already-current, stale, or unsupported work with terminal evidence.

    - [ ] 4.3.2 Task {#rwi-p04-automatic-updates} [repo: jido_code] [after: {#rwi-p04-scheduling}] - Execute automatic deterministic updates through the edition protocol.

      This task reuses the same compiler, lint, review policy, accounting, and
      activation gates as manual deterministic generation.

      - [ ] 4.3.2.1 Subtask - Bind each attempt to current enrollment, lease generation, source fence, classifier result, generation profile, zero-token reservation posture, and invocation-before-effect identity.
      - [ ] 4.3.2.2 Subtask - Compile, lint, render, record zero-token usage, and activate only under the existing exact current-source compare-and-swap transition.
      - [ ] 4.3.2.3 Subtask - Retry only profile-approved transient outcomes with bounded backoff and stable idempotency; never retry policy, source, qualification, or authorization failures blindly.
      - [ ] 4.3.2.4 Subtask - Mark current editions stale and surface bounded failure status when automatic rebuilding cannot complete, without hiding the last accepted edition.
      - [ ] 4.3.2.5 Subtask - Rescan current graph state after crash or ownership change and resume or supersede work without trusting the predecessor's queue or cursor.

  - [ ] 4.4 Section - Build and disable the future synthesis boundary.

    This section validates that a future model-backed compiler cannot bypass
    opt-in, reservation, accounting, source fencing, or qualification, while
    deliberately enabling no provider in V1.

    - [ ] 4.4.1 Task {#rwi-p04-synthesis-boundary} [repo: jido_code] [after: {#rwi-p04-automatic-updates}] - Implement the provider-neutral synthesis invocation boundary in disabled mode.

      This task defines the exact invocation contract and denies it unless all
      profile, budget, reservation, and deployment requirements are present.

      - [ ] 4.4.1.1 Subtask - Define a controller-owned request containing bounded source facts, retrieval context, prompt/template digest, output schema, token limits, reservation identity, source fence, and redaction policy.
      - [ ] 4.4.1.2 Subtask - Require exact repository synthesis opt-in distinct from wiki enrollment, an enabled closed provider/model profile, enabled current price profile, worker readiness, and successful reservation.
      - [ ] 4.4.1.3 Subtask - Commit invocation-before-effect before adapter dispatch and reject any call lacking a current reservation or using caller-selected model, endpoint, credential, prompt, tool, or limit.
      - [ ] 4.4.1.4 Subtask - Normalize bounded structured output and provider usage as observations; require deterministic lint, source/provenance checks, human/approved review policy, and current-source activation fencing.
      - [ ] 4.4.1.5 Subtask - Keep the adapter catalog empty or disabled in production configuration and prove every synthesis request returns a stable unavailable outcome before network or token effect.

    - [ ] 4.4.2 Task {#rwi-p04-accounting-reconciliation} [repo: jido_code] [after: {#rwi-p04-synthesis-boundary}] - Implement usage recovery and accounting reconciliation.

      This task prevents a crash or incomplete provider response from making
      consumed tokens disappear from repository and fleet cost views.

      - [ ] 4.4.2.1 Subtask - Reconstruct attempts with committed invocation but no terminal usage from graph state and immutable provider evidence references.
      - [ ] 4.4.2.2 Subtask - Retry supported usage retrieval under bounded policy or close as `usage_unknown` with reserved liability retained according to finance policy.
      - [ ] 4.4.2.3 Subtask - Reconcile late usage only against the exact attempt, reservation, provider request, model, price revision, and current accounting fence.
      - [ ] 4.4.2.4 Subtask - Emit repository, tenant, actor, profile, trigger, edition, period, token-class, and currency rollups as disposable reviewed projections.
      - [ ] 4.4.2.5 Subtask - Alert on expired live reservations, invocation-without-terminal-usage, cost arithmetic errors, profile/price drift, and impossible zero/nonzero token combinations.

  - [ ] 4.5 Section - Make opt-out, cancellation, and recovery authoritative.

    This section proves an owner can stop future cost and maintenance promptly
    without losing audit or accounting evidence.

    - [ ] 4.5.1 Task {#rwi-p04-opt-out} [repo: jido_code] [after: {#rwi-p04-accounting-reconciliation}] - Implement disable, cancellation, reservation release, and teardown.

      This task turns an accepted Off transition into an immediate fence
      against queued, running, retrying, preview, and late-result work.

      - [ ] 4.5.1.1 Subtask - Commit enrollment disable and a new cancellation fence before signaling maintainers, compilation tasks, sandbox jobs, metadata refreshes, or future provider invocations.
      - [ ] 4.5.1.2 Subtask - Stop admission, discard or terminally record pending triggers, cancel active effects, revoke leases, and reject every result from an older enrollment or lease generation.
      - [ ] 4.5.1.3 Subtask - Release unconsumed reservations, retain consumed/unknown liability, close deterministic attempts with zero-token evidence, and preserve required usage/audit records.
      - [ ] 4.5.1.4 Subtask - Apply configured retained-read and artifact-retention policy independently from generation disable and remove product navigation when reads are not permitted.
      - [ ] 4.5.1.5 Subtask - Prove re-enrollment creates a new generation and cannot revive stale leases, previews, reservations, attempts, callbacks, or source fences.

    - [ ] 4.5.2 Task {#rwi-p04-maintainer-recovery} [repo: jido_code] [after: {#rwi-p04-opt-out}] - Implement maintainer restart, takeover, and degraded-mode recovery.

      This task recovers automatic maintenance from durable state while
      preserving one-owner and one-current-source invariants.

      - [ ] 4.5.2.1 Subtask - Scan eligible automatic enrollments on startup, validate profiles and readiness, and acquire only expired or absent leases.
      - [ ] 4.5.2.2 Subtask - Reconstruct pending necessity from current source, current edition, staleness, terminal attempts, and trigger evidence rather than a persisted process queue.
      - [ ] 4.5.2.3 Subtask - Recover incomplete editions, reservations, usage-pending attempts, metadata refreshes, and activation candidates under their exact original fences.
      - [ ] 4.5.2.4 Subtask - Enter explicit degraded status when store, harness, artifact, profile, or accounting dependencies are unavailable and resume only after current revalidation.

  - [ ] 4.6 Section - Phase 4 Integration Tests.

    This final section proves maintenance is optional, concurrency-safe,
    budgeted, fully accountable, recoverable, and synthesis-disabled in V1.

    - [ ] 4.6.1 Task {#rwi-p04-integration} [repo: jido_code] [after: {#rwi-p04-maintainer-recovery}] - Execute the RW4 maintainer, budget, accounting, and opt-out matrix.

      This task closes RW4 only when every admitted attempt reaches terminal
      usage evidence and disabling a repository prevents every later effect.

      - [ ] 4.6.1.1 Subtask - Race maintainer starts, lease renewals, takeovers, same-repository sessions, different repositories, trigger bursts, source supersession, retries, crashes, and late results.
      - [ ] 4.6.1.2 Subtask - Exercise budget boundaries, concurrent reservations, checked arithmetic, price intervals, expiration, duplicate callbacks, partial usage, unknown usage, refund/release, and cost rollups.
      - [ ] 4.6.1.3 Subtask - Prove deterministic manual and automatic attempts always record zero model tokens/cost while still recording attributable local work and terminal status.
      - [ ] 4.6.1.4 Subtask - Exercise synthesis requests through fake adapters for missing opt-in, missing/disabled profile, no price, insufficient budget, stale reservation, provider failure, malformed output, usage drift, and late response.
      - [ ] 4.6.1.5 Subtask - Prove production has no enabled hosted profile, no fake call reaches a real network, and all unavailable cases fail before token-bearing effect.
      - [ ] 4.6.1.6 Subtask - Exercise disable during queued, compiling, sandbox, metadata, reserved, invoked, usage-pending, preview, activation, and recovery states; prove old-generation results are rejected.
      - [ ] 4.6.1.7 Subtask - Rerun RW1-RW3 and applicable harness/security suites, then run architecture checks, Dialyzer, `mix precommit`, and clean-checkout CI.

    - [ ] 4.6.2 Task {#rwi-p04-phase-receipt} [repo: jido_code] [after: {#rwi-p04-integration}] - Publish and pin the Phase 4 receipt.

      This task records RW4 evidence in
      `docs/architecture/repository-wiki-phase-04-receipt.md`.

      - [ ] 4.6.2.1 Subtask - Record generation, price, budget, reservation, usage, cost, maintainer, scheduler, synthesis-boundary, cancellation, recovery, and fixture revisions and digests.
      - [ ] 4.6.2.2 Subtask - Keep RW4 open if an unconfigured repository starts maintenance, concurrent attempts overspend, usage can disappear, synthesis reaches an effect without every gate, or disable accepts an old-generation result.
      - [ ] 4.6.2.3 Subtask - Preserve every gate reopening condition and attach concurrency, zero-token, reservation, accounting, disabled-synthesis, opt-out, recovery, precommit, Dialyzer, and clean-checkout evidence.
      - [ ] 4.6.2.4 Subtask - Pin the merged candidate commit and merge date, then tick the phase, final Phase 4 Integration Tests section, receipt task, and pinning checkboxes before authorizing Phase 5.
