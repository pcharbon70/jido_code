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
  alias JidoCode.Knowledge.Writer

  def execute(%CommandEnvelope{} = envelope, options \\ []), do: Writer.execute(envelope, options)

  def command_status(%CommandEnvelope{} = envelope, options \\ []),
    do: Writer.command_status(envelope, options)

  def subscribe_changes(scope_iri), do: ChangeFeed.subscribe(scope_iri)
  def bootstrap(attributes, options \\ []), do: Writer.bootstrap(attributes, options)

  def query(name, version, parameters, %AuthorityContext{} = authority, scope_iri, options \\ []),
    do: QueryRunner.execute(name, version, parameters, authority, scope_iri, options)

  def health, do: Readiness.snapshot()
  def ready?, do: health() |> JidoCode.Knowledge.Health.ready?()
  def gate(operation) when is_atom(operation), do: Readiness.gate(Readiness, operation)
  def store_summary, do: StoreServer.summary()
end
