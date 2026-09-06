defmodule JidoCode.TestSupport.HypermediaUIPhaseC4Fixture do
  @moduledoc false

  alias JidoCode.Product.ReadProjection

  def projection(surface, overrides \\ %{}) do
    base = %{
      surface: surface,
      state: :ready,
      source_outcome: :ready,
      query_version: "2.11.0",
      dataset_revision: 77,
      source_revision_count: 3,
      generated_at: ~U[2026-09-06 00:00:00Z],
      freshness: :current,
      complete?: true,
      truncated?: false,
      attention: [],
      attention_families: [],
      health: [],
      fleet: [],
      projects: [],
      project: nil,
      attempts: [],
      wiki: nil,
      dependencies: [],
      attempt: nil,
      summaries: %{},
      capabilities: [],
      warnings: [],
      pagination: %{
        page: 1,
        page_size: 20,
        known_total: 0,
        page_count: 1,
        previous_href: nil,
        next_href: nil,
        summary: "Page 1 of 1; 0 authorized rows"
      },
      cache: %{status: :bypass}
    }

    base |> Map.merge(overrides) |> ReadProjection.new!()
  end

  def fleet_row(label, href, overrides \\ %{}) do
    Map.merge(
      %{
        project: label,
        project_href: href,
        work: "1 running · 0 blocked · 0 awaiting",
        agent: "Managed coding profile",
        stage: "Running",
        health: "Current",
        health_state: :ready,
        freshness: "Current"
      },
      overrides
    )
  end
end
