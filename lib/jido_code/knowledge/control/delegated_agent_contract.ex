defmodule JidoCode.Knowledge.Control.DelegatedAgentContract do
  @moduledoc false

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @digest ~r/^[a-f0-9]{64}$/
  @identifier ~r/^[a-z][a-z0-9_-]*$/

  @spec digest?(term()) :: boolean()
  def digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  @spec digest(term()) :: String.t()
  def digest(value) do
    value
    |> canonical()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @spec identifier(term(), pos_integer()) :: {:ok, String.t()} | :error
  def identifier(value, limit)
      when is_binary(value) and byte_size(value) in 1..limit//1 do
    if Regex.match?(@identifier, value), do: {:ok, value}, else: :error
  end

  def identifier(_value, _limit), do: :error

  @spec text(term(), pos_integer()) :: {:ok, String.t()} | :error
  def text(value, limit) when is_binary(value) and byte_size(value) in 1..limit//1 do
    trimmed = String.trim(value)
    if trimmed == "", do: :error, else: {:ok, trimmed}
  rescue
    _error -> :error
  end

  def text(_value, _limit), do: :error

  @spec enum(term(), [atom()]) :: {:ok, atom()} | :error
  def enum(value, allowed) when is_atom(value),
    do: if(value in allowed, do: {:ok, value}, else: :error)

  def enum(_value, _allowed), do: :error

  @spec identifiers(term(), pos_integer(), pos_integer()) :: {:ok, [String.t()]} | :error
  def identifiers(values, maximum, item_limit)
      when is_list(values) and values != [] and length(values) <= maximum do
    if Enum.all?(values, &match?({:ok, _}, identifier(&1, item_limit))) do
      {:ok, values |> Enum.uniq() |> Enum.sort()}
    else
      :error
    end
  end

  def identifiers(_values, _maximum, _item_limit), do: :error

  @spec resources(term(), pos_integer()) :: {:ok, [String.t()]} | :error
  def resources(values, maximum)
      when is_list(values) and values != [] and length(values) <= maximum do
    if Enum.all?(values, &(ResourceIdentity.validate(&1) == :ok)) do
      {:ok, values |> Enum.uniq() |> Enum.sort()}
    else
      :error
    end
  end

  def resources(_values, _maximum), do: :error

  @spec resource(term()) :: :ok | {:error, Error.t()}
  def resource(value), do: ResourceIdentity.validate(value)

  @spec optional_resource(term()) :: :ok | {:error, Error.t()}
  def optional_resource(nil), do: :ok
  def optional_resource(value), do: ResourceIdentity.validate(value)

  @spec bounded_map(term(), pos_integer()) :: {:ok, map()} | :error
  def bounded_map(value, limit) when is_map(value) and map_size(value) > 0 do
    if byte_size(:erlang.term_to_binary(value, [:deterministic])) <= limit,
      do: {:ok, value},
      else: :error
  end

  def bounded_map(_value, _limit), do: :error

  @spec interval(term(), term()) :: :ok | :error
  def interval(%DateTime{} = approved_at, %DateTime{} = expires_at) do
    if DateTime.compare(approved_at, expires_at) == :lt, do: :ok, else: :error
  end

  def interval(_approved_at, _expires_at), do: :error

  @spec concept(atom()) :: String.t()
  def concept(value),
    do: "https://jido.run/ontology/concept/" <> (value |> Atom.to_string() |> Macro.camelize())

  defp canonical(%DateTime{} = value), do: DateTime.to_iso8601(value)

  defp canonical(value) when is_map(value) do
    value
    |> Enum.map(fn {key, item} -> {to_string(key), canonical(item)} end)
    |> Enum.sort()
  end

  defp canonical(value) when is_list(value), do: Enum.map(value, &canonical/1)
  defp canonical(value) when is_atom(value), do: Atom.to_string(value)
  defp canonical(value), do: value
end
