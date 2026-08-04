defmodule JidoCode.Capacity do
  @moduledoc "Supported fleet workload profiles and fail-closed capacity admission."

  alias JidoCode.Knowledge.Error

  @dimensions [
    :repositories,
    :snapshots,
    :source_symbols,
    :observations,
    :goals_tasks,
    :runs,
    :evidence,
    :memory_assertions,
    :audit_statements,
    :derived_statements
  ]
  @maximum %{
    repositories: 500,
    snapshots: 50_000,
    source_symbols: 250_000,
    observations: 1_000_000,
    goals_tasks: 50_000,
    runs: 100_000,
    evidence: 500_000,
    memory_assertions: 100_000,
    audit_statements: 1_000_000,
    derived_statements: 500_000
  }
  @profiles %{
    small: %{
      repositories: 10,
      snapshots: 200,
      source_symbols: 5_000,
      observations: 10_000,
      goals_tasks: 500,
      runs: 1_000,
      evidence: 5_000,
      memory_assertions: 1_000,
      audit_statements: 10_000,
      derived_statements: 5_000
    },
    medium: %{
      repositories: 100,
      snapshots: 10_000,
      source_symbols: 75_000,
      observations: 250_000,
      goals_tasks: 10_000,
      runs: 20_000,
      evidence: 100_000,
      memory_assertions: 20_000,
      audit_statements: 250_000,
      derived_statements: 100_000
    },
    maximum: @maximum
  }

  @spec dimensions() :: [atom()]
  def dimensions, do: @dimensions

  @spec profile(:small | :medium | :maximum) :: {:ok, map()} | {:error, Error.t()}
  def profile(name) when is_atom(name) do
    case Map.fetch(@profiles, name) do
      {:ok, workload} -> {:ok, workload}
      :error -> {:error, Error.new(:invalid_input, :capacity_profile)}
    end
  end

  @spec maximum() :: map()
  def maximum, do: @maximum

  @spec admit(map()) :: {:ok, map()} | {:error, Error.t()}
  def admit(workload) when is_map(workload) do
    with true <- Map.keys(workload) |> Enum.sort() == Enum.sort(@dimensions),
         true <- Enum.all?(workload, fn {_key, value} -> is_integer(value) and value >= 0 end),
         [] <- exceeded(workload) do
      pressure = if soft_limit?(workload), do: :soft_limit, else: :normal

      {:ok,
       %{state: :supported, pressure: pressure, pagination_required?: pressure == :soft_limit}}
    else
      exceeded when is_list(exceeded) and exceeded != [] ->
        {:error, Error.new(:conflict, :capacity_limit)}

      _invalid ->
        {:error, Error.new(:invalid_input, :capacity_workload)}
    end
  end

  def admit(_workload), do: {:error, Error.new(:invalid_input, :capacity_workload)}

  @spec limits() :: map()
  def limits do
    %{
      hard: @maximum,
      soft_ratio: 0.8,
      query_timeout_ms: 5_000,
      maintenance_timeout_ms: 120_000,
      page_size: 100,
      maximum_page_size: 500,
      scheduling_candidates: 1_000,
      retention_removals_per_commit: 900,
      degraded_claim: :stale_or_incomplete
    }
  end

  defp exceeded(workload) do
    Enum.flat_map(@dimensions, fn dimension ->
      if workload[dimension] > @maximum[dimension], do: [dimension], else: []
    end)
  end

  defp soft_limit?(workload) do
    Enum.any?(@dimensions, fn dimension -> workload[dimension] >= @maximum[dimension] * 0.8 end)
  end
end
