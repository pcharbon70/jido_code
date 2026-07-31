defmodule JidoCode.Knowledge.Queries.Graphs do
  @moduledoc """
  Bounded, read-only graph metadata queries.
  """

  alias JidoCode.Knowledge.QueryRunner

  def metadata(graph_iri, options \\ []) do
    QueryRunner.graph_metadata(graph_iri, options)
  end
end
