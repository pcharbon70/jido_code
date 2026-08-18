defmodule JidoCode.Factory.Ports.ExternalOutcomeObserver do
  @moduledoc "Trusted provider observation boundary after publication."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Publication.Result

  @callback observe(term(), Result.t(), keyword()) ::
              {:ok, map()} | {:error, AdapterError.t()}
end
