defmodule JidoCode.Knowledge.RepositoryWiki.Segment do
  @moduledoc "Bounded, ordered, content-addressed wiki edition segment."

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.RepositoryWiki.Command
  alias JidoCode.Knowledge.RepositoryWiki.Contract
  alias JidoCode.Knowledge.RepositoryWiki.Graph
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :edition_iri,
    :index,
    :predecessor_iri,
    :digest,
    :statement_count,
    :content_bytes,
    :recorded_at,
    :statements
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @statement_limit 800
  @byte_limit 192 * 1024
  @payload_statement_limit 790

  def limits, do: %{statements: @statement_limit, bytes: @byte_limit}

  @spec partition(String.t(), [tuple()], DateTime.t()) ::
          {:ok, [t()]} | {:error, Error.t()}
  def partition(edition_iri, statements, %DateTime{} = recorded_at) when is_list(statements) do
    statements
    |> Enum.chunk_every(@payload_statement_limit)
    |> Enum.reduce_while({:ok, [], nil}, fn chunk, {:ok, segments, predecessor} ->
      case fit_chunk(edition_iri, chunk, recorded_at, segments, predecessor) do
        {:ok, next_segments, next_predecessor} ->
          {:cont, {:ok, next_segments, next_predecessor}}

        {:error, %Error{} = error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, [], _predecessor} -> invalid(:wiki_segment_empty)
      {:ok, segments, _predecessor} -> {:ok, segments}
      error -> error
    end
  end

  def partition(_edition_iri, _statements, _recorded_at),
    do: invalid(:wiki_segment_partition)

  @spec new(String.t(), non_neg_integer(), nil | t(), [tuple()], DateTime.t()) ::
          {:ok, t()} | {:error, Error.t()}
  def new(edition_iri, index, predecessor, statements, recorded_at)
      when is_integer(index) and index >= 0 and is_list(statements) and statements != [] and
             is_struct(recorded_at, DateTime) do
    with :ok <- ResourceIdentity.validate(edition_iri),
         :ok <- predecessor_valid(index, edition_iri, predecessor),
         true <- length(statements) <= @payload_statement_limit,
         {:ok, payload} <- canonical(statements),
         digest <-
           Contract.digest(%{
             edition_iri: edition_iri,
             index: index,
             predecessor_digest: predecessor_digest(predecessor),
             payload: payload
           }),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :wiki_edition_segment,
             Enum.join([edition_iri, Integer.to_string(index), digest], "\n")
           ),
         segment <- %__MODULE__{
           iri: iri,
           edition_iri: edition_iri,
           index: index,
           predecessor_iri: predecessor_iri(predecessor),
           digest: digest,
           statement_count: length(statements) + metadata_statement_count(predecessor),
           content_bytes: byte_size(payload),
           recorded_at: DateTime.truncate(recorded_at, :microsecond),
           statements: statements
         },
         additions <- all_statements(segment),
         true <- length(additions) <= @statement_limit,
         {:ok, canonical} <- canonical(additions),
         true <- byte_size(canonical) <= @byte_limit do
      {:ok, segment}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:wiki_segment)
    end
  rescue
    _error -> invalid(:wiki_segment)
  end

  def new(_edition_iri, _index, _predecessor, _statements, _recorded_at),
    do: invalid(:wiki_segment)

  @spec all_statements(t()) :: [tuple()]
  def all_statements(%__MODULE__{} = segment) do
    [
      {segment.iri, @rdf_type, RDF.iri(@jf <> "WikiEditionSegment")},
      {segment.iri, @jf <> "wikiEdition", RDF.iri(segment.edition_iri)},
      {segment.iri, @jf <> "segmentIndex", RDF.XSD.NonNegativeInteger.new(segment.index)},
      {segment.iri, @jf <> "segmentDigest", RDF.XSD.String.new(segment.digest)},
      {segment.iri, @jf <> "segmentBytes", RDF.XSD.NonNegativeInteger.new(segment.content_bytes)},
      {segment.iri, @jf <> "segmentStatementCount",
       RDF.XSD.NonNegativeInteger.new(segment.statement_count)},
      {segment.iri, @prov <> "generatedAtTime", RDF.XSD.DateTime.new(segment.recorded_at)}
      | optional_predecessor(segment)
    ] ++ segment.statements
  end

  @spec append_command(t(), map(), keyword()) ::
          {:ok, JidoCode.Knowledge.CommandEnvelope.t()} | {:error, Error.t()}
  def append_command(%__MODULE__{} = segment, attributes, options \\ []) do
    graph = attributes[:wiki_graph_iri]
    revision = attributes[:expected_wiki_revision]

    with true <- is_integer(revision) and revision > 0,
         {:ok, target} <- Graph.append_target(graph, revision, all_statements(segment)),
         guards <-
           [
             {:subject_present, graph, segment.edition_iri},
             {:predicate_absent, graph, segment.edition_iri, @jf <> "closureDigest"},
             {:subject_absent, graph, segment.iri}
           ] ++ predecessor_guard(graph, segment),
         {:ok, command} <-
           Command.build(
             "AppendWikiEditionSegment",
             segment.iri,
             [target],
             guards,
             command_attributes(attributes, graph, revision),
             options
           ) do
      {:ok, command}
    else
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> invalid(:append_wiki_edition_segment)
    end
  end

  defp command_attributes(attributes, graph, revision) do
    attributes
    |> Map.put(:expected_graph_revisions, %{graph => revision})
    |> Map.put(:source_fence, attributes[:source_fence])
  end

  defp predecessor_valid(0, _edition, nil), do: :ok

  defp predecessor_valid(index, edition, %__MODULE__{} = predecessor) when index > 0 do
    if predecessor.edition_iri == edition and predecessor.index == index - 1,
      do: :ok,
      else: invalid(:wiki_segment_predecessor)
  end

  defp predecessor_valid(_index, _edition, _predecessor),
    do: invalid(:wiki_segment_predecessor)

  defp fit_chunk(edition_iri, chunk, recorded_at, segments, predecessor) do
    case new(edition_iri, length(segments), predecessor, chunk, recorded_at) do
      {:ok, segment} ->
        {:ok, segments ++ [segment], segment}

      {:error, %Error{} = error} when length(chunk) == 1 ->
        {:error, error}

      {:error, %Error{}} ->
        {left, right} = Enum.split(chunk, div(length(chunk), 2))

        with {:ok, left_segments, left_predecessor} <-
               fit_chunk(edition_iri, left, recorded_at, segments, predecessor),
             {:ok, all_segments, final_predecessor} <-
               fit_chunk(edition_iri, right, recorded_at, left_segments, left_predecessor) do
          {:ok, all_segments, final_predecessor}
        end
    end
  end

  defp predecessor_iri(nil), do: nil
  defp predecessor_iri(%__MODULE__{iri: iri}), do: iri
  defp predecessor_digest(nil), do: nil
  defp predecessor_digest(%__MODULE__{digest: digest}), do: digest

  defp metadata_statement_count(nil), do: 7
  defp metadata_statement_count(%__MODULE__{}), do: 8

  defp optional_predecessor(%__MODULE__{predecessor_iri: nil}), do: []

  defp optional_predecessor(segment),
    do: [{segment.iri, @jf <> "predecessorWikiSegment", RDF.iri(segment.predecessor_iri)}]

  defp predecessor_guard(_graph, %__MODULE__{predecessor_iri: nil}), do: []

  defp predecessor_guard(graph, segment),
    do: [{:subject_present, graph, segment.predecessor_iri}]

  defp canonical(statements) do
    graph = RDF.Graph.new(statements)

    if RDF.Graph.triples(graph) |> length() == length(statements) and
         Enum.all?(
           RDF.Graph.triples(graph),
           &(RDF.Triple.valid?(&1) and not RDF.Triple.has_bnode?(&1))
         ) do
      {:ok, RDF.NTriples.write_string!(graph, sort: true)}
    else
      invalid(:wiki_segment_statements)
    end
  rescue
    _error -> invalid(:wiki_segment_statements)
  end

  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
