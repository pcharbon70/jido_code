defmodule JidoCodeWeb.ArchitectureFixture.DirectStoreOpen do
  def open(path), do: TripleStore.open(path, schema: :quad)
end
