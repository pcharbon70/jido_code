defmodule JidoCode.Knowledge.RepositoryWiki.Contract do
  @moduledoc false

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @digest ~r/^[a-f0-9]{64}$/

  @spec digest(term()) :: String.t()
  def digest(value) do
    value
    |> canonical()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec digest?(term()) :: boolean()
  def digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  @spec resource(term()) :: :ok | {:error, Error.t()}
  def resource(value), do: ResourceIdentity.validate(value)

  @spec optional_resource(term()) :: :ok | {:error, Error.t()}
  def optional_resource(nil), do: :ok
  def optional_resource(value), do: resource(value)

  @spec concept(atom()) :: String.t()
  def concept(value),
    do: "https://jido.run/ontology/concept/" <> (value |> Atom.to_string() |> Macro.camelize())

  @spec valid_interval?(term(), term()) :: boolean()
  def valid_interval?(%DateTime{} = start_at, nil),
    do: start_at == DateTime.truncate(start_at, :microsecond)

  def valid_interval?(%DateTime{} = start_at, %DateTime{} = expires_at) do
    start_at == DateTime.truncate(start_at, :microsecond) and
      expires_at == DateTime.truncate(expires_at, :microsecond) and
      DateTime.compare(start_at, expires_at) == :lt
  end

  def valid_interval?(_start_at, _expires_at), do: false

  defp canonical(%DateTime{} = value), do: DateTime.to_iso8601(value)

  defp canonical(value) when is_map(value) do
    value
    |> Enum.map(fn {key, nested} -> {to_string(key), canonical(nested)} end)
    |> Enum.sort()
  end

  defp canonical(value) when is_list(value), do: Enum.map(value, &canonical/1)
  defp canonical(value) when is_atom(value), do: Atom.to_string(value)
  defp canonical(value), do: value
end
