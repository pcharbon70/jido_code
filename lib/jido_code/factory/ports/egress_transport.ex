defmodule JidoCode.Factory.Ports.EgressTransport do
  @moduledoc "Transport port that connects only to a broker-resolved endpoint."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Egress.Request

  @callback request(term(), Request.t(), map(), binary()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end
