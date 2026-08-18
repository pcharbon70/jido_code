defmodule JidoCode.Factory.Extensions.MultiAgent.Plan do
  @moduledoc "Bounded graph-work fanout with one independent contract per worker."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.MultiAgent.Specification
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @keys [:specification_digest, :parent_task_iri, :coordinator_iri, :workers]
  @worker_keys [
    :worker_iri,
    :graph_task_iri,
    :context_manifest_iri,
    :context_manifest_digest,
    :attempt_iri,
    :lease_iri,
    :capability_iri,
    :capability_digest,
    :fencing_token,
    :budget,
    :output_schema_digest,
    :write_set,
    :isolated_tool_namespaces
  ]
  @budget_keys [:output_bytes, :wall_time_ms, :cost_microunits, :model_tokens]
  @identity_keys [
    :worker_iri,
    :graph_task_iri,
    :context_manifest_iri,
    :attempt_iri,
    :lease_iri,
    :capability_iri
  ]

  @enforce_keys @keys ++ [:digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Specification.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%Specification{} = specification, attributes) when is_map(attributes) do
    with true <- Specification.valid?(specification),
         true <- exact_shape?(attributes, @keys),
         true <- attributes[:specification_digest] == specification.digest,
         :ok <- resources(attributes, [:parent_task_iri, :coordinator_iri]),
         workers when is_list(workers) <- attributes[:workers],
         true <- length(workers) in 2..specification.maximum_workers,
         {:ok, workers} <- workers(workers, specification),
         :ok <- unique_contracts(workers),
         :ok <- aggregate_budget(workers, specification.aggregate_budget),
         :ok <- independence(workers, specification.allowed_task_class),
         normalized <- Map.put(attributes, :workers, workers),
         digest <- Definition.digest({specification.digest, Map.take(normalized, @keys)}) do
      {:ok, struct!(__MODULE__, Map.put(normalized, :digest, digest))}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:multi_agent_plan)
    end
  rescue
    _error -> invalid(:multi_agent_plan)
  end

  def new(_specification, _attributes), do: invalid(:multi_agent_plan)

  @spec valid?(t(), Specification.t()) :: boolean()
  def valid?(%__MODULE__{} = plan, %Specification{} = specification) do
    attributes = plan |> Map.from_struct() |> Map.take(@keys)

    case new(specification, attributes) do
      {:ok, rebuilt} -> rebuilt == plan
      {:error, %AdapterError{}} -> false
    end
  end

  def valid?(_plan, _specification), do: false

  @spec fetch_worker(t(), String.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def fetch_worker(%__MODULE__{} = plan, worker_iri) when is_binary(worker_iri) do
    case Enum.find(plan.workers, &(&1.worker_iri == worker_iri)) do
      worker when is_map(worker) -> {:ok, worker}
      nil -> invalid(:multi_agent_worker)
    end
  end

  def fetch_worker(_plan, _worker_iri), do: invalid(:multi_agent_worker)

  defp workers(values, specification) do
    values
    |> Enum.reduce_while({:ok, []}, fn value, {:ok, accepted} ->
      case worker(value, specification) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | accepted]}}
        {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, accepted} -> {:ok, Enum.sort_by(accepted, & &1.worker_iri)}
      {:error, %AdapterError{} = error} -> {:error, error}
    end
  end

  defp worker(value, specification) when is_map(value) do
    with true <- exact_shape?(value, @worker_keys),
         :ok <- resources(value, @identity_keys),
         true <- digest?(value[:context_manifest_digest]),
         true <- digest?(value[:capability_digest]),
         fence when is_integer(fence) and fence > 0 <- value[:fencing_token],
         {:ok, budget} <- worker_budget(value[:budget], specification.aggregate_budget),
         true <- value[:output_schema_digest] == specification.worker_output_schema_digest,
         {:ok, write_set} <- paths(value[:write_set]),
         {:ok, tools} <- namespaces(value[:isolated_tool_namespaces]),
         normalized <-
           value
           |> Map.put(:budget, budget)
           |> Map.put(:write_set, write_set)
           |> Map.put(:isolated_tool_namespaces, tools) do
      {:ok, Map.take(normalized, @worker_keys)}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:multi_agent_worker)
    end
  end

  defp worker(_value, _specification), do: invalid(:multi_agent_worker)

  defp worker_budget(value, aggregate) when is_map(value) do
    if exact_shape?(value, @budget_keys) and
         Enum.all?(@budget_keys, fn key ->
           amount = value[key]
           is_integer(amount) and amount > 0 and amount <= aggregate[key]
         end) do
      {:ok, Map.take(value, @budget_keys)}
    else
      invalid(:multi_agent_worker_budget)
    end
  end

  defp worker_budget(_value, _aggregate), do: invalid(:multi_agent_worker_budget)

  defp unique_contracts(workers) do
    unique? =
      Enum.all?(@identity_keys, fn key ->
        values = Enum.map(workers, & &1[key])
        length(values) == length(Enum.uniq(values))
      end)

    if unique?, do: :ok, else: invalid(:multi_agent_worker_identity)
  end

  defp aggregate_budget(workers, maximum) do
    within? =
      Enum.all?(@budget_keys, fn key ->
        Enum.sum(Enum.map(workers, & &1.budget[key])) <= maximum[key]
      end)

    if within?, do: :ok, else: invalid(:multi_agent_aggregate_budget)
  end

  defp independence(workers, :disjoint_write_sets) do
    write_sets = Enum.map(workers, &MapSet.new(&1.write_set))

    if Enum.all?(write_sets, &(MapSet.size(&1) > 0)) and pairwise_disjoint?(write_sets),
      do: :ok,
      else: invalid(:multi_agent_write_independence)
  end

  defp independence(workers, :specialized_isolated_tools) do
    tool_sets = Enum.map(workers, &MapSet.new(&1.isolated_tool_namespaces))

    if Enum.all?(tool_sets, &(MapSet.size(&1) > 0)) and pairwise_disjoint?(tool_sets),
      do: :ok,
      else: invalid(:multi_agent_tool_isolation)
  end

  defp independence(_workers, _task_class), do: :ok

  defp pairwise_disjoint?([]), do: true

  defp pairwise_disjoint?([first | rest]) do
    Enum.all?(rest, &MapSet.disjoint?(first, &1)) and pairwise_disjoint?(rest)
  end

  defp paths(values) when is_list(values) and length(values) <= 128 do
    if Enum.all?(values, &relative_path?/1) and length(values) == length(Enum.uniq(values)),
      do: {:ok, Enum.sort(values)},
      else: invalid(:multi_agent_write_set)
  end

  defp paths(_values), do: invalid(:multi_agent_write_set)

  defp relative_path?(value) when is_binary(value) and byte_size(value) in 1..512 do
    Path.type(value) == :relative and value == Path.join(Path.split(value)) and
      not String.contains?(value, ["\\", <<0>>, "//"]) and
      Enum.all?(Path.split(value), &(&1 not in [".", "..", ""]))
  end

  defp relative_path?(_value), do: false

  defp namespaces(values) when is_list(values) and length(values) <= 32 do
    if Enum.all?(values, fn value ->
         is_binary(value) and Regex.match?(~r/^[a-z][a-z0-9_.:-]{0,63}$/, value)
       end) and length(values) == length(Enum.uniq(values)) do
      {:ok, Enum.sort(values)}
    else
      invalid(:multi_agent_tool_namespace)
    end
  end

  defp namespaces(_values), do: invalid(:multi_agent_tool_namespace)

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid(:multi_agent_plan_identity)
  end

  defp exact_shape?(value, keys),
    do: MapSet.new(Map.keys(value)) == MapSet.new(keys)

  defp digest?(value),
    do: is_binary(value) and Regex.match?(~r/^sha256:[a-f0-9]{64}$/, value)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
