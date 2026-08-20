defmodule JidoCode.Knowledge.Memory.RetrievalIndex do
  @moduledoc """
  Disposable, deterministic projection for one authorized candidate channel.

  Index identity contains the complete authorization partition. The graph
  remains authoritative: deleting and rebuilding an index from the same
  eligible source candidates yields the same digest and results.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.CandidateAccess
  alias JidoCode.Knowledge.Memory.RetrievalRequest

  @enforce_keys [
    :channel,
    :revision,
    :partition_digest,
    :effective_time_generation,
    :erasure_generation,
    :entries,
    :digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @revision "1.0.0"

  @spec revision() :: String.t()
  def revision, do: @revision

  @spec build(RetrievalRequest.t(), atom(), (map() -> {:ok, [map()]})) ::
          {:ok, t(), map()} | {:error, Error.t()}
  def build(%RetrievalRequest{} = request, channel, generator) do
    with {:ok, result} <- CandidateAccess.generate(request, channel, generator) do
      entries = Enum.sort_by(result.candidates, & &1.iri)

      index = %__MODULE__{
        channel: channel,
        revision: @revision,
        partition_digest: request.partition.partition_digest,
        effective_time_generation: request.partition.effective_time_generation,
        erasure_generation: request.partition.erasure_generation,
        entries: entries,
        digest: digest({channel, @revision, request.partition.partition_digest, entries})
      }

      {:ok, index, Map.drop(result, [:candidates])}
    end
  end

  @spec lookup(t(), RetrievalRequest.t()) :: {:ok, [map()]} | {:error, Error.t()}
  def lookup(%__MODULE__{} = index, %RetrievalRequest{} = request) do
    if index.partition_digest == request.partition.partition_digest and
         index.effective_time_generation == request.partition.effective_time_generation and
         index.erasure_generation == request.partition.erasure_generation and
         index.digest ==
           digest({index.channel, index.revision, index.partition_digest, index.entries}) do
      {:ok, index.entries}
    else
      {:error, Error.new(:stale_precondition, :memory_retrieval_index)}
    end
  end

  def lookup(_index, _request),
    do: {:error, Error.new(:invalid_input, :memory_retrieval_index)}

  @spec drop(t()) :: :ok
  def drop(%__MODULE__{}), do: :ok

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
