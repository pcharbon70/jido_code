defmodule JidoCode.Knowledge.RepositoryWiki.Vocabulary do
  @moduledoc """
  Closed semantic vocabulary for repository-wiki protocol `1.0.0`.

  Values are executable application configuration. Repository, graph, browser,
  and model input can select only a value already present in this module.
  """

  @protocol_version "1.0.0"

  @values %{
    enrollment_state: ~w[off manual automatic]a,
    generation_profile: ~w[manual_deterministic automatic_deterministic]a,
    generation_mode: ~w[deterministic_only synthesis_allowed]a,
    preview_mode: ~w[disabled allowed]a,
    edition_state: ~w[
      building finalized linted closed incomplete stale invalidated superseded
    ]a,
    edition_purpose: ~w[current release candidate_preview recovery]a,
    freshness: ~w[current stale unknown]a,
    completeness: ~w[building complete incomplete]a,
    source_kind: ~w[
      repository_file source_graph control_graph decision_graph memory_graph
      policy_graph ontology_graph artifact_manifest external_observation
    ]a,
    authority_class: ~w[authored deterministic synthesized live_panel gap]a,
    retention_class: ~w[
      current superseded preview incomplete invalid source_snapshot render_artifact accounting audit
    ]a,
    accounting_state: ~w[
      reserved consumed released rejected success failed cancelled timed_out usage_pending usage_unknown
    ]a,
    maintainer_state: ~w[disabled idle admitted running cancelling failed stopped]a,
    page_kind: ~w[
      home project_overview architecture_overview module runtime data_flow source_area test_area
      dependency_overview dependency dependency_gap guide_index user_guide developer_guide
      operator_guide contributor_guide upgrade_guide release_guide adr_index adr research_note
      operations security release changelog glossary reference known_gap about_this_wiki
    ]a,
    link_kind: ~w[
      contains explains depends_on used_by implements documents supersedes related backlink
    ]a,
    gap_kind: ~w[
      absent unavailable unsupported contradictory incomplete unauthorized truncated changed_during_read
    ]a,
    update_reason: ~w[
      manual source_changed documentation_changed manifest_changed lock_changed policy_changed
      compiler_changed recovery metadata_refresh
    ]a
  }

  @spec protocol_version() :: String.t()
  def protocol_version, do: @protocol_version

  @spec dimensions() :: [atom()]
  def dimensions, do: @values |> Map.keys() |> Enum.sort()

  @spec values(atom()) :: {:ok, [atom()]} | :error
  def values(dimension) when is_atom(dimension), do: Map.fetch(@values, dimension)
  def values(_dimension), do: :error

  @spec valid?(atom(), atom()) :: boolean()
  def valid?(dimension, value) when is_atom(dimension) and is_atom(value) do
    case values(dimension) do
      {:ok, allowed} -> value in allowed
      :error -> false
    end
  end

  def valid?(_dimension, _value), do: false
end
