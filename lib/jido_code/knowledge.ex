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
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.QueryRunner
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
