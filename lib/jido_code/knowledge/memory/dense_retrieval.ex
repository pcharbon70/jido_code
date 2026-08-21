defmodule JidoCode.Knowledge.Memory.DenseRetrieval do
  @moduledoc """
  Port for a future evaluated dense-retrieval adapter.

  Phase 3 defines the seam but deliberately ships no enabled production
  adapter. Any future implementation must consume the authorization-derived
  partition and preserve source classification and erasure generation.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.RetrievalRequest

  @callback enabled?() :: boolean()
  @callback search(RetrievalRequest.t(), map()) :: {:ok, [map()]} | {:error, Error.t()}

  @spec enabled?() :: false
  def enabled?, do: false

  @spec search(RetrievalRequest.t(), map()) :: {:error, Error.t()}
  def search(%RetrievalRequest{}, _features),
    do: {:error, Error.new(:unauthorized, :dense_memory_retrieval)}

  def search(_request, _features),
    do: {:error, Error.new(:invalid_input, :dense_memory_retrieval)}
end
