defmodule JidoCode.Knowledge.RepositoryWiki.ContextProfile do
  @moduledoc """
  Closed V1 profile for selecting repository-wiki fragments as agent context.

  The profile is application-owned configuration. Repository or graph data can
  refer to its key and digest, but cannot change page eligibility, ranking,
  budgets, authority labels, or freshness requirements.
  """

  alias JidoCode.Knowledge.RepositoryWiki.Contract

  @revision "wiki-context-deterministic/1.0.0"
  @page_classes %{
    overview: [:home, :project_overview, :about_this_wiki],
    architecture: [:architecture_overview, :module, :runtime, :data_flow],
    project: [:operations, :security, :release, :changelog, :glossary, :reference],
    dependencies: [:dependency_overview, :dependency, :dependency_gap],
    guides: [
      :guide_index,
      :user_guide,
      :developer_guide,
      :operator_guide,
      :contributor_guide,
      :upgrade_guide,
      :release_guide,
      :adr_index,
      :adr,
      :research_note
    ],
    source: [:source_area, :test_area],
    known_gaps: [:known_gap]
  }
  @class_limits %{
    overview: 4,
    architecture: 12,
    project: 8,
    dependencies: 16,
    guides: 12,
    source: 8,
    known_gaps: 8
  }
  @ranking %{
    direct_task_or_source: 1_000,
    current_repository_wiki: 700,
    accepted_memory: 500,
    lower_confidence_summary: 300,
    known_gap_bonus: 80,
    authored_bonus: 40,
    contradiction_bonus: 20
  }

  @enforce_keys [
    :key,
    :digest,
    :eligible_page_classes,
    :eligible_page_kinds,
    :class_limits,
    :freshness,
    :minimum_confidence_basis_points,
    :maximum_fragments,
    :maximum_fragment_bytes,
    :maximum_bytes,
    :maximum_estimated_tokens,
    :ranking,
    :source_labels,
    :preview_context?,
    :authority?
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec profile() :: t()
  def profile do
    material = %{
      key: @revision,
      eligible_page_classes: Map.keys(@page_classes) |> Enum.sort(),
      eligible_page_kinds: @page_classes |> Map.values() |> List.flatten() |> Enum.sort(),
      class_limits: @class_limits,
      freshness: :current,
      minimum_confidence_basis_points: 7_000,
      maximum_fragments: 64,
      maximum_fragment_bytes: 8_192,
      maximum_bytes: 65_536,
      maximum_estimated_tokens: 16_384,
      ranking: @ranking,
      source_labels: [:authored, :deterministic, :gap],
      preview_context?: false,
      authority?: false
    }

    struct!(__MODULE__, Map.put(material, :digest, Contract.digest(material)))
  end

  @spec valid?(term()) :: boolean()
  def valid?(%__MODULE__{} = profile), do: profile == profile()
  def valid?(_profile), do: false

  @spec page_class(atom()) :: {:ok, atom()} | :error
  def page_class(kind) when is_atom(kind) do
    Enum.find_value(@page_classes, :error, fn {class, kinds} ->
      if kind in kinds, do: {:ok, class}
    end)
  end

  def page_class(_kind), do: :error

  @spec class_limit(t(), atom()) :: non_neg_integer()
  def class_limit(%__MODULE__{} = profile, page_class),
    do: Map.get(profile.class_limits, page_class, 0)
end
