defmodule JidoCode.Factory.Ports.Tool do
  @moduledoc "Effect-only tool adapter port without semantic command authority."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.Request
  alias JidoCode.Factory.Tool.Result

  @callback execute(term(), Request.t(), keyword()) ::
              {:ok, Result.t()} | {:error, AdapterError.t()}
end
