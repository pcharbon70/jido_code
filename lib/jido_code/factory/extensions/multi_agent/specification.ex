defmodule JidoCode.Factory.Extensions.MultiAgent.Specification do
  @moduledoc "Accepted multi-agent graph-work contract for one graduated task class."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.MultiAgent.Evaluation
  alias JidoCode.Factory.Extensions.MultiAgent.Gate
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @contract_version "1.0.0"
  @keys [
    :revision,
    :status,
    :specification_iri,
    :evaluation,
    :gate_decision,
    :allowed_task_class,
    :coordination_mode,
    :maximum_workers,
    :aggregate_budget,
    :worker_output_schema,
    :worker_output_schema_digest
  ]
  @budget_keys [:output_bytes, :wall_time_ms, :cost_microunits, :model_tokens]
  @schema_keys [:additional_properties, :required, :properties]
  @coordination_modes %{
    independent_research: :independent_branches,
    disjoint_write_sets: :disjoint_writes,
    unboundable_context: :partitioned_context,
    specialized_isolated_tools: :isolated_specialists,
    verified_candidate_diversity: :verified_candidates
  }

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
         :ok <- Knowledge.validate_resource_identity(attributes[:specification_iri]),
         %Evaluation{} = evaluation <- attributes[:evaluation],
         true <- Evaluation.valid?(evaluation),
         decision when is_map(decision) <- attributes[:gate_decision],
         true <- Gate.valid?(decision, evaluation),
         :graduated <- decision[:status],
         true <- attributes[:allowed_task_class] == evaluation.task_class,
         true <- attributes[:coordination_mode] == @coordination_modes[evaluation.task_class],
         workers when is_integer(workers) and workers in 2..16 <- attributes[:maximum_workers],
         {:ok, budget} <- budget(attributes[:aggregate_budget]),
         :ok <- schema(attributes[:worker_output_schema]),
         true <- digest?(attributes[:worker_output_schema_digest]),
         true <-
           attributes.worker_output_schema_digest ==
             Definition.digest(attributes.worker_output_schema),
         normalized <- Map.put(attributes, :aggregate_budget, budget),
         digest <- Definition.digest(Map.take(normalized, @keys)) do
      {:ok, struct!(__MODULE__, Map.put(normalized, :digest, digest))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:multi_agent_specification)
    end
  rescue
    _error -> invalid(:multi_agent_specification)
  end

  def new(_attributes), do: invalid(:multi_agent_specification)

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = specification) do
    attributes = specification |> Map.from_struct() |> Map.take(@keys)

    case new(attributes) do
      {:ok, rebuilt} -> rebuilt == specification
      {:error, %AdapterError{}} -> false
    end
  end

  def valid?(_specification), do: false

  @spec validate_output(t(), map(), pos_integer()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def validate_output(%__MODULE__{} = specification, output, maximum_bytes)
      when is_map(output) and is_integer(maximum_bytes) and maximum_bytes > 0 do
    with true <- valid?(specification),
         {:ok, normalized} <- normalize(output, specification.worker_output_schema),
         keys = Map.keys(normalized),
         true <- Enum.all?(specification.worker_output_schema.required, &(&1 in keys)),
         true <-
           Enum.all?(normalized, fn {key, value} ->
             valid_type?(value, Map.fetch!(specification.worker_output_schema.properties, key))
           end),
         true <- bounded?(normalized, maximum_bytes) do
      {:ok, normalized}
    else
      _invalid -> invalid(:multi_agent_worker_output)
    end
  rescue
    _error -> invalid(:multi_agent_worker_output)
  end

  def validate_output(_specification, _output, _maximum_bytes),
    do: invalid(:multi_agent_worker_output)

  defp budget(value) when is_map(value) do
    if exact_shape?(value, @budget_keys) and
         Enum.all?(@budget_keys, &(is_integer(value[&1]) and value[&1] > 0)) do
      {:ok, Map.take(value, @budget_keys)}
    else
      invalid(:multi_agent_budget)
    end
  end

  defp budget(_value), do: invalid(:multi_agent_budget)

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
      _invalid -> invalid(:multi_agent_worker_output_schema)
    end
  end

  defp schema(_value), do: invalid(:multi_agent_worker_output_schema)

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
  defp valid_type?(value, {:string, maximum}), do: text?(value, maximum)

  defp valid_type?(value, {:integer, minimum, maximum}),
    do: is_integer(value) and value in minimum..maximum

  defp valid_type?(value, {:enum, values}), do: value in values

  defp valid_type?(value, {:list, type, maximum}),
    do: is_list(value) and length(value) <= maximum and Enum.all?(value, &valid_type?(&1, type))

  defp valid_type?(_value, _type), do: false

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
