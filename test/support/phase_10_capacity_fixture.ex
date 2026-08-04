defmodule JidoCode.TestSupport.Phase10CapacityFixture do
  @moduledoc false

  alias JidoCode.Capacity

  def workload!(profile) do
    {:ok, workload} = Capacity.profile(profile)

    %{
      profile: profile,
      counts: workload,
      repositories: sample("repository", workload.repositories),
      snapshots: sample("snapshot", workload.snapshots),
      source_symbols: sample("symbol", workload.source_symbols),
      observations: sample("observation", workload.observations),
      goals_tasks: sample("goal-task", workload.goals_tasks),
      runs: sample("run", workload.runs),
      evidence: sample("evidence", workload.evidence),
      memory: sample("memory", workload.memory_assertions),
      audit: sample("audit", workload.audit_statements),
      derived: sample("derived", workload.derived_statements)
    }
  end

  defp sample(kind, logical_count) do
    for index <- 1..min(logical_count, 100) do
      %{iri: "https://jido.run/id/#{kind}/#{index}", logical_count: logical_count}
    end
  end
end
