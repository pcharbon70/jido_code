defmodule JidoCode.Product.CommandOutcome do
  @moduledoc """
  Transient outcome-safe product view of a semantic command receipt.
  """

  alias JidoCode.Knowledge.CommandReceipt

  @enforce_keys [:outcome, :retry, :dataset_revision]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec from_receipt(CommandReceipt.t()) :: t()
  def from_receipt(%CommandReceipt{} = receipt) do
    %__MODULE__{
      outcome: receipt.outcome,
      retry: receipt.retry,
      dataset_revision: receipt.dataset_revision
    }
  end
end
