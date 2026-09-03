defmodule JidoCodeWeb.ArchitectureFixture.DirectGraphWrite do
  def run(store), do: TripleStore.update(store, "INSERT DATA { <s> <p> <o> }")
end
