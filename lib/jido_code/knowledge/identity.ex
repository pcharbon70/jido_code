defmodule JidoCode.Knowledge.Identity do
  @moduledoc false

  @spec lineage_iri() :: String.t()
  def lineage_iri do
    token = :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)
    "urn:jido-code:lineage:#{token}"
  end

  @spec commit_iri() :: String.t()
  def commit_iri do
    token = :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)
    "urn:jido-code:commit:#{token}"
  end

  @spec restore_activity_iri() :: String.t()
  def restore_activity_iri do
    token = :crypto.strong_rand_bytes(18) |> Base.url_encode64(padding: false)
    "urn:jido-code:restore-activity:#{token}"
  end

  @spec valid_commit_iri?(term()) :: boolean()
  def valid_commit_iri?(iri) when is_binary(iri) do
    Regex.match?(~r/^urn:jido-code:commit:[A-Za-z0-9_-]{8,128}$/, iri)
  end

  def valid_commit_iri?(_iri), do: false
end
