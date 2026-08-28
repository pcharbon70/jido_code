defmodule JidoCode.Product.RepositoryWikiProjection do
  @moduledoc """
  Transient browser-safe repository wiki projection.

  It is reconstructed from reviewed graph queries. Navigation and search data
  are disposable and never act as edition, enrollment, or authorization state.
  """

  alias JidoCode.Product.RepositoryWikiOperationsProjection

  @enforce_keys [
    :state,
    :visible?,
    :repository_iri,
    :dataset_revision,
    :enrollment,
    :edition,
    :navigation,
    :selected_page,
    :backlinks,
    :sources,
    :gaps,
    :history,
    :search_results,
    :usage,
    :operations,
    :settings,
    :warnings
  ]
  defstruct @enforce_keys

  @type state ::
          :unselected
          | :hidden
          | :disabled
          | :empty
          | :current
          | :stale
          | :incomplete
          | :failed
          | :rebuilding
          | :preview
          | :unauthorized
          | :unavailable

  @type t :: %__MODULE__{}

  @spec unavailable(state(), String.t() | nil) :: t()
  def unavailable(state \\ :unavailable, repository_iri \\ nil)
      when state in [:unselected, :hidden, :disabled, :unauthorized, :unavailable] do
    %__MODULE__{
      state: state,
      visible?: false,
      repository_iri: repository_iri,
      dataset_revision: nil,
      enrollment: nil,
      edition: nil,
      navigation: [],
      selected_page: nil,
      backlinks: [],
      sources: [],
      gaps: [],
      history: [],
      search_results: [],
      usage: RepositoryWikiOperationsProjection.empty(repository_iri, state),
      operations: default_operations(state),
      settings: default_settings(),
      warnings: [Atom.to_string(state)]
    }
  end

  @spec default_settings() :: map()
  def default_settings do
    %{
      mode: :off,
      read_visibility: :hidden,
      retention: :standard,
      generation_mode: :deterministic_only,
      token_posture: :zero_model_tokens,
      regeneration_available?: false
    }
  end

  @spec default_operations(atom()) :: map()
  def default_operations(state \\ :unavailable) do
    %{
      state: state,
      repository_count: 0,
      current_count: 0,
      stale_count: 0,
      queue_pending: 0,
      queue_active: 0,
      reservations_live: 0,
      usage_pending: 0,
      usage_unknown: 0,
      retained_bytes: 0,
      alert_count: 0,
      repositories: [],
      alerts: []
    }
  end
end
