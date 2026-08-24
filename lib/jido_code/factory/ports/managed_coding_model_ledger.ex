defmodule JidoCode.Factory.Ports.ManagedCodingModelLedger do
  @moduledoc "Durable accounting seam surrounding one managed coding model invocation."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.Request

  @callback start(term(), map(), Request.t()) ::
              {:ok, term()} | {:error, AdapterError.t()}

  @callback outcome(term(), term(), map()) ::
              :ok | {:error, AdapterError.t()}
end
