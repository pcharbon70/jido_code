defmodule JidoCode.Knowledge do
  @moduledoc """
  Public command and health boundary for the authoritative knowledge substrate.

  It never exposes raw backend handles, write batches, or arbitrary SPARQL.
  """

  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Projection
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.DerivedGraphManager
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

  def repository_locator_identity(provider, external_id),
    do: ResourceIdentity.repository_locator(provider, external_id)

  def repository_address(provider, owner, name),
    do: ResourceIdentity.repository_locator(provider, owner, name)

  def provider_identity(provider), do: ResourceIdentity.provider_host(provider)

  def provider_object_identity(locator_iri, kind, external_id),
    do: ResourceIdentity.provider_object(locator_iri, kind, external_id)

  def git_object_identity(algorithm, value), do: ResourceIdentity.git_object(algorithm, value)
  def validate_resource_identity(iri), do: ResourceIdentity.validate(iri)

  def health, do: Readiness.snapshot()
  def ready?, do: health() |> JidoCode.Knowledge.Health.ready?()
  def gate(operation) when is_atom(operation), do: Readiness.gate(Readiness, operation)
  def store_summary, do: StoreServer.summary()
end
