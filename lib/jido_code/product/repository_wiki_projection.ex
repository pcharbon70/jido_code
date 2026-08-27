defmodule JidoCode.Product.RepositoryWikiProjection do
  @moduledoc """
  Transient browser-safe repository wiki projection.

  It is reconstructed from reviewed graph queries. Navigation and search data
  are disposable and never act as edition, enrollment, or authorization state.
  """

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
end
