defmodule JidoCode.Knowledge do
  @moduledoc """
  Public command and health boundary for the authoritative knowledge substrate.

  It never exposes raw backend handles, write batches, or arbitrary SPARQL.
  """

  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Commands.PublishSourceGraph
  alias JidoCode.Knowledge.Control.DesiredOutcome
  alias JidoCode.Knowledge.Control.Eligibility
  alias JidoCode.Knowledge.Control.ExecutionLease
  alias JidoCode.Knowledge.Control.CapabilityRegistry
  alias JidoCode.Knowledge.Control.Cohort
  alias JidoCode.Knowledge.Control.GovernanceProjection
  alias JidoCode.Knowledge.Control.Obligation
  alias JidoCode.Knowledge.Control.Policy
  alias JidoCode.Knowledge.Control.Reconciliation
  alias JidoCode.Knowledge.Control.ReconciliationPackage
  alias JidoCode.Knowledge.Control.ReconciliationProjection
  alias JidoCode.Knowledge.Control.WorkGraph
  alias JidoCode.Knowledge.Control.WorkProjection
  alias JidoCode.Knowledge.Execution.InteractionMessage
  alias JidoCode.Knowledge.Execution.InteractionProjection
  alias JidoCode.Knowledge.Execution.InteractionSession
  alias JidoCode.Knowledge.Execution.Attempt
  alias JidoCode.Knowledge.Execution.AttemptProjection
  alias JidoCode.Knowledge.Execution.Artifact
  alias JidoCode.Knowledge.Execution.ToolInvocation
  alias JidoCode.Knowledge.Execution.Provenance
  alias JidoCode.Knowledge.Decision.GoalOutcome
  alias JidoCode.Knowledge.Decision.Projection, as: DecisionProjection
  alias JidoCode.Knowledge.Evidence.Bundle, as: EvidenceBundle
  alias JidoCode.Knowledge.Evidence.Graph, as: EvidenceGraph
  alias JidoCode.Knowledge.Evidence.Projection, as: EvidenceProjection
  alias JidoCode.Knowledge.Evidence.Sufficiency, as: EvidenceSufficiency
  alias JidoCode.Knowledge.Evidence.VerificationActivity
  alias JidoCode.Knowledge.Evidence.VerificationMethod
  alias JidoCode.Knowledge.Memory.Adoption, as: KnowledgeAdoption
  alias JidoCode.Knowledge.Memory.Assertion, as: KnowledgeAssertion
  alias JidoCode.Knowledge.Memory.Evolution, as: KnowledgeEvolution
  alias JidoCode.Knowledge.Memory.Graph, as: MemoryGraph
  alias JidoCode.Knowledge.Memory.Retrieval, as: KnowledgeRetrieval
  alias JidoCode.Knowledge.Memory.StateTransition, as: KnowledgeStateTransition
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Queries.ExecutionRecovery
  alias JidoCode.Knowledge.Projection
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.DerivedGraphManager
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Writer

  def execute(%CommandEnvelope{} = envelope, options \\ []), do: Writer.execute(envelope, options)

  def command_status(%CommandEnvelope{} = envelope, options \\ []),
    do: Writer.command_status(envelope, options)

  def subscribe_changes(scope_iri), do: ChangeFeed.subscribe(scope_iri)
  def bootstrap(attributes, options \\ []), do: Writer.bootstrap(attributes, options)

  def query(name, version, parameters, %AuthorityContext{} = authority, scope_iri, options \\ []),
    do: QueryRunner.execute(name, version, parameters, authority, scope_iri, options)

  def project(result, %AuthorityContext{} = authority, scope_iri, options \\ []),
    do: Projection.build(result, authority, scope_iri, options)

  def publish_derived(attributes, options \\ []),
    do: DerivedGraphManager.publish(attributes, options)

  def source_publication_command(attributes, options \\ []),
    do: PublishSourceGraph.build(attributes, options)

  def desired_outcome(attributes), do: DesiredOutcome.new(attributes)

  def assert_desired_outcome(outcome, attributes, options \\ []),
    do: DesiredOutcome.assert_command(outcome, attributes, options)

  def propose_goal(attributes, options \\ []), do: WorkGraph.propose_goal(attributes, options)
  def propose_plan(attributes, options \\ []), do: WorkGraph.propose_plan(attributes, options)

  def adopt_plan(plan, attributes, options \\ []),
    do: WorkGraph.adopt_plan(plan, attributes, options)

  def project_work(result, context), do: WorkProjection.build(result, context)

  def policy(attributes), do: Policy.new(attributes)

  def propose_policy(policy, attributes, options \\ []),
    do: Policy.propose_command(policy, attributes, options)

  def resolve_policy_conflicts(policies), do: Policy.resolve_conflicts(policies)
  def repository_cohort(attributes), do: Cohort.new(attributes)

  def define_repository_cohort(cohort, attributes, options \\ []),
    do: Cohort.define_command(cohort, attributes, options)

  def publish_cohort_membership(cohort, memberships, attributes, options \\ []),
    do: Cohort.publish_membership(cohort, memberships, attributes, options)

  def policy_obligation(attributes), do: Obligation.new(attributes)

  def derive_policy_obligation(obligation, attributes, options \\ []),
    do: Obligation.derive_command(obligation, attributes, options)

  def capability(attributes), do: CapabilityRegistry.new(attributes)

  def register_capability(capability, attributes, options \\ []),
    do: CapabilityRegistry.register_command(capability, attributes, options)

  def project_governance(result, context), do: GovernanceProjection.build(result, context)
  def reconciliation_package(attributes), do: ReconciliationPackage.new(attributes)

  def reconcile(package, evaluations, attributes),
    do: Reconciliation.new(package, evaluations, attributes)

  def record_reconciliation(reconciliation, attributes, options \\ []),
    do: Reconciliation.record_command(reconciliation, attributes, options)

  def project_reconciliation(result, context), do: ReconciliationProjection.build(result, context)

  def evaluate_eligibility(context), do: Eligibility.evaluate(context)

  def acquire_execution_lease(eligibility, task_resolution, attributes, options \\ []),
    do: ExecutionLease.acquire_command(eligibility, task_resolution, attributes, options)

  def transition_execution_lease(
        lease,
        lease_resolution,
        task_resolution,
        attributes,
        options \\ []
      ),
      do:
        ExecutionLease.transition_command(
          lease,
          lease_resolution,
          task_resolution,
          attributes,
          options
        )

  def execution_lease_guard(lease, control_graph_iri, fence, at),
    do: ExecutionLease.execution_guard(lease, control_graph_iri, fence, at)

  def interaction_session(attributes), do: InteractionSession.new(attributes)

  def open_interaction_session(session, attributes, options \\ []),
    do: InteractionSession.open_command(session, attributes, options)

  def transition_interaction_session(session, resolution, attributes, options \\ []),
    do: InteractionSession.transition_command(session, resolution, attributes, options)

  def interaction_message(attributes), do: InteractionMessage.new(attributes)

  def record_interaction_message(message, resolution, attributes, options \\ []),
    do: InteractionMessage.record_command(message, resolution, attributes, options)

  def project_interaction(result, context), do: InteractionProjection.build(result, context)

  def execution_attempt(context, attributes), do: Attempt.new(context, attributes)

  def start_execution_attempt(attempt, context, lease, resolutions, attributes, options \\ []),
    do: Attempt.start_command(attempt, context, lease, resolutions, attributes, options)

  def transition_execution_attempt(
        attempt,
        attempt_resolution,
        lease,
        task_resolution,
        attributes,
        options \\ []
      ),
      do:
        Attempt.transition_command(
          attempt,
          attempt_resolution,
          lease,
          task_resolution,
          attributes,
          options
        )

  def tool_invocation(attempt, attributes), do: ToolInvocation.new(attempt, attributes)

  def start_tool_invocation(invocation, attempt, resolution, lease, attributes, options \\ []),
    do: ToolInvocation.start_command(invocation, attempt, resolution, lease, attributes, options)

  def record_tool_outcome(invocation, attempt, resolution, lease, attributes, options \\ []),
    do:
      ToolInvocation.outcome_command(invocation, attempt, resolution, lease, attributes, options)

  def execution_artifact(attributes), do: Artifact.new(attributes)

  def record_execution_artifact(artifact, attempt, resolution, lease, attributes, options \\ []),
    do: Artifact.record_command(artifact, attempt, resolution, lease, attributes, options)

  def verify_execution_artifact(artifact, options \\ []), do: Artifact.verify(artifact, options)

  def finalize_execution_run(attempt, resolution, lease, attributes, options \\ []),
    do: Provenance.finalize_command(attempt, resolution, lease, attributes, options)

  def project_execution_attempt(results, context), do: AttemptProjection.build(results, context)

  def execution_recovery_candidates(result, graph_iri),
    do: ExecutionRecovery.candidates(result, graph_iri)

  def verification_method(attributes), do: VerificationMethod.new(attributes)

  def verification_activity(method, attributes),
    do: VerificationActivity.new(method, attributes)

  def evidence_bundle(activity, evidence_graph_iri, attributes),
    do: EvidenceBundle.new(activity, evidence_graph_iri, attributes)

  def record_verification_evidence(bundle, attributes, options \\ []),
    do: EvidenceBundle.record_command(bundle, attributes, options)

  def evaluate_evidence_sufficiency(bundles, requirements, context),
    do: EvidenceSufficiency.evaluate(bundles, requirements, context)

  def project_evidence(result, context), do: EvidenceProjection.build(result, context)
  def project_evidence_sufficiency(assessment), do: EvidenceProjection.sufficiency(assessment)

  def evidence_graph_identity(repository_iri), do: EvidenceGraph.evidence_graph(repository_iri)

  def goal_outcome_decision(assessment, bundles, goal_resolution, task_resolution, attributes),
    do: GoalOutcome.new(assessment, bundles, goal_resolution, task_resolution, attributes)

  def decide_goal_outcome(decision, attributes, options \\ []),
    do: GoalOutcome.record_command(decision, attributes, options)

  def project_decision(result, context), do: DecisionProjection.build(result, context)

  def knowledge_assertion(decision, source_claims, attributes),
    do: KnowledgeAssertion.new(decision, source_claims, attributes)

  def adopt_knowledge(assertion, decision, attributes, options \\ []),
    do: KnowledgeAdoption.record_command(assertion, decision, attributes, options)

  def evolve_knowledge(assertion, resolution, replacement, attributes, options \\ []),
    do:
      KnowledgeEvolution.record_command(
        assertion,
        resolution,
        replacement,
        attributes,
        options
      )

  def resolve_knowledge_state(transitions), do: KnowledgeStateTransition.resolve(transitions)
  def retrieve_knowledge(result, context), do: KnowledgeRetrieval.build(result, context)
  def memory_graph_identity(repository_iri), do: MemoryGraph.memory_graph(repository_iri)

  def repository_locator_identity(provider, external_id),
    do: ResourceIdentity.repository_locator(provider, external_id)

  def repository_address(provider, owner, name),
    do: ResourceIdentity.repository_locator(provider, owner, name)

  def provider_identity(provider), do: ResourceIdentity.provider_host(provider)

  def provider_object_identity(locator_iri, kind, external_id),
    do: ResourceIdentity.provider_object(locator_iri, kind, external_id)

  def git_object_identity(algorithm, value), do: ResourceIdentity.git_object(algorithm, value)

  def repository_snapshot_identity(repository_iri, algorithm, tree_digest),
    do: ResourceIdentity.repository_snapshot(repository_iri, algorithm, tree_digest)

  def source_artifact_identity(snapshot_iri, path, digest),
    do: ResourceIdentity.source_artifact(snapshot_iri, path, digest)

  def code_symbol_identity(snapshot_iri, kind, name),
    do: ResourceIdentity.code_symbol(snapshot_iri, kind, name)

  def source_analysis_identity(snapshot_iri, analyzer_version, configuration_digest),
    do: ResourceIdentity.source_analysis(snapshot_iri, analyzer_version, configuration_digest)

  def source_graph_identity(repository_iri, snapshot_iri),
    do:
      GraphRegistry.graph_iri(:source_revision, %{
        repository: repository_iri,
        revision: snapshot_iri
      })

  def validate_resource_identity(iri), do: ResourceIdentity.validate(iri)
  def validate_graph_identity(iri), do: GraphRegistry.identify(iri)

  def health, do: Readiness.snapshot()
  def ready?, do: health() |> JidoCode.Knowledge.Health.ready?()
  def gate(operation) when is_atom(operation), do: Readiness.gate(Readiness, operation)
  def store_summary, do: StoreServer.summary()
end
