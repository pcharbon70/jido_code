defmodule JidoCode.Factory.Ports.ToolLedger do
  @moduledoc "Durable start/outcome port used by the tool reference monitor."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Authorization
  alias JidoCode.Factory.Tool.Request
  alias JidoCode.Factory.Tool.Result
  alias JidoCode.Factory.Tool.StartReceipt

  @callback start(term(), Authorization.t(), Request.t()) ::
              {:ok, StartReceipt.t()} | {:error, AdapterError.t()}

  @callback outcome(term(), StartReceipt.t(), Result.t()) ::
              {:ok, term()} | {:error, AdapterError.t()}
end
