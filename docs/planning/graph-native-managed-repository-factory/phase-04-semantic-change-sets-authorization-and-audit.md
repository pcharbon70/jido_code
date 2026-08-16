---
id: plan.jido_code_graph_factory_phase_04
intent: control_plane_change
source:
  - docs/research/01-graph-native-managed-repository-factory.md
---

# Phase 4 - Semantic Change Sets, Authorization, And Audit

This phase implements the sole domain mutation boundary: versioned semantic
commands that normalize RDF terms, authorize actor and scope, validate shapes
and preconditions, commit assertions plus provenance and audit atomically,
recover idempotent outcomes, and publish disposable post-commit notifications.

Back to plan: [README](./README.md)

- [ ] 4 Phase - Make every graph-visible product mutation semantic, governed, atomic, and recoverable.

  This phase replaces generic CRUD and record codecs with intent-named command
  contracts while preserving the knowledge substrate's one-writer and
  graph-only truth invariants.

  - [x] 4.1 Section - Define semantic command, change-set, and receipt contracts.

    This section gives all future factory operations one bounded, versioned,
    provenance-bearing mutation vocabulary without coupling callers to SPARQL
    or backend details.

    - [x] 4.1.1 Task {#jcf-p04-command-envelope} [repo: jido_code] [after: {#jcf-p03-phase-receipt}] - Implement the common semantic command envelope.

      This task captures authority, identity, causation, consistency, and
      version requirements shared by every domain-specific command.

      - [x] 4.1.1.1 Subtask {#jcf-p04-4-1-1-1} - Require command type/version, command IRI, authenticated actor/delegation, scope, idempotency key, correlation/causation IRIs, ontology/shape version, expected revisions, reason, and issued time.
      - [x] 4.1.1.2 Subtask {#jcf-p04-4-1-1-2} - Define bounded command payloads using RDF terms and canonical resource references rather than persisted entity structs.
      - [x] 4.1.1.3 Subtask {#jcf-p04-4-1-1-3} - Reject unknown versions, missing scope/authority, malformed identities, oversized payloads, unsupported graph families, and untrusted timestamps.
      - [x] 4.1.1.4 Subtask {#jcf-p04-4-1-1-4} - Keep clocks, ID generation, and actor resolution explicit and deterministic in tests.
      - [x] 4.1.1.5 Subtask {#jcf-p04-4-1-1-5} - Define safe inspect/serialization behavior that redacts sensitive metadata and never logs statement bodies by default.

    - [x] 4.1.2 Task {#jcf-p04-change-set} [repo: jido_code] [after: {#jcf-p04-command-envelope}] - Implement the semantic change-set representation.

      This task translates command intent into an atomic graph delta while
      preserving assertions, transitions, supersession, invalidation, and
      provenance as distinct operations.

      - [x] 4.1.2.1 Subtask {#jcf-p04-4-1-2-1} - Define target graph additions, explicit supersession/invalidation relationships, maintenance-only removals, graph metadata changes, and expected revisions.
      - [x] 4.1.2.2 Subtask {#jcf-p04-4-1-2-2} - Include change-set IRI, command IRI, actor, cause, ontology/shape versions, validation context, request fingerprint, and commit metadata.
      - [x] 4.1.2.3 Subtask {#jcf-p04-4-1-2-3} - Ensure ordinary commands cannot delete immutable graph contents, replace a subject wholesale, or write unregistered graphs.
      - [x] 4.1.2.4 Subtask {#jcf-p04-4-1-2-4} - Canonically order and fingerprint logical changes so semantically identical retries compare deterministically.
      - [x] 4.1.2.5 Subtask {#jcf-p04-4-1-2-5} - Separate command construction from authorization, validation, and backend execution.

    - [x] 4.1.3 Task {#jcf-p04-receipt-error-contract} [repo: jido_code] [after: {#jcf-p04-change-set}] - Implement command receipts and failure outcomes.

      This task makes authoritative outcomes recoverable and useful without
      returning raw triples, backend handles, or unbounded diagnostics.

      - [x] 4.1.3.1 Subtask {#jcf-p04-4-1-3-1} - Return committed, already-committed, rejected, conflicted, unauthorized, invalid, unavailable, and unknown-after-timeout outcome classes.
      - [x] 4.1.3.2 Subtask {#jcf-p04-4-1-3-2} - Bind successful receipts to command/change-set IRI, dataset and graph revisions, affected graph IRIs, assertion/supersession counts, actor, and committed time.
      - [x] 4.1.3.3 Subtask {#jcf-p04-4-1-3-3} - Return current revisions, failed precondition or shape references, stable issue codes, and bounded retry guidance where disclosure is authorized.
      - [x] 4.1.3.4 Subtask {#jcf-p04-4-1-3-4} - Conceal resource existence and policy details on unauthorized or cross-scope requests.

    - [x] 4.1.4 Task {#jcf-p04-initial-command-vocabulary} [repo: jido_code] [after: {#jcf-p04-receipt-error-contract}] - Define the initial intent-named command registry.

      This task establishes stable semantic operation names while deferring
      domain-specific payload details to the phases that introduce them.

      - [x] 4.1.4.1 Subtask {#jcf-p04-4-1-4-1} - Register `EnrollRepository`, `RecordObservationBatch`, `AssertDesiredOutcome`, `ProposeGoal`, `AdoptPlan`, and `AcquireExecutionLease` command identities.
      - [x] 4.1.4.2 Subtask {#jcf-p04-4-1-4-2} - Register `RecordExecutionAttempt`, `RecordVerificationEvidence`, `DecideGoalOutcome`, `AdoptKnowledge`, `SupersedeClaim`, and `RetireEnrollment` command identities.
      - [x] 4.1.4.3 Subtask {#jcf-p04-4-1-4-3} - Define command ownership, writer capability, graph families, expected preconditions, and version negotiation without implementing future business rules early.
      - [x] 4.1.4.4 Subtask {#jcf-p04-4-1-4-4} - Reject a generic create/update/delete entity command from the public knowledge boundary.

  - [x] 4.2 Section - Implement the governed atomic write pipeline.

    This section composes normalization, authorization, validation,
    preconditions, provenance, audit, commit, and outcome recovery into one
    deterministic mutation path.

    - [x] 4.2.1 Task {#jcf-p04-command-normalization} [repo: jido_code] [after: {#jcf-p04-initial-command-vocabulary}] - Implement command normalization and change-set construction.

      This task converts accepted command versions into canonical RDF deltas
      without querying or mutating the backend from command codecs.

      - [x] 4.2.1.1 Subtask {#jcf-p04-4-2-1-1} - Resolve command/version definitions from a fixed registry and reject user-controlled module/atom dispatch.
      - [x] 4.2.1.2 Subtask {#jcf-p04-4-2-1-2} - Normalize IRIs, literals, datatypes, language tags, controlled concepts, timestamps, and graph references.
      - [x] 4.2.1.3 Subtask {#jcf-p04-4-2-1-3} - Construct explicit provenance resources for command, actor association, inputs used, outputs generated, and causation.
      - [x] 4.2.1.4 Subtask {#jcf-p04-4-2-1-4} - Produce a deterministic logical fingerprint before accessing mutable graph state.

    - [x] 4.2.2 Task {#jcf-p04-precommit-pipeline} [repo: jido_code] [after: {#jcf-p04-command-normalization}] - Implement authorization, validation, and precondition evaluation.

      This task evaluates all policy and semantic guards against one consistent
      committed snapshot plus the proposed change before anything is visible.

      - [x] 4.2.2.1 Subtask {#jcf-p04-4-2-2-1} - Resolve actor, delegation, capabilities, enrollment/repository scope, and graph-family write authority.
      - [x] 4.2.2.2 Subtask {#jcf-p04-4-2-2-2} - Run RDF/shape/graph-topology validation against the effective post-change dataset.
      - [x] 4.2.2.3 Subtask {#jcf-p04-4-2-2-3} - Evaluate expected revisions, subject transition predecessor, uniqueness, immutable graph closure, and command-specific ASK preconditions.
      - [x] 4.2.2.4 Subtask {#jcf-p04-4-2-2-4} - Bound query count, rows, execution time, and diagnostic output for pre-commit checks.
      - [x] 4.2.2.5 Subtask {#jcf-p04-4-2-2-5} - Ensure a timeout or unavailable authorization/validation dependency fails closed.

    - [x] 4.2.3 Task {#jcf-p04-atomic-semantic-commit} [repo: jido_code] [after: {#jcf-p04-precommit-pipeline}] - Commit domain statements, provenance, audit, and revisions atomically.

      This task guarantees a successful product mutation can never appear
      without its responsible actor, cause, validation context, and audit
      outcome.

      - [x] 4.2.3.1 Subtask {#jcf-p04-4-2-3-1} - Assemble domain additions, transition/supersession statements, graph metadata, command/change-set provenance, audit resource, and revision updates into one commit.
      - [x] 4.2.3.2 Subtask {#jcf-p04-4-2-3-2} - Use the Phase 2 atomicity strategy and preserve all-or-nothing reader visibility across affected graphs.
      - [x] 4.2.3.3 Subtask {#jcf-p04-4-2-3-3} - Persist the logical request fingerprint and authoritative receipt in the same commit.
      - [x] 4.2.3.4 Subtask {#jcf-p04-4-2-3-4} - Return the committed receipt only after durability succeeds and classify response-loss ambiguity separately.
      - [x] 4.2.3.5 Subtask {#jcf-p04-4-2-3-5} - Never write an audit success for a rejected or failed domain change; record bounded rejection audits through their own authorized path where required.

    - [x] 4.2.4 Task {#jcf-p04-idempotency-recovery} [repo: jido_code] [after: {#jcf-p04-atomic-semantic-commit}] - Implement idempotent replay and outcome recovery.

      This task makes command retries safe when clients cannot know whether a
      response was lost before or after authoritative commit.

      - [x] 4.2.4.1 Subtask {#jcf-p04-4-2-4-1} - Map actor/scope/command idempotency keys to stable request resources and fingerprints.
      - [x] 4.2.4.2 Subtask {#jcf-p04-4-2-4-2} - Return the original receipt for equivalent replay without advancing revisions or duplicating statements.
      - [x] 4.2.4.3 Subtask {#jcf-p04-4-2-4-3} - Reject divergent reuse with a deterministic conflict and conceal prior payload details.
      - [x] 4.2.4.4 Subtask {#jcf-p04-4-2-4-4} - Resolve unknown-after-timeout outcomes by command IRI/idempotency identity before permitting a new command.
      - [x] 4.2.4.5 Subtask {#jcf-p04-4-2-4-5} - Define retention for idempotency receipts without permitting removal while referenced by durable domain history.

  - [x] 4.3 Section - Implement authorization, delegation, and audit policy.

    This section gives semantic writes an explicit accountable actor and
    least-privilege graph capability model without persisting credentials or
    moving route authorization into the graph writer.

    - [x] 4.3.1 Task {#jcf-p04-actor-authority} [repo: jido_code] [after: {#jcf-p04-idempotency-recovery}] - Implement actor, delegation, and capability context.

      This task distinguishes the authenticated caller, accountable actor,
      delegated software agent, and allowed semantic effects for each command.

      - [x] 4.3.1.1 Subtask {#jcf-p04-4-3-1-1} - Define opaque actor, principal, agent, delegation, authorization-grant, and capability IRIs with bounded context projections.
      - [x] 4.3.1.2 Subtask {#jcf-p04-4-3-1-2} - Separate observation, proposal, control, execution, evidence, decision, ontology, security, and administrative write capabilities.
      - [x] 4.3.1.3 Subtask {#jcf-p04-4-3-1-3} - Constrain delegation by actor, scope, capability, validity interval, command family, and optional resource/graph boundary.
      - [x] 4.3.1.4 Subtask {#jcf-p04-4-3-1-4} - Reject expired, revoked, cross-scope, self-expanded, or ambiguous delegation and preserve concealment behavior.
      - [x] 4.3.1.5 Subtask {#jcf-p04-4-3-1-5} - Keep authentication/session establishment and route admission in their owning web boundary.

    - [x] 4.3.2 Task {#jcf-p04-bootstrap-authority} [repo: jido_code] [after: {#jcf-p04-actor-authority}] - Define secure bootstrap and authority initialization.

      This task creates the first factory actor and policy graph without an
      ungoverned backdoor that survives initialization.

      - [x] 4.3.2.1 Subtask {#jcf-p04-4-3-2-1} - Define one explicit, local bootstrap procedure guarded by empty-dataset state and trusted operator configuration.
      - [x] 4.3.2.2 Subtask {#jcf-p04-4-3-2-2} - Atomically create factory identity, initial actor/grant, graph metadata, provenance, audit, and a bootstrap-complete assertion.
      - [x] 4.3.2.3 Subtask {#jcf-p04-4-3-2-3} - Disable bootstrap permanently for the dataset lineage after success and reject replay against restored initialized data.
      - [x] 4.3.2.4 Subtask {#jcf-p04-4-3-2-4} - Ensure no secret value or environment credential is copied into graph statements or receipts.

    - [x] 4.3.3 Task {#jcf-p04-audit-contract} [repo: jido_code] [after: {#jcf-p04-bootstrap-authority}] - Implement append-only semantic audit records.

      This task records accountable command activity without creating an
      alternate log authority or leaking command contents.

      - [x] 4.3.3.1 Subtask {#jcf-p04-4-3-3-1} - Record command/change-set, actor/delegation, scope, capability, causation, outcome, affected graph families, revisions, time, and safe issue codes.
      - [x] 4.3.3.2 Subtask {#jcf-p04-4-3-3-2} - Partition append-only audit graphs by bounded period and record closure/retention metadata.
      - [x] 4.3.3.3 Subtask {#jcf-p04-4-3-3-3} - Prohibit raw secrets, prompts, source bodies, arbitrary SPARQL, stack traces, and unbounded external payloads.
      - [x] 4.3.3.4 Subtask {#jcf-p04-4-3-3-4} - Authorize audit reads separately from ordinary product projections and preserve concealment across repository scopes.

  - [x] 4.4 Section - Implement post-commit change delivery and command recovery.

    This section lets runtime and presentation processes react efficiently
    while keeping the graph, not the notification channel, authoritative.

    - [x] 4.4.1 Task {#jcf-p04-change-feed} [repo: jido_code] [after: {#jcf-p04-audit-contract}] - Implement disposable post-commit change notifications.

      This task publishes low-cardinality wake-up hints only after a durable
      receipt exists.

      - [x] 4.4.1.1 Subtask {#jcf-p04-4-4-1-1} - Publish dataset revision, affected graph family/scope, command class, and receipt IRI after commit.
      - [x] 4.4.1.2 Subtask {#jcf-p04-4-4-1-2} - Use bounded PubSub topics derived from authorized scope rather than arbitrary resource or user input.
      - [x] 4.4.1.3 Subtask {#jcf-p04-4-4-1-3} - Exclude statement bodies, secrets, raw failures, prompts, source text, and authority-bearing context from events.
      - [x] 4.4.1.4 Subtask {#jcf-p04-4-4-1-4} - Require subscribers to re-query from their known revision and tolerate duplicate, delayed, reordered, or missed events.

    - [x] 4.4.2 Task {#jcf-p04-command-status} [repo: jido_code] [after: {#jcf-p04-change-feed}] - Implement bounded command outcome lookup.

      This task gives clients and recovery workers a reliable way to resolve
      timed-out requests without replaying side effects blindly.

      - [x] 4.4.2.1 Subtask {#jcf-p04-4-4-2-1} - Query a command by authorized command IRI or idempotency identity and return its current outcome/receipt projection.
      - [x] 4.4.2.2 Subtask {#jcf-p04-4-4-2-2} - Distinguish unknown, staged/uncommitted, committed, rejected, superseded, and inaccessible outcomes.
      - [x] 4.4.2.3 Subtask {#jcf-p04-4-4-2-3} - Reconcile uncommitted staging graphs according to the Phase 2 recovery protocol before reporting final status.
      - [x] 4.4.2.4 Subtask {#jcf-p04-4-4-2-4} - Preserve authorization and concealment on lookup; possession of an idempotency key alone grants no read authority.

  - [ ] 4.5 Section - Phase 4 Integration Tests.

    This final section proves semantic commands remain authorized, valid,
    atomic, idempotent, attributable, and recoverable under races, retries,
    response loss, and process death.

    - [x] 4.5.1 Task {#jcf-p04-command-integration} [repo: jido_code] [after: {#jcf-p04-command-status}] - Execute the command pipeline against real graph fixtures.

      This task exercises representative transitions, supersession, immutable
      graph creation, and cross-graph provenance through the production writer.

      - [x] 4.5.1.1 Subtask {#jcf-p04-4-5-1-1} - Bootstrap a fresh dataset and execute representative valid command/change-set fixtures across catalog, policy, control, audit, and immutable batch graphs.
      - [x] 4.5.1.2 Subtask {#jcf-p04-4-5-1-2} - Verify each visible assertion traces to command, change set, actor/delegation, cause, validation versions, audit outcome, and revisions.
      - [x] 4.5.1.3 Subtask {#jcf-p04-4-5-1-3} - Reject unauthorized graphs, invalid shapes, stale revisions, illegal transitions, immutable rewrites, and generic CRUD requests with no partial visibility.
      - [x] 4.5.1.4 Subtask {#jcf-p04-4-5-1-4} - Verify backup/export/restore preserves command receipts, audit relationships, and idempotency outcomes.

    - [x] 4.5.2 Task {#jcf-p04-concurrency-security-integration} [repo: jido_code] [after: {#jcf-p04-command-integration}] - Exercise races, retries, delegation, concealment, and notification loss.

      This task falsifies the mutation boundary under realistic concurrent and
      adversarial client behavior.

      - [x] 4.5.2.1 Subtask {#jcf-p04-4-5-2-1} - Race equivalent and divergent idempotency replays plus stale expected-revision commands and prove deterministic outcomes.
      - [x] 4.5.2.2 Subtask {#jcf-p04-4-5-2-2} - Kill writer/store/client processes before, during, and after commit and recover authoritative outcomes without duplicate effects.
      - [x] 4.5.2.3 Subtask {#jcf-p04-4-5-2-3} - Test expired/revoked delegation, capability widening, cross-repository references, guessed command IRIs, and audit enumeration.
      - [x] 4.5.2.4 Subtask {#jcf-p04-4-5-2-4} - Drop, duplicate, delay, and reorder PubSub notifications and prove subscribers recover by graph revision.
      - [x] 4.5.2.5 Subtask {#jcf-p04-4-5-2-5} - Scan logs, telemetry, errors, receipts, events, and graph literals for fixture secrets and forbidden raw payloads.
      - [x] 4.5.2.6 Subtask {#jcf-p04-4-5-2-6} - Rerun Phases 1-3 suites and `mix precommit`.

    - [ ] 4.5.3 Task {#jcf-p04-phase-receipt} [repo: jido_code] [after: {#jcf-p04-concurrency-security-integration}] - Publish the Phase 4 controlled-mutation receipt.

      This task binds G3 to exact command, authorization, validation,
      transaction, audit, idempotency, recovery, and notification evidence.

      - [x] 4.5.3.1 Subtask {#jcf-p04-4-5-3-1} - Record command registry/version, ontology/shape versions, capability model, transaction strategy, fixture digests, and candidate commit.
      - [x] 4.5.3.2 Subtask {#jcf-p04-4-5-3-2} - Attach valid/invalid command traces, race and crash results, delegation/concealment tests, audit checks, and event-loss recovery proof.
      - [x] 4.5.3.3 Subtask {#jcf-p04-4-5-3-3} - Keep G3 blocked if any visible statement lacks atomic provenance/audit, any adapter can issue raw mutations, or retries can duplicate semantic effects.
      - [ ] 4.5.3.4 Subtask {#jcf-p04-4-5-3-4} - Pin the merged candidate commit before authorizing Phase 5.
