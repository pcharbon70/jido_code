defmodule JidoCode.Knowledge.WriteReceipt do
  @moduledoc """
  Bounded projection of an immutable commit receipt stored in the graph.
  """

  @enforce_keys [
    :commit_id,
    :batch_digest,
    :prior_dataset_revision,
    :dataset_revision,
    :graph_revisions,
    :additions_count,
    :removals_count,
    :durability,
    :replayed?
  ]
  defstruct [
    :commit_id,
    :batch_digest,
    :prior_dataset_revision,
    :dataset_revision,
    :graph_revisions,
    :additions_count,
    :removals_count,
    :durability,
    :replayed?
  ]

  @type graph_revision :: %{prior: non_neg_integer(), new: non_neg_integer()}

  @type t :: %__MODULE__{
          commit_id: String.t(),
          batch_digest: String.t(),
          prior_dataset_revision: non_neg_integer(),
          dataset_revision: non_neg_integer(),
          graph_revisions: %{String.t() => graph_revision()},
          additions_count: non_neg_integer(),
          removals_count: non_neg_integer(),
          durability: :sync,
          replayed?: boolean()
        }

  def replayed(%__MODULE__{} = receipt), do: %{receipt | replayed?: true}
end
