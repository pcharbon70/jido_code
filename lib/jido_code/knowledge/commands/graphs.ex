defmodule JidoCode.Knowledge.Commands.Graphs do
  @moduledoc """
  Semantic command boundary for creating a registered named graph.

  Payload and graph-local metadata are compiled into one substrate batch. The
  returned map is a transient command projection; persisted authority is the
  named graph and its immutable commit receipt.
  """

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.WriteBatch
  alias JidoCode.Knowledge.Writer

  @metadata_namespace "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @relationship_predicates MapSet.new(~w[
    enrolls manages locatedBy inScope about derivedFrom supports contradicts addresses
    decomposesInto dependsOn blocks requiresCapability governedBy executes evaluates accepts
    rejects waives satisfies supersedes claimedBy validFor sourceActivity graphScope
    epistemicState confidenceBand priorState nextState transitionSubject expectedPredecessor
    cause decisionAuthority ontologyVersion creationActivity ownerScope graphKind lifecycleState
    completenessState sourceRevision parentGraph sourceGraph targetGraph validationReport
    focusNode resultShape resultPath severity ruleSet invalidationState
  ])

  @spec prepare_create(atom(), map(), [RDF.Statement.coercible()], map(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def prepare_create(family, scopes, payload, attributes, options \\ [])

  def prepare_create(family, scopes, payload, attributes, options)
      when is_atom(family) and is_map(scopes) and is_list(payload) and is_map(attributes) and
             is_list(options) do
    with {:ok, graph_iri} <- GraphRegistry.graph_iri(family, scopes),
         {:ok, contract} <-
           GraphRegistry.validate_target(graph_iri, Keyword.get(options, :capability)),
         true <- GraphRegistry.write_allowed?(family, :create),
         {:ok, metadata} <-
           GraphMetadata.new(graph_iri, metadata_attributes(attributes, contract)),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata),
         {:ok, payload_quads} <- normalize_payload(payload, graph_iri, family),
         {:ok, expected_dataset_revision} <- expected_dataset_revision(options),
         {:ok, batch} <-
           WriteBatch.new(
             metadata_quads ++ payload_quads,
             batch_options(options, expected_dataset_revision, graph_iri)
           ) do
      {:ok, %{batch: batch, graph_iri: graph_iri, metadata: metadata}}
    else
      false -> {:error, Error.new(:conflict, :graph_lifecycle)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  def prepare_create(_family, _scopes, _payload, _attributes, _options),
    do: {:error, Error.new(:invalid_input, :graph_create)}

  @spec create(atom(), map(), [RDF.Statement.coercible()], map(), keyword()) :: term()
  def create(family, scopes, payload, attributes, options \\ []) do
    writer = Keyword.get(options, :writer, Writer)

    with {:ok, prepared} <- prepare_create(family, scopes, payload, attributes, options),
         {:ok, receipt} <- Writer.commit(writer, prepared.batch, writer_options(options)) do
      {:ok, Map.put(prepared, :receipt, receipt)}
    end
  end

  defp metadata_attributes(attributes, contract) do
    attributes
    |> Map.put_new(:lifecycle_state, default_lifecycle(contract))
    |> Map.put_new(:completeness_state, contract.completeness)
    |> Map.put_new(:graph_revision, 1)
  end

  defp default_lifecycle(%{mutability: mutability})
       when mutability in [:immutable, :replaceable],
       do: :closed

  defp default_lifecycle(_contract), do: :open

  defp expected_dataset_revision(options) do
    case Keyword.fetch(options, :expected_dataset_revision) do
      {:ok, revision} when is_integer(revision) and revision >= 0 -> {:ok, revision}
      _missing_or_invalid -> {:error, Error.new(:invalid_input, :validate_expected_revision)}
    end
  end

  defp writer_options(options) do
    Keyword.take(options, [:operation_timeout, :caller_timeout])
  end

  defp batch_options(options, expected_dataset_revision, graph_iri) do
    base = [
      expected_dataset_revision: expected_dataset_revision,
      expected_graph_revisions: %{graph_iri => 0},
      operation_metadata: %{class: :graph_create, registry: GraphRegistry.revision()}
    ]

    case Keyword.fetch(options, :commit_id) do
      {:ok, commit_id} -> Keyword.put(base, :commit_id, commit_id)
      :error -> base
    end
  end

  defp normalize_payload(payload, graph_iri, family) do
    Enum.reduce_while(payload, {:ok, []}, fn statement, {:ok, quads} ->
      with {:ok, quad} <- normalize_statement(statement, graph_iri),
           :ok <- reject_reserved_metadata(quad, graph_iri),
           :ok <- validate_cross_graph_link(quad, family) do
        {:cont, {:ok, [quad | quads]}}
      else
        {:error, %Error{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, quads} -> {:ok, Enum.reverse(quads)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp normalize_statement({subject, predicate, object}, graph_iri) do
    normalize_quad({subject, predicate, object, graph_iri}, graph_iri)
  end

  defp normalize_statement({_, _, _, _} = quad, graph_iri), do: normalize_quad(quad, graph_iri)
  defp normalize_statement(_statement, _graph_iri), do: invalid(:graph_payload)

  defp normalize_quad(quad, graph_iri) do
    normalized = RDF.Quad.new(quad)

    case normalized do
      {_, _, _, %RDF.IRI{value: ^graph_iri}} ->
        if RDF.Quad.valid?(normalized) and not RDF.Quad.has_bnode?(normalized) do
          {:ok, normalized}
        else
          invalid(:graph_payload)
        end

      _wrong_graph ->
        invalid(:graph_placement)
    end
  rescue
    _error -> invalid(:graph_payload)
  end

  defp reject_reserved_metadata(
         {%RDF.IRI{value: subject}, %RDF.IRI{value: predicate}, _, _},
         graph_iri
       ) do
    if subject == graph_iri and String.starts_with?(predicate, @metadata_namespace) do
      invalid(:graph_metadata_authority)
    else
      :ok
    end
  end

  defp reject_reserved_metadata(_quad, _graph_iri), do: :ok

  defp validate_cross_graph_link({_subject, predicate, %RDF.IRI{value: object}, _graph}, family) do
    cond do
      not relationship_predicate?(predicate) ->
        :ok

      String.starts_with?(object, "https://jido.run/graph/") ->
        with {:ok, target_family} <- GraphRegistry.identify(object),
             true <- GraphRegistry.allowed_link?(family, target_family) do
          :ok
        else
          _invalid -> invalid(:cross_graph_link)
        end

      true ->
        :ok
    end
  end

  defp validate_cross_graph_link({_subject, predicate, _literal, _graph}, _family) do
    if relationship_predicate?(predicate) or RDF.IRI.to_string(predicate) == @rdf_type,
      do: invalid(:literal_relationship),
      else: :ok
  end

  defp relationship_predicate?(%RDF.IRI{value: @metadata_namespace <> local}) do
    MapSet.member?(@relationship_predicates, local)
  end

  defp relationship_predicate?(_predicate), do: false
  defp invalid(operation), do: {:error, Error.new(:invalid_input, operation)}
end
