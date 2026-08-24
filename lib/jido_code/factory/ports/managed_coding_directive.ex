defmodule JidoCode.Factory.Ports.ManagedCodingDirective do
  @moduledoc "Host-selected effect executor for one closed managed coding directive kind."

  alias JidoCode.Factory.AdapterError

  @callback execute(term(), term(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end
