defmodule JidoCode.TestSupport.AllowExecutionAuthority do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ExecutionAuthority

  alias JidoCode.Factory.AdapterError

  @impl true
  def authorize(operation, _request, options) do
    if Keyword.get(options, :authorized?, true),
      do: :ok,
      else: {:error, AdapterError.new(:unauthorized, operation)}
  end
end
