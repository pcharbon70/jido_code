defmodule JidoCode.Factory.Ports.ManagedCodingDraftPublisher do
  @moduledoc "Authorized draft branch and pull-request publication boundary."

  alias JidoCode.Factory.AdapterError

  @callback create_draft(term(), map(), keyword()) :: {:ok, map()} | {:error, AdapterError.t()}
end
