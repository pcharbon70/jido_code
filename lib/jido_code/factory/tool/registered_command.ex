defmodule JidoCode.Factory.Tool.RegisteredCommand do
  @moduledoc "Server-owned command contract; model input selects only its stable name."

  alias JidoCode.Factory.AdapterError

  @derive {Inspect, only: [:name, :working_directory, :network_policy]}
  @enforce_keys [
    :name,
    :executable,
    :working_directory,
    :arguments,
    :environment,
    :network_policy,
    :resource_limits
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @limit_keys ~w[cpu_ms memory_bytes timeout_ms output_bytes]a

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with name when is_binary(name) and byte_size(name) in 1..64 <- attributes[:name],
         true <- Regex.match?(~r/^[a-z][a-z0-9_-]*$/, name),
         executable when is_binary(executable) <- attributes[:executable],
         true <- Path.type(executable) == :absolute and byte_size(executable) <= 512,
         :repository_root <- attributes[:working_directory],
         true <- text_list?(attributes[:arguments], 64, 512),
         true <- environment?(attributes[:environment]),
         :ok <- network_policy(attributes[:network_policy]),
         true <- limits?(attributes[:resource_limits]) do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp text_list?(values, maximum_count, maximum_bytes)
       when is_list(values) and length(values) <= maximum_count do
    Enum.all?(values, fn value ->
      is_binary(value) and byte_size(value) <= maximum_bytes and
        not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
    end)
  end

  defp text_list?(_values, _count, _bytes), do: false

  defp environment?(environment) when is_map(environment) and map_size(environment) <= 16 do
    Enum.all?(environment, fn {name, value} ->
      is_binary(name) and Regex.match?(~r/^[A-Z][A-Z0-9_]*$/, name) and
        is_binary(value) and byte_size(value) <= 256 and
        not Regex.match?(~r/(?:TOKEN|SECRET|PASSWORD|KEY)/, name) and
        not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)
    end)
  end

  defp environment?(_environment), do: false

  defp network_policy(:deny), do: :ok

  defp network_policy({:allowlist, destinations})
       when is_list(destinations) and destinations != [] and length(destinations) <= 16 do
    if Enum.all?(destinations, &(is_binary(&1) and byte_size(&1) in 1..256)),
      do: :ok,
      else: :error
  end

  defp network_policy(_policy), do: :error

  defp limits?(limits) when is_map(limits) and map_size(limits) == 4 do
    Enum.sort(Map.keys(limits)) == Enum.sort(@limit_keys) and
      Enum.all?(limits, fn {_key, value} -> is_integer(value) and value > 0 end)
  end

  defp limits?(_limits), do: false
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :registered_command)}
end
