defmodule JidoCode.Knowledge.Identity do
  @moduledoc false

  @spec lineage_iri() :: String.t()
  def lineage_iri do
    token = :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)
    "urn:jido-code:lineage:#{token}"
  end
end
