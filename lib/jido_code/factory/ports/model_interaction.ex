defmodule JidoCode.Factory.Ports.ModelInteraction do
  @moduledoc """
  Narrow provider boundary for exactly one buffered call or stream start.

  Implementations normalize buffered responses and errors. Stream handles are
  opaque and remain owned by the adapter until the supervised stream contract
  consumes and closes them.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.Dispatch
  alias JidoCode.Factory.Model.Response

  @callback generate(adapter :: term(), Dispatch.t()) ::
              {:ok, Response.t()} | {:error, AdapterError.t()}

  @callback stream(adapter :: term(), Dispatch.t()) ::
              {:ok, handle :: term()} | {:error, AdapterError.t()}
end
