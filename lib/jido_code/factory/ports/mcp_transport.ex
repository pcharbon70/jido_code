defmodule JidoCode.Factory.Ports.MCPTransport do
  @moduledoc """
  Trusted MCP transport boundary.

  The transport receives a validated call containing only broker references,
  never bearer-token material, and returns an external reference plus digests.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Extensions.MCP.Call

  @callback identity(term()) ::
              {:ok, %{identity: String.t(), digest: String.t()}}
              | {:error, AdapterError.t()}

  @callback invoke(term(), Call.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end
