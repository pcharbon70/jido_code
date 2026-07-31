---
id: plan.jido_code_graph_factory_phase_03
intent: contract_change
source:
  - docs/research/graph-native-managed-repository-factory.md
---

# Phase 3 - Ontology, Identity, Graph Topology, And Validation

This phase defines the first versioned Jido Factory ontology, canonical
resource and graph identities, named graph lifecycle rules, SHACL-compatible
validation shapes, temporal and epistemic semantics, and schema migration
discipline that make RDF the actual domain model rather than a serialization
format for Elixir records.

Back to plan: [README](./README.md)

- [ ] 3 Phase - Establish the graph-native semantic contract and executable validation boundary.

  This phase admits the first domain-bearing statements only after their
  vocabulary, identity, provenance, graph placement, temporal meaning, and
  evolution rules are explicit and testable.

  - [ ] 3.1 Section - Define the versioned ontology and controlled vocabularies.

    This section creates a small project-owned ontology that reuses standard
    RDF vocabularies and models relationships directly instead of reproducing
    object fields and foreign keys.

    - [ ] 3.1.1 Task {#jcf-p03-ontology-package} [repo: jido_code] [after: {#jcf-p02-phase-receipt}] - Create the ontology source and release layout.

      This task establishes immutable, reviewable ontology artifacts and a
      deterministic way to load and identify them.

      - [ ] 3.1.1.1 Subtask {#jcf-p03-3-1-1-1} - Add `priv/ontology` sources for the factory ontology, validation shapes, controlled work states, policy terms, and ontology metadata.
      - [ ] 3.1.1.2 Subtask {#jcf-p03-3-1-1-2} - Choose canonical ontology and term IRI namespaces separately from resource and named-graph IRI namespaces.
      - [ ] 3.1.1.3 Subtask {#jcf-p03-3-1-1-3} - Define immutable ontology version IRIs, semantic versions, source digests, imports, compatibility posture, and release notes.
      - [ ] 3.1.1.4 Subtask {#jcf-p03-3-1-1-4} - Load ontology schema only into `ontology/{version}` graphs and keep the default and repository instance graphs free of schema copies.
      - [ ] 3.1.1.5 Subtask {#jcf-p03-3-1-1-5} - Add deterministic parse, canonical serialization, and checksum tasks for ontology artifacts.

    - [ ] 3.1.2 Task {#jcf-p03-core-vocabulary} [repo: jido_code] [after: {#jcf-p03-ontology-package}] - Define the initial factory resources and relationships.

      This task expresses repository identity, knowledge, intent, execution,
      governance, interaction, and actor semantics as connected graph terms.

      - [ ] 3.1.2.1 Subtask {#jcf-p03-3-1-2-1} - Define `RepositoryFactory`, `SoftwareRepository`, `RepositoryLocator`, `ManagementEnrollment`, `RepositorySnapshot`, `SourceArtifact`, `CodeSymbol`, and `Scope`.
      - [ ] 3.1.2.2 Subtask {#jcf-p03-3-1-2-2} - Define `ObservationActivity`, `ObservationBatch`, `Claim`, `AssessmentActivity`, `Finding`, `Contradiction`, `KnowledgeAssertion`, and `AdoptionActivity`.
      - [ ] 3.1.2.3 Subtask {#jcf-p03-3-1-2-3} - Define `DesiredOutcome`, `Goal`, `Constraint`, `Policy`, `Obligation`, `Task`, `Plan`, `Capability`, and `Lease`.
      - [ ] 3.1.2.4 Subtask {#jcf-p03-3-1-2-4} - Define `ExecutionAttempt`, `ToolInvocation`, `Patch`, `VerificationActivity`, `Artifact`, `EvidenceBundle`, and `Decision` using PROV-O activities/entities where applicable.
      - [ ] 3.1.2.5 Subtask {#jcf-p03-3-1-2-5} - Define `Actor`, `Agent`, `InteractionSession`, `Message`, `AuthorizationGrant`, and `CredentialReference` without credential-value predicates.
      - [ ] 3.1.2.6 Subtask {#jcf-p03-3-1-2-6} - Define direct relationships for enrollment, management, location, scope, derivation, support, contradiction, goal decomposition, dependency, blocking, capability, policy, execution, evaluation, acceptance, satisfaction, supersession, lease ownership, and validity.

    - [ ] 3.1.3 Task {#jcf-p03-standard-vocabulary-alignment} [repo: jido_code] [after: {#jcf-p03-core-vocabulary}] - Align project terms with established semantic vocabularies.

      This task avoids project-specific reinvention while constraining external
      vocabulary use to semantics the application can validate and query.

      - [ ] 3.1.3.1 Subtask {#jcf-p03-3-1-3-1} - Map entity/activity/agent, generation, use, derivation, association, invalidation, and time to PROV-O.
      - [ ] 3.1.3.2 Subtask {#jcf-p03-3-1-3-2} - Use SKOS concepts and schemes for controlled state, outcome, priority, confidence band, artifact kind, and decision disposition.
      - [ ] 3.1.3.3 Subtask {#jcf-p03-3-1-3-3} - Use Dublin Core Terms and SPDX only where their documented semantics fit repository and software artifacts.
      - [ ] 3.1.3.4 Subtask {#jcf-p03-3-1-3-4} - Document domain/range guidance, expected cardinality, provenance policy, graph ownership, and query use for every project predicate.
      - [ ] 3.1.3.5 Subtask {#jcf-p03-3-1-3-5} - Reject ontology terms that exist only to mirror an Elixir module, struct field, enum atom, or storage codec.

  - [ ] 3.2 Section - Implement canonical identity and named graph topology.

    This section gives every resource and graph a deterministic, validated
    identity and enforces lifecycle boundaries independently from Elixir
    record types.

    - [ ] 3.2.1 Task {#jcf-p03-resource-identity} [repo: jido_code] [after: {#jcf-p03-standard-vocabulary-alignment}] - Implement canonical resource IRI construction and validation.

      This task prevents ad hoc strings, foreign-key literals, user-created
      atoms, and ambiguous provider identities from becoming graph identity.

      - [ ] 3.2.1.1 Subtask {#jcf-p03-3-2-1-1} - Define deterministic IRIs for natural external identities and opaque time-sortable IRIs for local activities, claims, goals, attempts, and decisions.
      - [ ] 3.2.1.2 Subtask {#jcf-p03-3-2-1-2} - Canonicalize provider host, repository locator, Git object, and content-digest inputs without conflating a locator with the conceptual repository.
      - [ ] 3.2.1.3 Subtask {#jcf-p03-3-2-1-3} - Validate namespace, segment encoding, maximum size, control characters, normalization, and scope before constructing an RDF IRI.
      - [ ] 3.2.1.4 Subtask {#jcf-p03-3-2-1-4} - Make identity functions pure and inject clock/random/ID sources through deterministic ports.
      - [ ] 3.2.1.5 Subtask {#jcf-p03-3-2-1-5} - Permit interoperability/display IDs only as literals and require graph relationships to join by IRI.

    - [ ] 3.2.2 Task {#jcf-p03-graph-registry} [repo: jido_code] [after: {#jcf-p03-resource-identity}] - Implement the named graph family registry.

      This task centralizes graph placement, ownership, lifecycle, and link
      rules so callers cannot invent storage topology in application code.

      - [ ] 3.2.2.1 Subtask {#jcf-p03-3-2-2-1} - Register ontology, factory catalog, factory policy, observation batch, source revision, repository control, run attempt, evidence, memory, security audit, and derived graph families.
      - [ ] 3.2.2.2 Subtask {#jcf-p03-3-2-2-2} - Define required scope inputs, canonical graph IRI template, writer capability, mutability, completeness, retention class, and allowed cross-graph links for each family.
      - [ ] 3.2.2.3 Subtask {#jcf-p03-3-2-2-3} - Enforce immutable/write-once behavior for ontology releases, observation batches, source revisions, and closed run graphs.
      - [ ] 3.2.2.4 Subtask {#jcf-p03-3-2-2-4} - Reserve the default graph for no application data and reject unregistered named graph writes.
      - [ ] 3.2.2.5 Subtask {#jcf-p03-3-2-2-5} - Avoid one graph per ordinary entity while preserving batch, snapshot, attempt, authority, and retention boundaries.

    - [ ] 3.2.3 Task {#jcf-p03-graph-metadata} [repo: jido_code] [after: {#jcf-p03-graph-registry}] - Define and validate named graph metadata.

      This task makes every graph self-describing enough for bounded queries,
      migration, reasoning, integrity, backup, and retention.

      - [ ] 3.2.3.1 Subtask {#jcf-p03-3-2-3-1} - Require graph kind, owner scope, ontology version, creation activity, creation time, lifecycle state, completeness state, and current graph revision.
      - [ ] 3.2.3.2 Subtask {#jcf-p03-3-2-3-2} - Add source revision, parent lineage, closure time, rule-set version, or retention metadata where required by graph family.
      - [ ] 3.2.3.3 Subtask {#jcf-p03-3-2-3-3} - Store metadata through the same atomic write boundary as graph creation and closure.
      - [ ] 3.2.3.4 Subtask {#jcf-p03-3-2-3-4} - Make metadata queryable without exposing graph contents or granting mutation authority.

  - [ ] 3.3 Section - Implement shape validation and ontology evolution.

    This section turns ontology rules into a fail-closed write contract and
    establishes explicit migration behavior before durable product graphs
    accumulate.

    - [ ] 3.3.1 Task {#jcf-p03-shape-contracts} [repo: jido_code] [after: {#jcf-p03-graph-metadata}] - Define SHACL-compatible operational shapes.

      This task captures command-critical structural and graph-placement
      invariants in versioned ontology artifacts.

      - [ ] 3.3.1.1 Subtask {#jcf-p03-3-3-1-1} - Define required types, predicates, datatypes, cardinalities, controlled concept schemes, and IRI scope for each admitted resource form.
      - [ ] 3.3.1.2 Subtask {#jcf-p03-3-3-1-2} - Define graph-family shapes for metadata, allowed resource classes, required provenance, immutable closure, and cross-scope references.
      - [ ] 3.3.1.3 Subtask {#jcf-p03-3-3-1-3} - Define transition predecessor/revision, lease fencing, claim proposition, evidence linkage, decision authority, and secret-reference constraints.
      - [ ] 3.3.1.4 Subtask {#jcf-p03-3-3-1-4} - Distinguish open-world semantic guidance from closed-world operational requirements explicitly.
      - [ ] 3.3.1.5 Subtask {#jcf-p03-3-3-1-5} - Version shapes independently where compatible ontology vocabulary can support stricter operational validation.

    - [ ] 3.3.2 Task {#jcf-p03-validator} [repo: jido_code] [after: {#jcf-p03-shape-contracts}] - Implement ontology-aware pre-commit validation.

      This task validates a proposed change against its effective dataset and
      graph metadata without requiring every caller to understand RDF rules.

      - [ ] 3.3.2.1 Subtask {#jcf-p03-3-3-2-1} - Validate RDF term forms, required shape constraints, graph-family rules, cross-reference scope, and effective ontology/shape version.
      - [ ] 3.3.2.2 Subtask {#jcf-p03-3-3-2-2} - Evaluate constraints against existing committed statements plus proposed additions/supersessions within the transaction snapshot.
      - [ ] 3.3.2.3 Subtask {#jcf-p03-3-3-2-3} - Return stable validation result resources with focus node, shape, path, issue code, severity, and bounded safe message.
      - [ ] 3.3.2.4 Subtask {#jcf-p03-3-3-2-4} - Reject unknown ontology/shape versions, ambiguous graph completeness, secret-like literals in protected positions, and validation timeouts.
      - [ ] 3.3.2.5 Subtask {#jcf-p03-3-3-2-5} - Permit failed import validation reports to be recorded only through a bounded quarantine/audit path that cannot make invalid domain statements visible.

    - [ ] 3.3.3 Task {#jcf-p03-schema-evolution} [repo: jido_code] [after: {#jcf-p03-validator}] - Implement ontology compatibility and graph migration contracts.

      This task prevents in-place vocabulary reinterpretation and makes every
      durable transformation attributable and recoverable.

      - [ ] 3.3.3.1 Subtask {#jcf-p03-3-3-3-1} - Classify ontology changes as additive compatible, validation-only, behaviorally stricter, transform-required, or breaking.
      - [ ] 3.3.3.2 Subtask {#jcf-p03-3-3-3-2} - Require a new immutable ontology version and migration activity for changed term meaning or graph shape.
      - [ ] 3.3.3.3 Subtask {#jcf-p03-3-3-3-3} - Transform source graphs into new target graphs or append explicit supersession without silently rewriting immutable history.
      - [ ] 3.3.3.4 Subtask {#jcf-p03-3-3-3-4} - Record source/target graphs, versions, transformer version, actor, counts, validation report, and rollback posture.
      - [ ] 3.3.3.5 Subtask {#jcf-p03-3-3-3-5} - Block application startup or affected writes when a required migration is missing or partially committed.

  - [ ] 3.4 Section - Define claims, time, state transitions, and inference authority.

    This section gives changing knowledge and operational state explicit
    provenance, validity, disagreement, and causal ordering instead of mutable
    status fields or last-write-wins updates.

    - [ ] 3.4.1 Task {#jcf-p03-claim-model} [repo: jido_code] [after: {#jcf-p03-schema-evolution}] - Implement statement and claim representation rules.

      This task distinguishes graph-level provenance from claims that require
      statement-level confidence, validity, contradiction, or acceptance.

      - [ ] 3.4.1.1 Subtask {#jcf-p03-3-4-1-1} - Permit direct statements in immutable graphs when one graph-level provenance envelope is sufficient.
      - [ ] 3.4.1.2 Subtask {#jcf-p03-3-4-1-2} - Represent consequential or disputable propositions as first-class `Claim` resources with RDF subject, predicate, object, source activity, and graph scope.
      - [ ] 3.4.1.3 Subtask {#jcf-p03-3-4-1-3} - Define observed, asserted, inferred, proposed, accepted, rejected, contradicted, superseded, and invalidated epistemic concepts.
      - [ ] 3.4.1.4 Subtask {#jcf-p03-3-4-1-4} - Model confidence, uncertainty, contradiction, support, and supersession without allowing numeric confidence to imply acceptance.
      - [ ] 3.4.1.5 Subtask {#jcf-p03-3-4-1-5} - Preserve incompatible claims and require explicit evaluation or decision rather than last-write-wins deletion.

    - [ ] 3.4.2 Task {#jcf-p03-temporal-model} [repo: jido_code] [after: {#jcf-p03-claim-model}] - Implement transaction-time and valid-time semantics.

      This task keeps when JidoCode learned a fact separate from when the fact
      applied in the external repository world.

      - [ ] 3.4.2.1 Subtask {#jcf-p03-3-4-2-1} - Define recorded/committed time, generated time, valid-from/to, invalidated time, and source-observed time predicates and datatype rules.
      - [ ] 3.4.2.2 Subtask {#jcf-p03-3-4-2-2} - Require clocks to enter through the command boundary and never derive causal order solely from wall time.
      - [ ] 3.4.2.3 Subtask {#jcf-p03-3-4-2-3} - Define delayed observation, retroactive correction, force-push, and policy-effective-time behavior.
      - [ ] 3.4.2.4 Subtask {#jcf-p03-3-4-2-4} - Add bounded temporal query fixtures for facts valid, recorded, superseded, or unknown at a requested point.

    - [ ] 3.4.3 Task {#jcf-p03-transition-model} [repo: jido_code] [after: {#jcf-p03-temporal-model}] - Implement causal state-transition semantics.

      This task defines current operational state as a validated transition
      chain rather than a mutable enum literal.

      - [ ] 3.4.3.1 Subtask {#jcf-p03-3-4-3-1} - Define transition subject, prior/next state concepts, expected predecessor, monotonic subject revision or fencing token, actor, cause, reason, and time.
      - [ ] 3.4.3.2 Subtask {#jcf-p03-3-4-3-2} - Require one genesis and one accepted successor at each revision, preserving rejected or superseded concurrent proposals as history.
      - [ ] 3.4.3.3 Subtask {#jcf-p03-3-4-3-3} - Reject missing predecessors, illegal edges, revision regression, cross-subject chains, and wall-clock tie breaking.
      - [ ] 3.4.3.4 Subtask {#jcf-p03-3-4-3-4} - Define current state as the endpoint of the unique valid, non-superseded chain.

    - [ ] 3.4.4 Task {#jcf-p03-inference-contract} [repo: jido_code] [after: {#jcf-p03-transition-model}] - Define asserted and derived graph authority rules.

      This task reserves a safe place for later OWL/rule materialization
      without granting derived statements mutation or acceptance authority.

      - [ ] 3.4.4.1 Subtask {#jcf-p03-3-4-4-1} - Require derived graph metadata to identify rule set, ontology version, source graph revisions, generation activity, and invalidation state.
      - [ ] 3.4.4.2 Subtask {#jcf-p03-3-4-4-2} - Prohibit inferred statements from satisfying goals, authorizing commands, or accepting claims unless an explicit policy consumes them through a governed decision.
      - [ ] 3.4.4.3 Subtask {#jcf-p03-3-4-4-3} - Make every derived graph disposable and rebuildable from asserted source graphs.
      - [ ] 3.4.4.4 Subtask {#jcf-p03-3-4-4-4} - Define stale and incompatible derived-graph behavior before implementing domain reasoning rules.

  - [ ] 3.5 Section - Phase 3 Integration Tests.

    This final section proves ontology, identity, graph placement, validation,
    temporal claims, transition chains, and evolution rules round-trip through
    the real quad store without record-shaped shortcuts.

    - [ ] 3.5.1 Task {#jcf-p03-ontology-integration} [repo: jido_code] [after: {#jcf-p03-inference-contract}] - Load and validate the complete ontology release.

      This task verifies deterministic ontology artifacts and representative
      valid datasets against real storage and query behavior.

      - [ ] 3.5.1.1 Subtask {#jcf-p03-3-5-1-1} - Parse, canonicalize, checksum, load, export, restore, and byte/term-compare the ontology and shapes.
      - [ ] 3.5.1.2 Subtask {#jcf-p03-3-5-1-2} - Load the illustrative repository-enrollment, observation, goal, attempt, evidence, and decision slice across registered graph families.
      - [ ] 3.5.1.3 Subtask {#jcf-p03-3-5-1-3} - Query every required cross-graph relationship and verify no join depends on foreign-key literals.
      - [ ] 3.5.1.4 Subtask {#jcf-p03-3-5-1-4} - Verify schema and instance graphs remain separated and the default graph remains empty after backup/restore.

    - [ ] 3.5.2 Task {#jcf-p03-validation-integration} [repo: jido_code] [after: {#jcf-p03-ontology-integration}] - Falsify identity, shape, temporal, and transition constraints.

      This task proves invalid semantic data cannot become visible even when it
      is well-formed RDF.

      - [ ] 3.5.2.1 Subtask {#jcf-p03-3-5-2-1} - Reject malformed/cross-scope IRIs, unknown graphs, missing graph metadata, wrong graph-family classes, invalid datatypes, and secret-like protected literals.
      - [ ] 3.5.2.2 Subtask {#jcf-p03-3-5-2-2} - Reject incomplete claims, invalid epistemic changes, unsupported confidence forms, and contradictory cardinality constraints.
      - [ ] 3.5.2.3 Subtask {#jcf-p03-3-5-2-3} - Race transition successors and prove one valid chain endpoint without timestamp-based resolution.
      - [ ] 3.5.2.4 Subtask {#jcf-p03-3-5-2-4} - Exercise additive and transform-required ontology migrations, interrupted migration recovery, validation reports, and rollback posture.
      - [ ] 3.5.2.5 Subtask {#jcf-p03-3-5-2-5} - Delete/rebuild a derived fixture graph and prove asserted truth and graph revisions remain coherent.
      - [ ] 3.5.2.6 Subtask {#jcf-p03-3-5-2-6} - Rerun Phases 1-2 invariant suites and `mix precommit`.

    - [ ] 3.5.3 Task {#jcf-p03-phase-receipt} [repo: jido_code] [after: {#jcf-p03-validation-integration}] - Publish the Phase 3 semantic-contract receipt.

      This task binds G2 to exact ontology, shape, identity, graph registry,
      validation, temporal, transition, and migration evidence.

      - [ ] 3.5.3.1 Subtask {#jcf-p03-3-5-3-1} - Record ontology/shape versions and digests, graph registry revision, fixture digests, validator version, and candidate commit.
      - [ ] 3.5.3.2 Subtask {#jcf-p03-3-5-3-2} - Attach round-trip, invalid-data, race, temporal, migration, restore, and derived-graph results.
      - [ ] 3.5.3.3 Subtask {#jcf-p03-3-5-3-3} - Keep G2 blocked if any resource requires an object-record codec, any graph lacks ownership metadata, or invalid RDF can become visible.
      - [ ] 3.5.3.4 Subtask {#jcf-p03-3-5-3-4} - Pin the merged candidate commit before authorizing Phase 4.
