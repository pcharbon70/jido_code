defmodule JidoCode.Knowledge.UnregisteredWriter do
  alias JidoCode.Knowledge.WriteBatch

  def persist(quads, options), do: WriteBatch.new(quads, options)
end
