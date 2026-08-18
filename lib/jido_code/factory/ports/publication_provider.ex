defmodule JidoCode.Factory.Ports.PublicationProvider do
  @moduledoc "Trusted compare-and-swap branch and pull-request publication boundary."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Publication.Request

  @callback capabilities(term(), Request.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback compare_and_swap_branch(term(), Request.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
  @callback open_or_update_pull_request(term(), Request.t(), map(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end
