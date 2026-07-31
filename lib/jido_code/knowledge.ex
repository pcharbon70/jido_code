defmodule JidoCode.Knowledge do
  @moduledoc """
  Public health boundary for the authoritative knowledge substrate.

  Semantic command and query contracts will be added behind this facade in
  later phases. It never exposes raw backend handles or arbitrary SPARQL.
  """

  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.StoreServer

  def health, do: Readiness.snapshot()
  def ready?, do: health() |> JidoCode.Knowledge.Health.ready?()
  def gate(operation) when is_atom(operation), do: Readiness.gate(Readiness, operation)
  def store_summary, do: StoreServer.summary()
end
