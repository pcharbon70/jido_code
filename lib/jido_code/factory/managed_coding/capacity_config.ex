defmodule JidoCode.Factory.ManagedCoding.CapacityConfig do
  @moduledoc "Closed concurrency, queue, reservation, and queue-expiry limits."

  alias JidoCode.Factory.AdapterError

  @dimensions ~w[global tenant repository provider sandbox verifier adapter]a
  @enforce_keys ~w[concurrency queue reserved queue_ttl_ms]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- limits(attributes[:concurrency], false),
         :ok <- limits(attributes[:queue], true),
         reserved when is_integer(reserved) and reserved >= 0 <- attributes[:reserved],
         true <- reserved < attributes.concurrency.global,
         ttl when is_integer(ttl) and ttl > 0 <- attributes[:queue_ttl_ms] do
      {:ok,
       %__MODULE__{
         concurrency: attributes.concurrency,
         queue: attributes.queue,
         reserved: reserved,
         queue_ttl_ms: ttl
       }}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_capacity_config)}
    end
  end

  def new(_attributes),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_capacity_config)}

  defp limits(values, zero_allowed) when is_map(values) do
    valid_keys = MapSet.new(Map.keys(values)) == MapSet.new(@dimensions)

    valid_values =
      Enum.all?(@dimensions, fn dimension ->
        value = values[dimension]
        is_integer(value) and if(zero_allowed, do: value >= 0, else: value > 0)
      end)

    if valid_keys and valid_values, do: :ok, else: :error
  end

  defp limits(_values, _zero_allowed), do: :error
end
