defmodule JidoCode.Factory.Fleet.Policy do
  @moduledoc """
  Effective fleet limits resolved from graph policy and trusted ceilings.

  Graph policy may always narrow a trusted runtime ceiling but can never widen
  it. The resulting struct is transient and must be rebuilt with each graph
  discovery cycle.
  """

  alias JidoCode.Knowledge.Error

  @concurrency_dimensions [:global, :cohort, :repository, :provider, :capability]
  @bounded_fields [
    :rate_units,
    :budget_units,
    :max_risk,
    :max_candidates,
    :max_campaign_repositories,
    :starvation_cycles,
    :emergency_priority
  ]
  @default_ceilings %{
    concurrency: %{global: 16, cohort: 8, repository: 2, provider: 4, capability: 4},
    rate_units: 100,
    budget_units: 100,
    max_risk: 10,
    max_candidates: 200,
    max_campaign_repositories: 50,
    starvation_cycles: 5,
    emergency_priority: 100
  }
  @maximums %{
    rate_units: 100_000,
    budget_units: 100_000,
    max_risk: 100,
    max_candidates: 1_000,
    max_campaign_repositories: 1_000,
    starvation_cycles: 10_000,
    emergency_priority: 1_000_000
  }

  @enforce_keys [
    :concurrency,
    :rate_units,
    :budget_units,
    :max_risk,
    :max_candidates,
    :max_campaign_repositories,
    :starvation_cycles,
    :emergency_priority,
    :policy_revision
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          concurrency: %{required(atom()) => pos_integer()},
          rate_units: pos_integer(),
          budget_units: pos_integer(),
          max_risk: non_neg_integer(),
          max_candidates: pos_integer(),
          max_campaign_repositories: pos_integer(),
          starvation_cycles: non_neg_integer(),
          emergency_priority: non_neg_integer(),
          policy_revision: non_neg_integer() | nil
        }

  @spec resolve(map(), map() | keyword()) :: {:ok, t()} | {:error, Error.t()}
  def resolve(graph_policy \\ %{}, trusted_ceilings \\ configured_ceilings())

  def resolve(graph_policy, trusted_ceilings)
      when is_map(graph_policy) and (is_map(trusted_ceilings) or is_list(trusted_ceilings)) do
    ceilings = normalize_legacy_limits(Map.new(trusted_ceilings))

    with :ok <- validate_keys(graph_policy),
         :ok <- validate_keys(ceilings),
         {:ok, trusted} <- complete_and_validate(ceilings),
         {:ok, requested} <- complete_and_validate(Map.merge(trusted, graph_policy)) do
      {:ok,
       %__MODULE__{
         concurrency: narrow_concurrency(requested.concurrency, trusted.concurrency),
         rate_units: min(requested.rate_units, trusted.rate_units),
         budget_units: min(requested.budget_units, trusted.budget_units),
         max_risk: min(requested.max_risk, trusted.max_risk),
         max_candidates: min(requested.max_candidates, trusted.max_candidates),
         max_campaign_repositories:
           min(requested.max_campaign_repositories, trusted.max_campaign_repositories),
         starvation_cycles: min(requested.starvation_cycles, trusted.starvation_cycles),
         emergency_priority: max(requested.emergency_priority, trusted.emergency_priority),
         policy_revision: valid_revision(graph_policy[:policy_revision])
       }}
    end
  end

  def resolve(_graph_policy, _trusted_ceilings),
    do: {:error, Error.new(:invalid_input, :fleet_policy)}

  @spec configured_ceilings() :: map()
  def configured_ceilings do
    :jido_code
    |> Application.get_env(:fleet_runtime_ceilings, @default_ceilings)
    |> Map.new()
  end

  defp normalize_legacy_limits(limits) do
    concurrency =
      limits
      |> Map.get(:concurrency, %{})
      |> Map.new()
      |> Map.merge(Map.take(limits, @concurrency_dimensions))

    limits
    |> Map.drop(@concurrency_dimensions)
    |> Map.put(:concurrency, concurrency)
    |> rename(:risk, :max_risk)
  end

  defp rename(map, old, new) do
    case Map.pop(map, old) do
      {nil, map} -> map
      {value, map} -> Map.put_new(map, new, value)
    end
  end

  defp complete_and_validate(values) do
    complete =
      @default_ceilings
      |> Map.merge(values)
      |> Map.update!(:concurrency, &Map.merge(@default_ceilings.concurrency, Map.new(&1)))

    valid_concurrency? =
      Map.keys(complete.concurrency) |> Enum.sort() == Enum.sort(@concurrency_dimensions) and
        Enum.all?(complete.concurrency, fn {_dimension, value} ->
          is_integer(value) and value in 1..1_000
        end)

    valid_bounds? =
      Enum.all?(@bounded_fields, fn field ->
        value = complete[field]
        is_integer(value) and value >= 0 and value <= @maximums[field]
      end)

    if valid_concurrency? and valid_bounds? and complete.max_candidates > 0 and
         complete.max_campaign_repositories > 0 and complete.rate_units > 0 and
         complete.budget_units > 0 do
      {:ok, complete}
    else
      {:error, Error.new(:invalid_input, :fleet_policy)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :fleet_policy)}
  end

  defp validate_keys(values) do
    allowed =
      [:concurrency, :policy_revision, :risk] ++ @concurrency_dimensions ++ @bounded_fields

    if Map.keys(values) -- allowed == [],
      do: :ok,
      else: {:error, Error.new(:invalid_input, :fleet_policy)}
  end

  defp narrow_concurrency(requested, trusted) do
    Map.new(@concurrency_dimensions, fn dimension ->
      {dimension, min(requested[dimension], trusted[dimension])}
    end)
  end

  defp valid_revision(value) when is_integer(value) and value >= 0, do: value
  defp valid_revision(_value), do: nil
end
