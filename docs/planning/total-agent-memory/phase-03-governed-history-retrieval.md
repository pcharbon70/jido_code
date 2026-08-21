---
id: plan.jido_code_total_agent_memory_phase_03
parent_plan: plan.jido_code_total_agent_memory
status: planned
intent: feature
---

# Memory Phase 3 - Governed History Retrieval

This phase adds bounded temporal history queries, authorization-first candidate
generation, disposable indexes, ranked evidence packets, and harness
integration.

Back to plan: [README](./README.md)

- [x] 3 Phase - Retrieve small, time-correct evidence packets without turning history into instructions or authority.

  This phase establishes MG3 by proving every retrieved item is scoped,
  temporally eligible, source-linked, bounded, and non-authoritative.

  - [x] 3.1 Section - Publish bounded historical query products.

    This section exposes semantic questions over attempts and repository
    history without raw SPARQL or transcript search.

    - [x] 3.1.1 Task {#tam-p03-history-queries} [repo: jido_code] [after: {#tam-p02-phase-receipt}] - Extend reviewed query catalog `2.0.0` with history lenses.

      This task provides stable bounded products with exact scope and
      completeness metadata.

      - [x] 3.1.1.1 Subtask - Add `attempt_timeline`, `attempt_capture_completeness`, `task_attempt_lineage`, and exact segment/event-range projections.
      - [x] 3.1.1.2 Subtask - Add `exact_failure_occurrences`, issue/change/test lineage, incident linkage, and `why_does_this_exist` queries.
      - [x] 3.1.1.3 Subtask - Support current and historical effective-time lenses without admitting future review, patch, incident, or association evidence.
      - [x] 3.1.1.4 Subtask - Return query/graph revisions, scope, completeness, truncation, classifications, source time, valid time, and direct evidence references.
      - [x] 3.1.1.5 Subtask - Keep raw retained content behind a separate access permit rather than embedding it in ordinary query results.

  - [x] 3.2 Section - Authorize retrieval before candidate generation.

    This section treats memory retrieval as a governed model-influencing
    effect.

    - [x] 3.2.1 Task {#tam-p03-retrieval-authorization} [repo: jido_code] [after: {#tam-p03-history-queries}] - Implement retrieval requests, activities, and packet commitments.

      This task ensures unauthorized candidates are never inspected by a
      shared index.

      - [x] 3.2.1.1 Subtask - Define a closed request containing actor, repository/tenant, task, purpose, plan phase, effective-time cutoff, provider profile, data ceiling, allowed categories/trust, and item/graph/byte/token/time budgets.
      - [x] 3.2.1.2 Subtask - Require authorization scope and erasure generation to participate in every first-stage index key or ACL-aware candidate lookup.
      - [x] 3.2.1.3 Subtask - Exclude erased, unavailable, invalidated, future-ineligible, unauthorized, and incompatible records before ranking.
      - [x] 3.2.1.4 Subtask - Add `RecordMemoryRetrievalStart` and `RecordMemoryRetrievalOutcome` to the active run segment with selected, omitted, opened, and unavailable item commitments.
      - [x] 3.2.1.5 Subtask - Bind query/ranking/index revisions and one deterministic evidence-packet digest to the context manifest.

  - [x] 3.3 Section - Build hybrid candidate selection and evidence packets.

    This section combines independent retrieval channels while retaining
    explicit ranking features and direct source recovery.

    - [x] 3.3.1 Task {#tam-p03-retrieval-pipeline} [repo: jido_code] [after: {#tam-p03-retrieval-authorization}] - Implement disposable indexes, deterministic ranking, and packet assembly.

      This task gains retrieval performance without introducing a second
      durable memory authority.

      - [x] 3.3.1.1 Subtask - Implement exact identifier, lexical, temporal-graph, failure-signature, recency, and current-state candidate channels as rebuildable projections.
      - [x] 3.3.1.2 Subtask - Define a dense-retrieval port whose production adapter remains disabled until separately evaluated; embeddings inherit source classification and erasure.
      - [x] 3.3.1.3 Subtask - Rank by relevance, symbol/dependency overlap, compatibility, plan phase, trust, evidence, freshness, contradiction, delayed outcome, diversity, and negative-transfer history.
      - [x] 3.3.1.4 Subtask - Make current policy, current source, current tests, and task evidence outrank historical frequency or semantic similarity.
      - [x] 3.3.1.5 Subtask - Assemble bounded items containing selection reason, source IRI, temporal scope, trust, evidence strength, freshness, limitations, contradiction, applicability, and an authorized recovery handle.
      - [x] 3.3.1.6 Subtask - Mark every payload as non-instructional data and prohibit it from adding tools, capabilities, policy, credentials, destinations, approvals, or durable writes.

  - [x] 3.4 Section - Integrate memory retrieval with the harness.

    This section places governed evidence packets into context without changing
    model/tool authority or accepting self-reported utility.

    - [x] 3.4.1 Task {#tam-p03-harness-retrieval} [repo: jido_code] [after: {#tam-p03-retrieval-pipeline}] - Extend context compilation and retrieval observability.

      This task makes memory influence attributable, bounded, and removable.

      - [x] 3.4.1.1 Subtask - Add evidence-packet items to `ContextManifest` with exact digest, source, classification, trust, and reconstruction state.
      - [x] 3.4.1.2 Subtask - Keep packet text structurally separate from system/task instructions and preserve epistemic labels through serialization.
      - [x] 3.4.1.3 Subtask - Record supplied, budget-omitted, opened, followed, contradicted, and ignored status without treating the model's claim of usefulness as evidence.
      - [x] 3.4.1.4 Subtask - Support a strict no-memory mode producing bit-identical base authorization and tool behavior.
      - [x] 3.4.1.5 Subtask - Emit bounded retrieval latency, cost, truncation, source-availability, and index-rebuild metrics without payload values.

  - [x] 3.5 Section - Phase 3 Integration Tests.

    This final section proves authorized, temporal, bounded retrieval and safe
    harness use.

    - [x] 3.5.1 Task {#tam-p03-integration} [repo: jido_code] [after: {#tam-p03-harness-retrieval}] - Execute the governed-retrieval matrix.

      This task validates history queries and evidence packets against
      adversarial multi-scope data.

      - [x] 3.5.1.1 Subtask - Prove exact timeline, failure, lineage, rationale, and capture-completeness results at current and historical cutoffs.
      - [x] 3.5.1.2 Subtask - Prove zero cross-repository, tenant, actor, purpose, provider-profile, or future-data candidate generation.
      - [x] 3.5.1.3 Subtask - Exercise stale, contradicted, erased, held, poisoned, malformed, oversized, and unavailable memories.
      - [x] 3.5.1.4 Subtask - Delete and rebuild every disposable index and prove graph truth and deterministic eligible results remain unchanged.
      - [x] 3.5.1.5 Subtask - Compare no-memory, recent-context, full-eligible, lexical, graph, and hybrid packets under identical budgets.
      - [x] 3.5.1.6 Subtask - Rerun prior suites, architecture scans, and `mix precommit`.

    - [x] 3.5.2 Task {#tam-p03-phase-receipt} [repo: jido_code] [after: {#tam-p03-integration}] - Publish the Phase 3 governed-retrieval receipt.

      This task records query and retrieval evidence in
      `docs/architecture/memory-phase-03-receipt.md` and binds MG3 to the
      merged candidate.

      - [x] 3.5.2.1 Subtask - Record query, ranker, index, packet, profile, corpus, and candidate revisions.
      - [x] 3.5.2.2 Subtask - Attach temporal, scope, budget, poisoning, rebuild, and ablation results.
      - [x] 3.5.2.3 Subtask - Keep MG3 blocked if filtering occurs only after search, a packet can grant authority, or future/ineligible evidence is returned.
      - [x] 3.5.2.4 Subtask - Pin merged candidate `c1185415439bf32d7387e5fe9e94c57bc7a2d42e` before authorizing Phase 4.
