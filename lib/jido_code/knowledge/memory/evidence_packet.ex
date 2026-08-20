defmodule JidoCode.Knowledge.Memory.EvidencePacket do
  @moduledoc """
  Bounded, source-linked, non-authoritative evidence supplied to a model.

  Packet payloads are structurally marked as data. Authority-bearing fields
  are rejected recursively, and exact retained content is represented only by
  a permit-requiring recovery handle.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Memory.RetrievalIndex
  alias JidoCode.Knowledge.Memory.RetrievalRanker
  alias JidoCode.Knowledge.Memory.RetrievalRequest
  alias JidoCode.Knowledge.ResourceIdentity

  @revision "1.0.0"
  @enforce_keys [
    :iri,
    :digest,
    :request_iri,
    :partition_digest,
    :query_version,
    :ranking_version,
    :index_version,
    :items,
    :omissions,
    :usage,
    :non_authoritative?
  ]
  defstruct @enforce_keys ++ [revision: @revision]

  @type t :: %__MODULE__{}
  @forbidden_keys ~w[
    instruction system_instruction tool tools capability capabilities credential credentials
    policy approval destination durable_write write_authority command authorization
  ]
  @spec revision() :: String.t()
  def revision, do: @revision

  @spec build(RetrievalRequest.t(), [map()]) :: {:ok, t()} | {:error, Error.t()}
  def build(%RetrievalRequest{} = request, ranked) when is_list(ranked) do
    with true <- Enum.all?(ranked, &valid_candidate?/1),
         {:ok, selected, omissions, usage} <- select(ranked, request.budgets),
         items <- Enum.map(selected, &item/1),
         digest <-
           digest({
             request.iri,
             request.partition.partition_digest,
             request.query_version,
             @revision,
             RetrievalRanker.revision(),
             RetrievalIndex.revision(),
             items,
             omissions,
             usage
           }),
         {:ok, iri} <- ResourceIdentity.deterministic(:memory_evidence_packet, digest) do
      {:ok,
       %__MODULE__{
         iri: iri,
         digest: digest,
         request_iri: request.iri,
         partition_digest: request.partition.partition_digest,
         revision: @revision,
         query_version: request.query_version,
         ranking_version: RetrievalRanker.revision(),
         index_version: RetrievalIndex.revision(),
         items: items,
         omissions: omissions,
         usage: usage,
         non_authoritative?: true
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def build(_request, _ranked), do: invalid()

  defp select(candidates, budgets) do
    initial = %{items: 0, graphs: MapSet.new(), bytes: 0, tokens: 0, time_ms: 0}

    {selected, omitted, usage} =
      Enum.reduce(candidates, {[], [], initial}, fn candidate, {selected, omitted, usage} ->
        next_graphs = MapSet.put(usage.graphs, candidate.source_graph_iri)
        bytes = candidate.payload_bytes
        tokens = candidate.estimated_tokens
        time_ms = candidate.retrieval_time_ms

        reason =
          cond do
            usage.items + 1 > budgets.item_limit -> :item_budget
            MapSet.size(next_graphs) > budgets.graph_limit -> :graph_budget
            usage.bytes + bytes > budgets.byte_limit -> :byte_budget
            usage.tokens + tokens > budgets.token_limit -> :token_budget
            usage.time_ms + time_ms > budgets.time_limit_ms -> :time_budget
            true -> nil
          end

        if is_nil(reason) do
          {[candidate | selected], omitted,
           %{
             items: usage.items + 1,
             graphs: next_graphs,
             bytes: usage.bytes + bytes,
             tokens: usage.tokens + tokens,
             time_ms: usage.time_ms + time_ms
           }}
        else
          {selected, [%{iri: candidate.iri, reason: reason} | omitted], usage}
        end
      end)

    usage = Map.put(usage, :graphs, MapSet.size(usage.graphs))
    {:ok, Enum.reverse(selected), Enum.reverse(omitted), usage}
  end

  defp item(candidate) do
    %{
      iri: candidate.iri,
      selection_reason: candidate.rank.selection_reason,
      source_iri: candidate.source_iri,
      temporal_scope: %{
        recorded_at: DateTime.to_iso8601(candidate.recorded_at),
        effective_at: candidate[:effective_at] && DateTime.to_iso8601(candidate.effective_at)
      },
      classification: candidate.classification,
      trust: candidate.trust,
      evidence_strength: candidate.evidence_strength,
      freshness: candidate.freshness,
      limitations: candidate.limitations,
      contradiction: candidate.contradiction,
      applicability: candidate.applicability,
      recovery_handle: %{
        source_iri: candidate.source_iri,
        graph_iri: candidate.source_graph_iri,
        graph_revision: candidate.source_revision,
        exact_content_permit_required?: candidate.exact_content?
      },
      payload: %{kind: :non_instructional_data, value: candidate.payload},
      authority?: false
    }
  end

  defp valid_candidate?(candidate) when is_map(candidate) do
    required = ~w[
      iri source_iri source_graph_iri source_revision recorded_at classification trust
      evidence_strength freshness limitations contradiction applicability exact_content? payload
      payload_bytes estimated_tokens retrieval_time_ms rank
    ]a

    Enum.all?(required, &Map.has_key?(candidate, &1)) and
      is_map(candidate.rank) and is_number(candidate.rank[:score]) and
      is_integer(candidate.payload_bytes) and candidate.payload_bytes > 0 and
      is_integer(candidate.estimated_tokens) and candidate.estimated_tokens >= 0 and
      is_integer(candidate.retrieval_time_ms) and candidate.retrieval_time_ms >= 0 and
      not authority_bearing?(candidate.payload)
  end

  defp valid_candidate?(_candidate), do: false

  defp authority_bearing?(value) when is_map(value) do
    Enum.any?(value, fn {key, nested} ->
      normalized = key |> to_string() |> String.downcase()
      normalized in @forbidden_keys or authority_bearing?(nested)
    end)
  end

  defp authority_bearing?(value) when is_list(value), do: Enum.any?(value, &authority_bearing?/1)
  defp authority_bearing?(_value), do: false

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid, do: {:error, Error.new(:invalid_input, :memory_evidence_packet)}
end
