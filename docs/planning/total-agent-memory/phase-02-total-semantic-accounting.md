---
id: plan.jido_code_total_agent_memory_phase_02
parent_plan: plan.jido_code_total_agent_memory
status: planned
intent: feature
---

# Memory Phase 2 - Total Semantic Accounting

This phase replaces unbounded run accumulation with predecessor-chained event
segments, multidimensional content accounting, and verifiable closure for every
new execution attempt.

Back to plan: [README](./README.md)

- [ ] 2 Phase - Account for every expected execution event without claiming unauthorized recall.

  This phase establishes MG2 by making sequence, causality, capture state,
  completeness, and omission mechanically provable.

  - [x] 2.1 Section - Implement the event-head and bounded-segment protocol.

    This section gives every new execution event one conflict-safe position in
    a bounded immutable sequence.

    - [x] 2.1.1 Task {#tam-p02-event-segments} [repo: jido_code] [after: {#tam-p01-phase-receipt}] - Implement predecessor-chained event segments.

      This task makes semantic attempt order independent of wall clocks and
      caller-selected sequence values.

      - [x] 2.1.1.1 Subtask - Revise `RecordExecutionAttempt` `2.0.0` to create the capture manifest, first segment, and sequence-zero event head atomically with run/control transitions.
      - [x] 2.1.1.2 Subtask - Require every event command to consume the exact active head and append one deterministic contiguous successor; concurrent uses of one predecessor conflict.
      - [x] 2.1.1.3 Subtask - Define segment roots, inclusive ranges, predecessor roots, ordered event-set digests, content-root digests, and carried open-effect sets.
      - [x] 2.1.1.4 Subtask - Implement `CloseEventSegment` with independent exact typed-set, sequence-gap, start/outcome, and unlisted-resource validation.
      - [x] 2.1.1.5 Subtask - Atomically close one segment, append its root to the attempt, and optionally open the next segment with explicit carried effects.
      - [x] 2.1.1.6 Subtask - Stop before any pinned limit and create a governed continuation attempt rather than an unfinalizable segment or root graph.

  - [x] 2.2 Section - Implement capture manifests and content-state accounting.

    This section records what content was expected, what representation exists,
    where it resides, and why anything is absent.

    - [x] 2.2.1 Task {#tam-p02-capture-state} [repo: jido_code] [after: {#tam-p02-event-segments}] - Implement episode and per-body capture contracts.

      This task makes total accounting complete even when exact content is
      forbidden or unavailable.

      - [x] 2.2.1.1 Subtask - Add `EpisodeCaptureManifest` with profile, expected event/body classes, policy, purpose, limits, and completeness roots.
      - [x] 2.2.1.2 Subtask - Add immutable `ContentCapture` shells owned by one event role and bound to opaque content identity, classification, purpose, policy, and initial state dimensions.
      - [x] 2.2.1.3 Subtask - Record captured, omitted-by-policy, unavailable-at-source, and capture-failed outcomes for every expected body.
      - [x] 2.2.1.4 Subtask - Record exact, deterministically redacted, normalized, commitment-only, or absent representations without treating a digest as replayable content.
      - [x] 2.2.1.5 Subtask - Bind redaction receipts, limitations, allowed uses, retention class, reconstruction status, and external-provider availability.
      - [x] 2.2.1.6 Subtask - Make missing capture entries a closure error rather than silently treating absence as omission.

  - [x] 2.3 Section - Move execution events onto immutable successors.

    This section applies the shared event sequence to model calls, tools,
    messages, transitions, artifacts, and lifecycle observations.

    - [x] 2.3.1 Task {#tam-p02-execution-events} [repo: jido_code] [after: {#tam-p02-capture-state}] - Implement event-type-specific `2.0.0` execution commands.

      This task removes cross-segment subject mutation while preserving current
      authorization and fencing.

      - [x] 2.3.1.1 Subtask - Represent model and tool starts and outcomes as separate immutable resources linked by exact attempt, lease, fence, context, tool/model revision, and event predecessor.
      - [x] 2.3.1.2 Subtask - Rename new tool starts to `RecordToolInvocationStart` while retaining legacy command resolution for historical reads only.
      - [x] 2.3.1.3 Subtask - Put attempt transitions, normalized proposals, sandbox events, artifacts, messages, cancellation, retry, and terminal observations onto the same attempt sequence.
      - [x] 2.3.1.4 Subtask - Keep provider observations in their source ordering and permit later attributed associations without fabricating task or attempt identity.
      - [x] 2.3.1.5 Subtask - Keep verification, decisions, publication, deployment, incidents, and delayed review in their accepted families while linking them to immutable attempts.
      - [x] 2.3.1.6 Subtask - Preserve capability, approval, effect-journal, invocation-before-dispatch, and stale-fence invariants from the harness.

  - [x] 2.4 Section - Extend finalization and recovery across segments.

    This section proves a run is complete only from bounded closed roots and
    reconstructs safe continuation after failure.

    - [x] 2.4.1 Task {#tam-p02-segmented-finalization} [repo: jido_code] [after: {#tam-p02-execution-events}] - Implement segmented closure, projection, and recovery.

      This task prevents missing, duplicated, unresolved, or unsegmented events
      from passing finalization.

      - [x] 2.4.1.1 Subtask - Revise `FinalizeExecutionRun` to consume ordered segment roots, prove contiguous ranges from zero through the terminal sequence, and verify immutable root/content digests.
      - [x] 2.4.1.2 Subtask - Reject events outside a closed segment and require all open effects to be closed, cancelled, or explicitly ambiguous.
      - [x] 2.4.1.3 Subtask - Preserve explicit incomplete finalization for unavailable providers, failed capture, cancellation ambiguity, and bounded-limit termination.
      - [x] 2.4.1.4 Subtask - Recover active heads, segment state, open effects, idempotency, and continuation authority entirely from graph state.
      - [x] 2.4.1.5 Subtask - Add dual legacy/segmented projections with explicit protocol and completeness fields.
      - [x] 2.4.1.6 Subtask - Reject late events after segment or run closure and prevent restore from reopening closed history.

  - [ ] 2.5 Section - Phase 2 Integration Tests.

    This final section proves total semantic accounting under concurrency,
    failure, restart, and protocol bounds.

    - [ ] 2.5.1 Task {#tam-p02-integration} [repo: jido_code] [after: {#tam-p02-segmented-finalization}] - Execute the segmented-accounting integration matrix.

      This task exercises the real command pipeline and TripleStore across
      complete and incomplete attempts.

      - [ ] 2.5.1.1 Subtask - Record attempts spanning one and multiple segments with model, tool, message, artifact, cancellation, and terminal events.
      - [ ] 2.5.1.2 Subtask - Exercise concurrent head consumption, replay, sequence gaps, duplicate outcomes, unlisted resources, carried effects, and closure-limit edges.
      - [ ] 2.5.1.3 Subtask - Prove 100% content-state accounting for expected classes and rejection of unsegmented resources.
      - [ ] 2.5.1.4 Subtask - Crash and restart before event commit, after start commit, during segment closure, and before run finalization.
      - [ ] 2.5.1.5 Subtask - Verify legacy closed runs remain readable and unchanged while new attempts require `2.0.0`.
      - [ ] 2.5.1.6 Subtask - Rerun prior suites, architecture scans, and `mix precommit`.

    - [ ] 2.5.2 Task {#tam-p02-phase-receipt} [repo: jido_code] [after: {#tam-p02-integration}] - Publish the Phase 2 semantic-accounting receipt.

      This task records the segmented protocol in
      `docs/architecture/memory-phase-02-receipt.md` and binds MG2 to the
      exact merged candidate.

      - [ ] 2.5.2.1 Subtask - Record command, shape, segment-limit, digest, capture-profile, fixture, and compatibility revisions.
      - [ ] 2.5.2.2 Subtask - Attach concurrency, closure, completeness, restart, and legacy-read evidence.
      - [ ] 2.5.2.3 Subtask - Keep MG2 blocked if an expected event can disappear, a closed segment can mutate, or a content body lacks an explicit state.
      - [ ] 2.5.2.4 Subtask - Pin the merged candidate commit before authorizing Phase 3.
