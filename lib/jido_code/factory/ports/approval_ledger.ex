defmodule JidoCode.Factory.Ports.ApprovalLedger do
  @moduledoc "Accepted command boundary for atomic approval consumption and outcomes."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Approval.Request

  @callback consume(term(), Request.t(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback terminal(term(), map(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback ambiguous(term(), map(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end
