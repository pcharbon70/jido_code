defmodule JidoCode.Factory.Model.Usage do
  @moduledoc "Bounded usage projection accepted by the Phase 1 invocation protocol."

  @spec normalize(map() | nil) :: map()
  def normalize(nil), do: %{}

  def normalize(usage) when is_map(usage) do
    %{}
    |> put_nonnegative_integer(:input_tokens, value(usage, :input_tokens))
    |> put_nonnegative_integer(:output_tokens, value(usage, :output_tokens))
    |> put_cost_units(value(usage, :total_cost))
  end

  def normalize(_usage), do: %{}

  defp put_nonnegative_integer(map, _key, nil), do: map

  defp put_nonnegative_integer(map, key, value) when is_integer(value) and value >= 0,
    do: Map.put(map, key, value)

  defp put_nonnegative_integer(map, _key, _value), do: map

  defp put_cost_units(map, value) when is_number(value) and value >= 0,
    do: Map.put(map, :cost_units, round(value * 1_000_000))

  defp put_cost_units(map, _value), do: map

  defp value(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))
end
