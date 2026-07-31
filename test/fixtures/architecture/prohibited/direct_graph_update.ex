defmodule JidoCode.Knowledge.ArchitectureFixture.DirectGraphUpdate do
  def write(store) do
    TripleStore.update(store, "INSERT DATA { <urn:s> <urn:p> <urn:o> }")
  end
end
