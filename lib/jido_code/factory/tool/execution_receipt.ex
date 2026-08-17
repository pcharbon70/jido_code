defmodule JidoCode.Factory.Tool.ExecutionReceipt do
  @moduledoc "One durably recorded terminal tool result."

  alias JidoCode.Factory.Tool.Result
  alias JidoCode.Factory.Tool.StartReceipt

  @derive {Inspect, only: [:status, :effect_dispatched]}
  @enforce_keys [:status, :effect_dispatched, :result, :start_receipt, :outcome_receipt]
  defstruct @enforce_keys

  @type t :: %__MODULE__{result: Result.t(), start_receipt: StartReceipt.t()}
end
