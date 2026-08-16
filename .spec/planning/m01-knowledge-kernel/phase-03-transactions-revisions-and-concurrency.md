---
id: plan.jido_code_m01_phase_03_transactions_revisions_and_concurrency
parent_plan: plan.jido_code_m01_knowledge_kernel
status: planned
intent: feature
---

# M01 JidoCode Phase 3 - Transactions, Revisions, And Concurrency

This phase establishes the serialized write coordinator, the atomic commit
strategy, and monotonic dataset/graph revisions that every later semantic
command, query, lease, and projection depends on.

Back to plan: [M01 README](./README.md)

- [ ] 3 Phase - Make every durable mutation one ordered, atomic, revisioned commit.

  This phase gives all future writers a single transaction boundary with
  optimistic concurrency before any domain semantics attach to it.

  - [ ] 3.1 Section - Implement the serialized knowledge write coordinator.

    This section funnels every persistent mutation through one supervised
    boundary with deadlines, ordering, and typed receipts.

    - [ ] 3.1.1 Task {#m01-jc-p03-write-coordinator} [repo: jido_code] [after: {#m01-jc-p02-integration}] - Implement `JidoCode.Knowledge.Writer`.

      This task provides the only public-internal route to persistent
      mutation, with no bypass through read callbacks or raw adapters.

      - [ ] 3.1.1.1 Subtask {#m01-jc-3-1-1-1} - Define a backend-neutral write batch carrying target graphs, additions, maintenance-policy-approved removals, expected revisions, and opaque operation metadata.
      - [ ] 3.1.1.2 Subtask {#m01-jc-3-1-1-2} - Serialize commits, enforce operation deadlines, and separate caller timeout from the authoritative commit outcome.
      - [ ] 3.1.1.3 Subtask {#m01-jc-3-1-1-3} - Return typed receipts with commit identity, affected graphs, prior/new revisions, counts, and durability result, never raw data.
      - [ ] 3.1.1.4 Subtask {#m01-jc-3-1-1-4} - Reject mutation attempts through `StoreServer` read callbacks, SPARQL query APIs, or arbitrary adapter functions.

  - [ ] 3.2 Section - Implement the atomic commit strategy.

    This section guarantees readers never observe a partially visible
    multi-graph change or a mutation detached from its commit status.

    - [ ] 3.2.1 Task {#m01-jc-p03-atomic-commit} [repo: jido_code] [after: {#m01-jc-p03-write-coordinator}] - Implement one-operation atomic commits.

      This task binds each change to exactly one backend transaction with
      synchronous durability and a defined recovery point.

      - [ ] 3.2.1.1 Subtask {#m01-jc-3-2-1-1} - Compile each commit to exactly one ground update operation across the required named graphs under a fixed quad ceiling with `sync: true`.
      - [ ] 3.2.1.2 Subtask {#m01-jc-3-2-1-2} - Ensure failed validation, precondition, backend, or sync outcomes leave no reader-visible partial state.
      - [ ] 3.2.1.3 Subtask {#m01-jc-3-2-1-3} - Prohibit multiple SPARQL update operations as one accepted transaction.
      - [ ] 3.2.1.4 Subtask {#m01-jc-3-2-1-4} - Define the point after which a lost caller response is recovered by commit identity rather than retried as a new write.
      - [ ] 3.2.1.5 Subtask {#m01-jc-3-2-1-5} - Reject indivisible batches exceeding the quad ceiling with a stable typed error.

  - [ ] 3.3 Section - Implement dataset and graph revision control.

    This section supplies the monotonic concurrency tokens used by every later
    command, query, cache, lease, and projection.

    - [ ] 3.3.1 Task {#m01-jc-p03-graph-revisions} [repo: jido_code] [after: {#m01-jc-p03-atomic-commit}] - Implement monotonic revisions and expected-revision guards.

      This task makes stale writes detectable and concurrent conflicts
      deterministic without wall-clock or process-local ordering.

      - [ ] 3.3.1.1 Subtask {#m01-jc-3-3-1-1} - Maintain a monotonic dataset revision and per-graph revisions updated in the same atomic boundary as graph contents.
      - [ ] 3.3.1.2 Subtask {#m01-jc-3-3-1-2} - Accept exact expected revisions and reject stale writes with a bounded current-revision receipt.
      - [ ] 3.3.1.3 Subtask {#m01-jc-3-3-1-3} - Prevent wall-clock timestamps, process counters, or PubSub sequences from serving as authoritative revisions.
      - [ ] 3.3.1.4 Subtask {#m01-jc-3-3-1-4} - Define overflow, restore, migration, and clone semantics without allowing revision regression within one dataset lineage.
      - [ ] 3.3.1.5 Subtask {#m01-jc-3-3-1-5} - Add race tests proving exactly one winner for conflicting expected-revision writes.

  - [ ] 3.4 Section - Phase 3 Integration Tests.

    This final section proves atomicity, ordering, and recovery under
    concurrency, crashes, and lost responses.

    - [ ] 3.4.1 Task {#m01-jc-p03-integration} [repo: jido_code] [after: {#m01-jc-p03-graph-revisions}] - Execute the transaction and concurrency matrices.

      This task certifies the commit boundary before backup and health
      operations are built on it.

      - [ ] 3.4.1.1 Subtask {#m01-jc-3-4-1-1} - Race conflicting expected-revision writes and prove one winner, deterministic stale receipts, and monotonic revisions.
      - [ ] 3.4.1.2 Subtask {#m01-jc-3-4-1-2} - Terminate callers and the store owner at pre-commit, commit, and post-commit windows; verify all-or-none visibility.
      - [ ] 3.4.1.3 Subtask {#m01-jc-3-4-1-3} - Drop responses before and after commit, recover by commit identity, and prove retries create no duplicate effects.
      - [ ] 3.4.1.4 Subtask {#m01-jc-3-4-1-4} - Rerun Phase 1 guardrails, Phase 2 lifecycle tests, and `mix precommit`.
