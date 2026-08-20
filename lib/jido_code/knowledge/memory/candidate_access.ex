defmodule JidoCode.Knowledge.Memory.CandidateAccess do
  @moduledoc """
  Authorization-first boundary for every memory candidate channel.

  The generator is called only with the request-derived partition. Ineligible
  records are removed here, before any ranking or packet assembly API can see
  them.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Memory.RetrievalRequest
  alias JidoCode.Knowledge.ResourceIdentity

  @channels ~w[exact_identifier lexical temporal_graph failure_signature recency current_state]a
  @max_candidates 1_000

  @spec generate(RetrievalRequest.t(), atom(), (map() -> {:ok, [map()]})) ::
          {:ok, map()} | {:error, Error.t()}
  def generate(%RetrievalRequest{} = request, channel, generator)
      when channel in @channels and is_function(generator, 1) do
    generator_input = %{
      partition_digest: request.partition.partition_digest,
      repository_iri: request.repository_iri,
      tenant_iri: request.tenant_iri,
      actor_scope_iri: request.actor_scope_iri,
      purpose: request.purpose,
      data_ceiling: request.data_ceiling,
      effective_at: request.effective_at,
      effective_time_generation: request.partition.effective_time_generation,
      erasure_generation: request.partition.erasure_generation
    }

    with {:ok, candidates} <- generator.(generator_input),
         true <- is_list(candidates) and length(candidates) <= @max_candidates,
         true <- Enum.all?(candidates, &valid_candidate?/1) do
      {eligible, omitted} = Enum.split_with(candidates, &eligible?(&1, request))

      {:ok,
       %{
         channel: channel,
         partition_digest: request.partition.partition_digest,
         candidates: eligible,
         omitted: omission_counts(omitted, request),
         inspected_count: length(candidates),
         eligible_count: length(eligible)
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def generate(_request, _channel, _generator), do: invalid()

  @spec channels() :: [atom()]
  def channels, do: @channels

  defp eligible?(candidate, request) do
    candidate.partition_digest == request.partition.partition_digest and
      candidate.repository_iri == request.repository_iri and
      candidate.tenant_iri == request.tenant_iri and
      candidate.actor_scope_iri == request.actor_scope_iri and
      candidate.purpose == request.purpose and
      candidate.classification in request.allowed_classifications and
      candidate.category in request.categories and candidate.trust in request.trust_levels and
      DateTime.compare(candidate.recorded_at, request.effective_at) in [:lt, :eq] and
      candidate.available? and not candidate.erased? and not candidate.invalidated? and
      candidate.compatible?
  end

  defp valid_candidate?(candidate) when is_map(candidate) do
    ResourceIdentity.validate(candidate[:iri]) == :ok and
      ResourceIdentity.validate(candidate[:source_iri]) == :ok and
      match?({:ok, _family}, GraphRegistry.identify(candidate[:source_graph_iri])) and
      is_integer(candidate[:source_revision]) and candidate.source_revision >= 0 and
      is_binary(candidate[:partition_digest]) and match?(%DateTime{}, candidate[:recorded_at]) and
      Enum.all?(~w[available? erased? invalidated? compatible?]a, &is_boolean(candidate[&1]))
  end

  defp valid_candidate?(_candidate), do: false

  defp omission_counts(candidates, request) do
    candidates
    |> Enum.flat_map(&reasons(&1, request))
    |> Enum.frequencies()
  end

  defp reasons(candidate, request) do
    []
    |> add(:partition, candidate.partition_digest != request.partition.partition_digest)
    |> add(:scope, candidate.repository_iri != request.repository_iri)
    |> add(:scope, candidate.tenant_iri != request.tenant_iri)
    |> add(:scope, candidate.actor_scope_iri != request.actor_scope_iri)
    |> add(:purpose, candidate.purpose != request.purpose)
    |> add(:classification, candidate.classification not in request.allowed_classifications)
    |> add(:category, candidate.category not in request.categories)
    |> add(:trust, candidate.trust not in request.trust_levels)
    |> add(:future, DateTime.compare(candidate.recorded_at, request.effective_at) == :gt)
    |> add(:unavailable, not candidate.available?)
    |> add(:erased, candidate.erased?)
    |> add(:invalidated, candidate.invalidated?)
    |> add(:incompatible, not candidate.compatible?)
  end

  defp add(values, _reason, false), do: values
  defp add(values, reason, true), do: [reason | values]
  defp invalid, do: {:error, Error.new(:unauthorized, :memory_candidate_generation)}
end
