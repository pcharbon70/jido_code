defmodule JidoCode.Knowledge.IntegrityReport do
  @moduledoc """
  Bounded projection of graph-store integrity without graph content.
  """

  alias JidoCode.Knowledge.IntegrityIssue

  @enforce_keys [:status, :dataset_revision, :graph_count, :quad_count, :issues]
  defstruct [:status, :dataset_revision, :graph_count, :quad_count, :issues]

  @type t :: %__MODULE__{
          status: :ok | :error,
          dataset_revision: non_neg_integer() | nil,
          graph_count: non_neg_integer(),
          quad_count: non_neg_integer(),
          issues: [IntegrityIssue.t()]
        }

  @spec healthy?(t()) :: boolean()
  def healthy?(%__MODULE__{status: :ok, issues: []}), do: true
  def healthy?(%__MODULE__{}), do: false
end
