defmodule JidoCode.Factory.Model.StreamEvent do
  @moduledoc "Bounded event projected from the adapter's single stream view."

  @enforce_keys [:type, :data]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @types ~w[
    start text_delta tool_call_start tool_call_delta tool_call usage finish cancelled
    error policy_violation
  ]a

  @spec new(atom(), term()) :: {:ok, t()} | :error
  def new(type, data) when type in @types do
    if bounded?(data, limit(type)), do: {:ok, %__MODULE__{type: type, data: data}}, else: :error
  rescue
    _error -> :error
  end

  def new(_type, _data), do: :error

  defp limit(:text_delta), do: 32_768
  defp limit(_type), do: 16_384

  defp bounded?(value, maximum) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> byte_size()
    |> Kernel.<=(maximum)
  end
end
