defmodule JidoCode.Product.Projection do
  @moduledoc """
  Transient, browser-safe workbench projection.

  This value is rebuilt from reviewed graph queries. It is never persisted and
  has no command, authorization, or acceptance authority.
  """

  @enforce_keys [
    :state,
    :dataset_revision,
    :generated_at,
    :freshness,
    :complete?,
    :truncated?,
    :repositories,
    :work,
    :attempts,
    :outcomes,
    :knowledge,
    :warnings
  ]
  defstruct @enforce_keys

  @type state ::
          :ready
          | :empty
          | :stale
          | :incomplete
          | :contradicted
          | :truncated
          | :unauthorized
          | :unavailable
          | :maintenance
          | :recovery

  @type t :: %__MODULE__{}

  @spec unavailable(atom()) :: t()
  def unavailable(state \\ :unavailable)
      when state in [:unavailable, :maintenance, :recovery, :unauthorized] do
    %__MODULE__{
      state: state,
      dataset_revision: nil,
      generated_at: DateTime.utc_now() |> DateTime.truncate(:second),
      freshness: "unknown",
      complete?: false,
      truncated?: false,
      repositories: [],
      work: empty_work(),
      attempts: [],
      outcomes: empty_outcomes(),
      knowledge: [],
      warnings: [Atom.to_string(state)]
    }
  end

  @spec empty_work() :: map()
  def empty_work do
    %{eligible: [], blocked: [], executing: [], awaiting_decision: []}
  end

  @spec empty_outcomes() :: map()
  def empty_outcomes do
    %{evidence: [], decisions: [], follow_up: []}
  end
end
