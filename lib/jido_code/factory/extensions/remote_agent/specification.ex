defmodule JidoCode.Factory.Extensions.RemoteAgent.Specification do
  @moduledoc "Accepted remote-agent protocol, identity, budget, and output contract."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @contract_version "1.0.0"
  @keys [
    :revision,
    :status,
    :specification_iri,
    :evidence_iri,
    :remote_agent_iri,
    :remote_identity,
    :protocol_versions,
    :adapter_identity,
    :adapter_digest,
    :maximum_budget,
    :output_schema,
    :output_schema_digest
  ]
  @budget_keys [:output_bytes, :wall_time_ms, :cost_microunits, :model_tokens]
  @schema_keys [:additional_properties, :required, :properties]

  @enforce_keys @keys ++ [:digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- exact_shape?(attributes, @keys),
         true <- text?(attributes[:revision], 128),
         :accepted <- attributes[:status],
         :ok <- resources(attributes, [:specification_iri, :evidence_iri, :remote_agent_iri]),
         true <- text?(attributes[:remote_identity], 256),
         {:ok, protocols} <- protocols(attributes[:protocol_versions]),
         true <- text?(attributes[:adapter_identity], 256),
         true <- digest?(attributes[:adapter_digest]),
         true <- attributes.adapter_digest == Definition.digest(attributes.adapter_identity),
         {:ok, budget} <- budget(attributes[:maximum_budget]),
         :ok <- schema(attributes[:output_schema]),
         true <- digest?(attributes[:output_schema_digest]),
         true <- attributes.output_schema_digest == Definition.digest(attributes.output_schema),
         normalized <-
           attributes
           |> Map.put(:protocol_versions, protocols)
           |> Map.put(:maximum_budget, budget),
         digest <- Definition.digest(Map.take(normalized, @keys)) do
      {:ok, struct!(__MODULE__, Map.put(normalized, :digest, digest))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:remote_agent_specification)
    end
  rescue
    _error -> invalid(:remote_agent_specification)
  end

  def new(_attributes), do: invalid(:remote_agent_specification)

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = specification) do
    attributes = specification |> Map.from_struct() |> Map.take(@keys)

    case new(attributes) do
      {:ok, rebuilt} -> rebuilt == specification
      {:error, %AdapterError{}} -> false
    end
  end

  def valid?(_specification), do: false

  @spec validate_output(t(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def validate_output(%__MODULE__{} = specification, output) when is_map(output) do
    with true <- valid?(specification),
         {:ok, normalized} <- normalize(output, specification.output_schema),
         keys = Map.keys(normalized),
         true <- Enum.all?(specification.output_schema.required, &(&1 in keys)),
         true <-
           Enum.all?(normalized, fn {key, value} ->
             valid_type?(value, Map.fetch!(specification.output_schema.properties, key))
           end),
         true <- bounded?(normalized, specification.maximum_budget.output_bytes) do
      {:ok, normalized}
    else
      _invalid -> invalid(:remote_agent_output)
    end
  rescue
    _error -> invalid(:remote_agent_output)
  end

  def validate_output(_specification, _output), do: invalid(:remote_agent_output)

  defp protocols(values) when is_map(values) and map_size(values) in 1..8 do
    if Enum.all?(values, fn {name, version} ->
         is_atom(name) and text?(version, 64)
       end) do
      {:ok, Map.new(Enum.sort(values))}
    else
      invalid(:remote_agent_protocols)
    end
  end

  defp protocols(_values), do: invalid(:remote_agent_protocols)

  defp budget(value) when is_map(value) do
    if exact_shape?(value, @budget_keys) and
         Enum.all?(@budget_keys, fn key ->
           amount = value[key]
           is_integer(amount) and amount > 0
         end) do
      {:ok, Map.take(value, @budget_keys)}
    else
      invalid(:remote_agent_budget)
    end
  end

  defp budget(_value), do: invalid(:remote_agent_budget)

  defp schema(value) when is_map(value) do
    with true <- exact_shape?(value, @schema_keys),
         false <- value[:additional_properties],
         required when is_list(required) <- value[:required],
         properties when is_map(properties) and map_size(properties) in 1..32 <-
           value[:properties],
         true <- Enum.all?(Map.keys(properties), &is_atom/1),
         true <- Enum.all?(required, &is_atom/1),
         true <- length(required) == length(Enum.uniq(required)),
         true <- Enum.all?(required, &Map.has_key?(properties, &1)),
         true <- Enum.all?(properties, fn {_key, type} -> schema_type?(type) end),
         true <- bounded?(value, 16_384) do
      :ok
    else
      _invalid -> invalid(:remote_agent_output_schema)
    end
  end

  defp schema(_value), do: invalid(:remote_agent_output_schema)

  defp normalize(output, schema) do
    names = Map.new(Map.keys(schema.properties), &{Atom.to_string(&1), &1})

    Enum.reduce_while(output, {:ok, %{}}, fn
      {key, value}, {:ok, accepted} when is_atom(key) ->
        if Map.has_key?(schema.properties, key) and not Map.has_key?(accepted, key),
          do: {:cont, {:ok, Map.put(accepted, key, value)}},
          else: {:halt, :error}

      {key, value}, {:ok, accepted} when is_binary(key) ->
        case Map.fetch(names, key) do
          {:ok, atom_key} when not is_map_key(accepted, atom_key) ->
            {:cont, {:ok, Map.put(accepted, atom_key, value)}}

          _unknown ->
            {:halt, :error}
        end

      _entry, _accepted ->
        {:halt, :error}
    end)
  end

  defp schema_type?(:boolean), do: true
  defp schema_type?(:digest), do: true
  defp schema_type?(:resource_iri), do: true
  defp schema_type?({:string, maximum}), do: is_integer(maximum) and maximum in 1..8_192

  defp schema_type?({:integer, minimum, maximum}),
    do: is_integer(minimum) and is_integer(maximum) and minimum <= maximum

  defp schema_type?({:enum, values}),
    do:
      is_list(values) and values != [] and length(values) <= 32 and
        length(values) == length(Enum.uniq(values))

  defp schema_type?({:list, type, maximum}),
    do: is_integer(maximum) and maximum in 1..64 and schema_type?(type)

  defp schema_type?(_type), do: false

  defp valid_type?(value, :boolean), do: is_boolean(value)

  defp valid_type?(value, :digest),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp valid_type?(value, :resource_iri), do: Knowledge.validate_resource_identity(value) == :ok

  defp valid_type?(value, {:string, maximum}),
    do: text?(value, maximum)

  defp valid_type?(value, {:integer, minimum, maximum}),
    do: is_integer(value) and value in minimum..maximum

  defp valid_type?(value, {:enum, values}), do: value in values

  defp valid_type?(value, {:list, type, maximum}),
    do: is_list(value) and length(value) <= maximum and Enum.all?(value, &valid_type?(&1, type))

  defp valid_type?(_value, _type), do: false

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid(:remote_agent_identity)
  end

  defp exact_shape?(value, keys),
    do: MapSet.new(Map.keys(value)) == MapSet.new(keys)

  defp digest?(value),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp text?(value, maximum),
    do:
      is_binary(value) and byte_size(value) in 1..maximum and
        not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp bounded?(value, maximum),
    do: byte_size(:erlang.term_to_binary(value, [:deterministic])) <= maximum

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
