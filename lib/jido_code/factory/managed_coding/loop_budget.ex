defmodule JidoCode.Factory.ManagedCoding.LoopBudget do
  @moduledoc "Persistable observations and pre-effect enforcement for a bounded coding loop."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Budget

  @enforce_keys [:dimensions, :unavailable, :observed_only]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Budget.t(), keyword()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(budget, options \\ [])

  def new(%Budget{} = budget, options) when is_list(options) do
    checks_limit = Keyword.get(options, :checks_limit, 1)

    with true <- is_integer(checks_limit) and checks_limit > 0 do
      dimensions =
        Budget.dimensions()
        |> Map.new(fn dimension ->
          limit = Budget.limit(budget, dimension)
          {dimension, %{used: 0, limit: limit.limit, enforcement: limit.enforcement}}
        end)
        |> Map.put(:checks, %{used: 0, limit: checks_limit, enforcement: :hard})

      {:ok, %__MODULE__{dimensions: dimensions, unavailable: [], observed_only: []}}
    else
      _invalid -> invalid()
    end
  end

  def new(_budget, _options), do: invalid()

  @spec before_effect(t(), map()) :: {:ok, t()} | {:stop, atom(), t()}
  def before_effect(%__MODULE__{} = budget, deltas) when is_map(deltas) do
    with :ok <- validate_deltas(budget, deltas) do
      case Enum.find(deltas, fn {dimension, delta} -> exhausted?(budget, dimension, delta) end) do
        {dimension, _delta} -> {:stop, dimension, budget}
        nil -> {:ok, add(budget, deltas, [:hard])}
      end
    else
      _invalid -> {:stop, :invalid_observation, budget}
    end
  end

  def before_effect(%__MODULE__{} = budget, _deltas),
    do: {:stop, :invalid_observation, budget}

  @spec after_effect(t(), map(), keyword()) :: {:ok, t()} | {:error, AdapterError.t()}
  def after_effect(budget, observations, options \\ [])

  def after_effect(%__MODULE__{} = budget, observations, options)
      when is_map(observations) and is_list(options) do
    unavailable = Keyword.get(options, :unavailable, [])
    observed_only = Keyword.get(options, :observed_only, [])

    with :ok <- validate_deltas(budget, observations),
         true <- valid_labels?(budget, unavailable),
         true <- valid_labels?(budget, observed_only) do
      {:ok,
       budget
       |> add(observations, [:next_effect, :observed_only])
       |> Map.update!(:unavailable, &Enum.sort(Enum.uniq(&1 ++ unavailable)))
       |> Map.update!(:observed_only, &Enum.sort(Enum.uniq(&1 ++ observed_only)))}
    else
      _invalid -> invalid()
    end
  end

  def after_effect(_budget, _observations, _options), do: invalid()

  @spec snapshot(t()) :: map()
  def snapshot(%__MODULE__{} = budget), do: budget.dimensions

  defp exhausted?(budget, dimension, delta) do
    %{used: used, limit: limit, enforcement: enforcement} = budget.dimensions[dimension]

    case enforcement do
      :hard -> used + delta > limit
      :next_effect -> used >= limit
      :observed_only -> false
      :unavailable -> true
    end
  end

  defp add(budget, deltas, classes) do
    dimensions =
      Enum.reduce(deltas, budget.dimensions, fn {dimension, delta}, current ->
        if current[dimension].enforcement in classes,
          do: update_in(current, [dimension, :used], &(&1 + delta)),
          else: current
      end)

    %{budget | dimensions: dimensions}
  end

  defp validate_deltas(budget, deltas) do
    if Enum.all?(deltas, fn {dimension, delta} ->
         Map.has_key?(budget.dimensions, dimension) and is_integer(delta) and delta >= 0
       end),
       do: :ok,
       else: :error
  end

  defp valid_labels?(budget, labels) when is_list(labels) do
    Enum.all?(labels, &(is_atom(&1) and Map.has_key?(budget.dimensions, &1)))
  end

  defp valid_labels?(_budget, _labels), do: false
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_loop_budget)}
end
