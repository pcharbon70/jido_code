defmodule JidoCode.Knowledge.Memory.RetrievalPipeline do
  @moduledoc "Authorization-first hybrid retrieval and bounded packet assembly."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.CandidateAccess
  alias JidoCode.Knowledge.Memory.DenseRetrieval
  alias JidoCode.Knowledge.Memory.EvidencePacket
  alias JidoCode.Knowledge.Memory.RetrievalRanker
  alias JidoCode.Knowledge.Memory.RetrievalRequest

  @channels ~w[exact_identifier lexical temporal_graph failure_signature recency current_state]a

  @spec retrieve(RetrievalRequest.t(), map()) :: {:ok, map()} | {:error, Error.t()}
  def retrieve(%RetrievalRequest{} = request, generators) when is_map(generators) do
    with true <- map_size(generators) > 0,
         true <- Enum.all?(Map.keys(generators), &(&1 in @channels)),
         {:ok, channel_results} <- generate(request, generators),
         candidates <- Enum.flat_map(channel_results, & &1.candidates),
         {:ok, ranked} <- RetrievalRanker.rank(request, candidates),
         {:ok, packet} <- EvidencePacket.build(request, ranked) do
      {:ok,
       %{
         packet: packet,
         channel_receipts: Enum.map(channel_results, &Map.drop(&1, [:candidates])),
         dense_retrieval_enabled?: DenseRetrieval.enabled?(),
         candidate_count: length(candidates),
         ranked_count: length(ranked)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:invalid_input, :memory_retrieval_pipeline)}
    end
  end

  def retrieve(_request, _generators),
    do: {:error, Error.new(:invalid_input, :memory_retrieval_pipeline)}

  defp generate(request, generators) do
    generators
    |> Enum.sort_by(fn {channel, _generator} -> Enum.find_index(@channels, &(&1 == channel)) end)
    |> Enum.reduce_while({:ok, []}, fn {channel, generator}, {:ok, results} ->
      case CandidateAccess.generate(request, channel, generator) do
        {:ok, result} -> {:cont, {:ok, [result | results]}}
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, results} -> {:ok, Enum.reverse(results)}
      error -> error
    end
  end
end
