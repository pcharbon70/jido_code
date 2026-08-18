defmodule JidoCode.Factory.Extensions.MultiAgent.Evaluation do
  @moduledoc "Pinned single-agent versus multi-agent evidence for one eligible task class."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Definition
  alias JidoCode.Knowledge

  @contract_version "1.0.0"
  @task_classes [
    :independent_research,
    :disjoint_write_sets,
    :unboundable_context,
    :specialized_isolated_tools,
    :verified_candidate_diversity
  ]
  @keys [
    :revision,
    :evidence_iri,
    :phase7_receipt_iri,
    :phase7_candidate_sha,
    :profile_revision,
    :task_class,
    :single_agent,
    :multi_agent,
    :thresholds
  ]
  @single_keys [:tasks, :verified_correct, :elapsed_ms, :cost_microunits]
  @multi_keys @single_keys ++ [:conflicts, :duplicated_work, :merge_failures]
  @threshold_keys [
    :minimum_tasks,
    :minimum_success_gain_basis_points,
    :maximum_cost_ratio_milli,
    :maximum_conflict_rate_basis_points,
    :maximum_duplicate_rate_basis_points,
    :maximum_merge_failure_rate_basis_points
  ]

  @enforce_keys @keys ++ [:measurements, :digest]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec contract_version() :: String.t()
  def contract_version, do: @contract_version

  @spec task_classes() :: [atom()]
  def task_classes, do: @task_classes

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <- exact_shape?(attributes, @keys),
         true <- text?(attributes[:revision], 128),
         :ok <- resources(attributes, [:evidence_iri, :phase7_receipt_iri]),
         true <- commit?(attributes[:phase7_candidate_sha]),
         true <- text?(attributes[:profile_revision], 128),
         task_class when task_class in @task_classes <- attributes[:task_class],
         {:ok, single} <- sample(attributes[:single_agent], @single_keys),
         {:ok, multi} <- sample(attributes[:multi_agent], @multi_keys),
         {:ok, thresholds} <- thresholds(attributes[:thresholds]),
         true <- single.tasks >= thresholds.minimum_tasks,
         true <- multi.tasks >= thresholds.minimum_tasks,
         measurements <- measurements(single, multi),
         normalized <-
           attributes
           |> Map.put(:single_agent, single)
           |> Map.put(:multi_agent, multi)
           |> Map.put(:thresholds, thresholds),
         digest <- Definition.digest({Map.take(normalized, @keys), measurements}) do
      {:ok,
       struct!(
         __MODULE__,
         normalized |> Map.put(:measurements, measurements) |> Map.put(:digest, digest)
       )}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> invalid(:multi_agent_evaluation)
    end
  rescue
    _error -> invalid(:multi_agent_evaluation)
  end

  def new(_attributes), do: invalid(:multi_agent_evaluation)

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = evaluation) do
    attributes = evaluation |> Map.from_struct() |> Map.take(@keys)

    case new(attributes) do
      {:ok, rebuilt} -> rebuilt == evaluation
      {:error, %AdapterError{}} -> false
    end
  end

  def valid?(_evaluation), do: false

  defp sample(value, keys) when is_map(value) do
    with true <- exact_shape?(value, keys),
         true <- Enum.all?(keys, &(is_integer(value[&1]) and value[&1] >= 0)),
         true <- value[:tasks] > 0,
         true <- value[:verified_correct] <= value[:tasks],
         true <- value[:elapsed_ms] > 0,
         true <- value[:cost_microunits] > 0,
         true <- counts_within_tasks?(value) do
      {:ok, Map.take(value, keys)}
    else
      _invalid -> invalid(:multi_agent_evaluation_sample)
    end
  end

  defp sample(_value, _keys), do: invalid(:multi_agent_evaluation_sample)

  defp counts_within_tasks?(value) do
    Enum.all?([:conflicts, :duplicated_work, :merge_failures], fn key ->
      not Map.has_key?(value, key) or value[key] <= value.tasks
    end)
  end

  defp thresholds(value) when is_map(value) do
    with true <- exact_shape?(value, @threshold_keys),
         minimum when is_integer(minimum) and minimum in 30..10_000 <- value[:minimum_tasks],
         gain when is_integer(gain) and gain in 1..10_000 <-
           value[:minimum_success_gain_basis_points],
         cost when is_integer(cost) and cost in 1_000..20_000 <-
           value[:maximum_cost_ratio_milli],
         conflict when is_integer(conflict) and conflict in 0..10_000 <-
           value[:maximum_conflict_rate_basis_points],
         duplicate when is_integer(duplicate) and duplicate in 0..10_000 <-
           value[:maximum_duplicate_rate_basis_points],
         merge when is_integer(merge) and merge in 0..10_000 <-
           value[:maximum_merge_failure_rate_basis_points] do
      {:ok, Map.take(value, @threshold_keys)}
    else
      _invalid -> invalid(:multi_agent_evaluation_thresholds)
    end
  end

  defp thresholds(_value), do: invalid(:multi_agent_evaluation_thresholds)

  defp measurements(single, multi) do
    single_success = rate(single.verified_correct, single.tasks)
    multi_success = rate(multi.verified_correct, multi.tasks)

    %{
      single_success_basis_points: single_success,
      multi_success_basis_points: multi_success,
      success_gain_basis_points: multi_success - single_success,
      cost_ratio_milli: ratio(multi.cost_microunits, single.cost_microunits),
      elapsed_ratio_milli: ratio(multi.elapsed_ms, single.elapsed_ms),
      conflict_rate_basis_points: rate(multi.conflicts, multi.tasks),
      duplicate_rate_basis_points: rate(multi.duplicated_work, multi.tasks),
      merge_failure_rate_basis_points: rate(multi.merge_failures, multi.tasks)
    }
  end

  defp rate(numerator, denominator), do: div(numerator * 10_000, denominator)
  defp ratio(numerator, denominator), do: div(numerator * 1_000, denominator)

  defp resources(attributes, keys) do
    if Enum.all?(keys, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: invalid(:multi_agent_evaluation_identity)
  end

  defp exact_shape?(value, keys),
    do: MapSet.new(Map.keys(value)) == MapSet.new(keys)

  defp text?(value, maximum),
    do:
      is_binary(value) and byte_size(value) in 1..maximum and
        not Regex.match?(~r/[\x00-\x1F\x7F]/u, value)

  defp commit?(value),
    do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{40}(?:[a-f0-9]{24})?$/, value)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
end
