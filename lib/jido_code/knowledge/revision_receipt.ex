defmodule JidoCode.Knowledge.RevisionReceipt do
  @moduledoc """
  Bounded current-revision evidence returned for a stale write.
  """

  @enforce_keys [:dataset_revision, :graph_revisions]
  defstruct [:dataset_revision, :graph_revisions]

  @type t :: %__MODULE__{
          dataset_revision: non_neg_integer(),
          graph_revisions: %{String.t() => non_neg_integer()}
        }
end
