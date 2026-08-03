defmodule JidoCode.Factory.Ports.ExecutionAuthority do
  @moduledoc "Fail-closed authorization callback evaluated immediately before a runtime effect."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request

  @callback authorize(atom(), Request.t(), keyword()) :: :ok | {:error, AdapterError.t()}
end
