defmodule JidoCode.Factory.Ports.ApprovedEffect do
  @moduledoc "Trusted effect boundary for an already consumed human approval."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Approval.Request

  @callback execute(term(), Request.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end
