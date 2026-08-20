defmodule JidoCode.Knowledge.Memory.RetrievalActivity do
  @moduledoc """
  Immutable start/outcome commitments for one governed retrieval.

  Start and outcome are ordinary predecessor-chained segment events. The start
  commits the authorization partition and algorithm revisions; the outcome
  commits the selected, omitted, opened, and unavailable identities plus the
  deterministic packet digest.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Execution.EventSegment
  alias JidoCode.Knowledge.Memory.RetrievalRequest
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [:iri, :request_iri, :kind, :occurred_at]
  defstruct @enforce_keys ++
              [
                :partition_digest,
                :query_version,
                :ranking_version,
                :index_version,
                :start_iri,
                :packet_digest,
                selected_iris: [],
                omitted_iris: [],
                opened_iris: [],
                unavailable_iris: [],
                followed_iris: [],
                contradicted_iris: [],
                ignored_iris: []
              ]

  @type t :: %__MODULE__{}
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @digest64 ~r/^[a-f0-9]{64}$/
  @max_commitments 200

  @spec start(RetrievalRequest.t(), DateTime.t()) :: {:ok, t()} | {:error, Error.t()}
  def start(%RetrievalRequest{} = request, %DateTime{} = occurred_at) do
    with {:ok, iri} <-
           ResourceIdentity.deterministic(:memory_retrieval_activity, "start\n" <> request.digest) do
      {:ok,
       %__MODULE__{
         iri: iri,
         request_iri: request.iri,
         kind: :start,
         occurred_at: DateTime.truncate(occurred_at, :microsecond),
         partition_digest: request.partition.partition_digest,
         query_version: request.query_version,
         ranking_version: request.ranking_version,
         index_version: request.index_version
       }}
    end
  end

  def start(_request, _occurred_at), do: invalid()

  @spec outcome(t(), map()) :: {:ok, t()} | {:error, Error.t()}
  def outcome(%__MODULE__{kind: :start} = start, attributes) when is_map(attributes) do
    allowed_keys = ~w[
      packet_digest occurred_at selected_iris omitted_iris opened_iris unavailable_iris
      followed_iris contradicted_iris ignored_iris
    ]a

    with true <- MapSet.subset?(MapSet.new(Map.keys(attributes)), MapSet.new(allowed_keys)),
         digest when is_binary(digest) <- attributes[:packet_digest],
         true <- Regex.match?(@digest64, digest),
         %DateTime{} = occurred_at <- attributes[:occurred_at],
         true <- DateTime.compare(occurred_at, start.occurred_at) in [:eq, :gt],
         {:ok, selected} <- commitments(attributes[:selected_iris] || []),
         {:ok, omitted} <- commitments(attributes[:omitted_iris] || []),
         {:ok, opened} <- commitments(attributes[:opened_iris] || []),
         {:ok, unavailable} <- commitments(attributes[:unavailable_iris] || []),
         {:ok, followed} <- commitments(attributes[:followed_iris] || []),
         {:ok, contradicted} <- commitments(attributes[:contradicted_iris] || []),
         {:ok, ignored} <- commitments(attributes[:ignored_iris] || []),
         true <- MapSet.disjoint?(MapSet.new(selected), MapSet.new(unavailable)),
         true <- MapSet.subset?(MapSet.new(opened), MapSet.new(selected)),
         true <- MapSet.subset?(MapSet.new(followed), MapSet.new(selected)),
         true <- MapSet.subset?(MapSet.new(contradicted), MapSet.new(selected)),
         true <- MapSet.subset?(MapSet.new(ignored), MapSet.new(selected)),
         true <- MapSet.disjoint?(MapSet.new(followed), MapSet.new(ignored)),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :memory_retrieval_activity,
             Enum.join(["outcome", start.iri, digest], "\n")
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         request_iri: start.request_iri,
         kind: :outcome,
         occurred_at: DateTime.truncate(occurred_at, :microsecond),
         partition_digest: start.partition_digest,
         query_version: start.query_version,
         ranking_version: start.ranking_version,
         index_version: start.index_version,
         start_iri: start.iri,
         packet_digest: digest,
         selected_iris: selected,
         omitted_iris: omitted,
         opened_iris: opened,
         unavailable_iris: unavailable,
         followed_iris: followed,
         contradicted_iris: contradicted,
         ignored_iris: ignored
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def outcome(_start, _attributes), do: invalid()

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{kind: :start} = activity) do
    [
      {activity.iri, @rdf_type, RDF.iri(@jf <> "MemoryRetrievalStart")},
      {activity.iri, @jf <> "retrievalRequest", RDF.iri(activity.request_iri)},
      {activity.iri, @jf <> "candidatePartitionDigest",
       RDF.XSD.String.new(activity.partition_digest)},
      {activity.iri, @jf <> "queryVersion", RDF.XSD.String.new(activity.query_version)},
      {activity.iri, @jf <> "rankingVersion", RDF.XSD.String.new(activity.ranking_version)},
      {activity.iri, @jf <> "indexVersion", RDF.XSD.String.new(activity.index_version)},
      {activity.iri, @prov <> "startedAtTime", RDF.XSD.DateTime.new(activity.occurred_at)}
    ]
  end

  def statements(%__MODULE__{kind: :outcome} = activity) do
    [
      {activity.iri, @rdf_type, RDF.iri(@jf <> "MemoryRetrievalOutcome")},
      {activity.iri, @jf <> "outcomeOf", RDF.iri(activity.start_iri)},
      {activity.iri, @jf <> "retrievalRequest", RDF.iri(activity.request_iri)},
      {activity.iri, @jf <> "evidencePacketDigest", RDF.XSD.String.new(activity.packet_digest)},
      {activity.iri, @prov <> "endedAtTime", RDF.XSD.DateTime.new(activity.occurred_at)}
    ] ++
      refs(activity.iri, "selectedMemory", activity.selected_iris) ++
      refs(activity.iri, "omittedMemory", activity.omitted_iris) ++
      refs(activity.iri, "openedMemory", activity.opened_iris) ++
      refs(activity.iri, "unavailableMemory", activity.unavailable_iris) ++
      refs(activity.iri, "followedMemory", activity.followed_iris) ++
      refs(activity.iri, "contradictedMemory", activity.contradicted_iris) ++
      refs(activity.iri, "ignoredMemory", activity.ignored_iris)
  end

  @spec event_attributes(t()) :: map()
  def event_attributes(%__MODULE__{kind: :start} = activity) do
    %{
      command_type: "RecordMemoryRetrievalStart",
      event_type: :memory_retrieval_start,
      role: :start,
      resource_iris: [activity.iri],
      resource_statements: statements(activity),
      opens_effect_iris: [activity.iri],
      occurred_at: activity.occurred_at
    }
  end

  def event_attributes(%__MODULE__{kind: :outcome} = activity) do
    %{
      command_type: "RecordMemoryRetrievalOutcome",
      event_type: :memory_retrieval_outcome,
      role: :outcome,
      resource_iris: [activity.iri],
      resource_statements: statements(activity),
      closes_effect_iris: [activity.start_iri],
      occurred_at: activity.occurred_at
    }
  end

  @spec record_command(t(), EventSegment.t(), map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def record_command(
        %__MODULE__{} = activity,
        %EventSegment{} = segment,
        attributes,
        options \\ []
      ) do
    EventSegment.append_command(
      segment,
      segment.head_iri,
      event_attributes(activity),
      attributes,
      options
    )
  end

  defp commitments(values) when is_list(values) and length(values) <= @max_commitments do
    normalized = Enum.sort(values)

    if length(normalized) == length(Enum.uniq(normalized)) and
         Enum.all?(normalized, &(ResourceIdentity.validate(&1) == :ok)),
       do: {:ok, normalized},
       else: invalid()
  end

  defp commitments(_values), do: invalid()

  defp refs(subject, predicate, values),
    do: Enum.map(values, &{subject, @jf <> predicate, RDF.iri(&1)})

  defp invalid, do: {:error, Error.new(:invalid_input, :memory_retrieval_activity)}
end
