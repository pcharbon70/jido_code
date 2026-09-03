defmodule JidoCodeWeb.ArchitectureFixture.DirectRuntime do
  def cancel(attempt), do: JidoCode.Runtime.cancel(attempt)
end
