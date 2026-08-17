defmodule JidoCode.Factory.Ports.EgressResolver do
  @moduledoc "Attested resolver port used by the egress broker."

  alias JidoCode.Factory.AdapterError

  @callback identity(term()) :: {:ok, map()} | {:error, AdapterError.t()}
  @callback resolve(term(), String.t()) ::
              {:ok, [tuple() | String.t()]} | {:error, AdapterError.t()}
end
