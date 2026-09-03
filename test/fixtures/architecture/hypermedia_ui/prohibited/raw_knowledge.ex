defmodule JidoCodeWeb.ArchitectureFixture.RawKnowledge do
  alias JidoCode.Knowledge.Internal.Query

  def run, do: Query.execute("SELECT ?s WHERE { ?s ?p ?o }")
end
