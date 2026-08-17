defmodule JidoCode.Factory.Ports.EgressAudit do
  @moduledoc "Fail-closed sink for bounded egress decisions."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Egress.Decision

  @callback record(term(), Decision.t()) :: :ok | {:error, AdapterError.t()}
end
