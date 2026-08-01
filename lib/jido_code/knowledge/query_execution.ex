defmodule JidoCode.Knowledge.QueryExecution do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.CatalogQueryRequest
  alias JidoCode.Knowledge.ConsistencyEvaluator
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.QueryAuthorization
  alias JidoCode.Knowledge.QueryCatalog
  alias JidoCode.Knowledge.QueryDefinition
  alias JidoCode.Knowledge.QueryParameters
  alias JidoCode.Knowledge.QueryResult
  alias JidoCode.Knowledge.SemanticSnapshot
  alias TripleStore.SPARQL.Query

  @policy_graph "https://jido.run/graph/factory/policy"

  @spec execute(TripleStore.store(), map(), CatalogQueryRequest.t()) ::
          {:ok, QueryResult.t()}
          | {:error, Error.t()}
          | {:error, Error.t(), JidoCode.Knowledge.ConsistencyReceipt.t()}
  def execute(store, substrate_metadata, %CatalogQueryRequest{} = request) do
    with :ok <- verify_definition(request),
         {:ok, snapshot} <- read_snapshot(store, substrate_metadata, request),
         {:ok, _authorization} <- QueryAuthorization.authorize(request, snapshot),
         {:ok, consistency} <-
           ConsistencyEvaluator.evaluate(
             request.consistency,
             substrate_metadata,
             snapshot,
             request.graph_iris
           ),
         {:ok, raw} <- run(store, request),
         {:ok, data, truncated?, cursor} <- decode(raw, request, consistency),
         :ok <- enforce_bytes(data, request.definition.limits.byte_limit) do
      {:ok,
       result(
         request,
         snapshot,
         substrate_metadata,
         consistency,
         data,
         truncated?,
         cursor
       )}
    else
      {:error, %Error{} = error, consistency} -> {:error, error, consistency}
      {:error, %Error{} = error} -> {:error, error}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :catalog_query)}
      _invalid -> {:error, Error.new(:unavailable, :catalog_query)}
    end
  rescue
    _error -> {:error, Error.new(:unavailable, :catalog_query)}
  catch
    _kind, _reason -> {:error, Error.new(:unavailable, :catalog_query)}
  end

  def execute(_store, _metadata, _request),
    do: {:error, Error.new(:invalid_input, :catalog_query)}

  defp verify_definition(request) do
    with {:ok, current} <- QueryCatalog.fetch(request.query_name, request.query_version),
         true <- current.source_digest == request.definition.source_digest,
         true <- current.source_digest == QueryDefinition.source_digest(current.source),
         true <- current.source == request.definition.source do
      :ok
    else
      _invalid -> {:error, Error.new(:incompatible, :catalog_query)}
    end
  end

  defp read_snapshot(store, substrate_metadata, request) do
    graphs = Enum.uniq([@policy_graph | request.graph_iris])

    with {:ok, snapshot} <- SemanticSnapshot.read(store, substrate_metadata, graphs) do
      graph_revisions = Map.take(snapshot.graph_revisions, request.graph_iris)
      graph_metadata = Map.take(snapshot.graph_metadata, request.graph_iris)

      {:ok,
       %{
         snapshot
         | graph_revisions: graph_revisions,
           graph_metadata: graph_metadata
       }
       |> Map.put(:authorization_dataset, snapshot.dataset)
       |> Map.put(:dataset, snapshot.dataset)}
    end
  end

  defp run(store, request) do
    context = %{db: store.db, dict_manager: store.dict_manager, permit_all: true}

    case Query.query(context, request.bound_query,
           timeout: request.definition.limits.timeout_ms,
           use_cache: false
         ) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :catalog_query)}
    end
  end

  defp decode(rows, %{definition: %{form: :select}} = request, consistency)
       when is_list(rows) do
    limit = request.definition.limits.row_limit
    truncated? = length(rows) > limit

    data =
      rows
      |> Enum.take(limit)
      |> Enum.map(fn row -> Map.new(row, fn {key, value} -> {key, normalize_term(value)} end) end)

    cursor =
      if truncated? do
        QueryParameters.encode_cursor(%{
          query: request.query_name,
          version: request.query_version,
          dataset_revision: consistency.dataset_revision,
          graph_revisions: consistency.graph_revisions,
          consistency_digest: consistency.constraint_digest,
          offset: limit
        })
      end

    {:ok, data, truncated?, cursor}
  end

  defp decode(value, %{definition: %{form: :ask}}, _metadata) when is_boolean(value),
    do: {:ok, value, false, nil}

  defp decode(%RDF.Graph{} = graph, %{definition: %{form: :construct}} = request, _metadata) do
    triples = RDF.Graph.triples(graph)
    limit = request.definition.limits.triple_limit
    truncated? = length(triples) > limit

    data =
      triples
      |> Enum.take(limit)
      |> Enum.map(fn {subject, predicate, object} ->
        %{
          subject: normalize_term(subject),
          predicate: normalize_term(predicate),
          object: normalize_term(object)
        }
      end)
      |> Enum.sort_by(&:erlang.term_to_binary(&1, [:deterministic]))

    {:ok, data, truncated?, nil}
  end

  defp decode(_raw, _request, _metadata),
    do: {:error, Error.new(:corrupt, :decode_catalog_query)}

  defp result(request, snapshot, substrate, consistency, data, truncated?, cursor) do
    metadata = Map.values(snapshot.graph_metadata)
    ontology_versions = metadata |> Enum.map(& &1.ontology_version) |> Enum.uniq()
    completeness_states = metadata |> Enum.map(& &1.completeness_state) |> Enum.uniq()

    completeness = %{
      assumption: request.definition.completeness,
      states: completeness_states,
      complete?: completeness_states != [] and Enum.all?(completeness_states, &(&1 == :complete))
    }

    warnings =
      if(truncated?, do: [:result_truncated], else: []) ++
        Enum.map(consistency.gaps, &{:consistency, &1})

    %QueryResult{
      query_name: request.query_name,
      query_version: request.query_version,
      dataset_revision: substrate.dataset_revision,
      graph_revisions: snapshot.graph_revisions,
      ontology_version: single_or_unknown(ontology_versions),
      completeness: completeness,
      freshness: :current,
      truncated?: truncated?,
      cursor: cursor,
      warnings: warnings,
      execution_class: request.definition.execution_class,
      consistency: consistency,
      evaluated_at: request.evaluated_at,
      data: data
    }
  end

  defp normalize_term({:named_node, iri}), do: %{type: :iri, value: iri}
  defp normalize_term({:blank_node, identifier}), do: %{type: :blank_node, value: identifier}

  defp normalize_term({:literal, :typed, lexical, datatype}),
    do: %{type: :literal, value: lexical, datatype: datatype, language: nil}

  defp normalize_term({:literal, :lang, lexical, language}),
    do: %{type: :literal, value: lexical, datatype: nil, language: language}

  defp normalize_term({:literal, :simple, lexical}),
    do: %{type: :literal, value: lexical, datatype: nil, language: nil}

  defp normalize_term(%RDF.IRI{value: value}), do: %{type: :iri, value: value}

  defp normalize_term(%RDF.BlankNode{value: value}),
    do: %{type: :blank_node, value: to_string(value)}

  defp normalize_term(%RDF.Literal{} = literal) do
    %{
      type: :literal,
      value: literal |> RDF.Literal.value() |> normalize_literal_value(),
      datatype: literal |> RDF.Literal.datatype_id() |> to_string(),
      language: RDF.Literal.language(literal)
    }
  end

  defp normalize_term(other), do: %{type: :unknown, value: inspect(other, limit: 20)}

  defp normalize_literal_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp normalize_literal_value(value) when is_binary(value), do: value
  defp normalize_literal_value(value) when is_number(value) or is_boolean(value), do: value
  defp normalize_literal_value(value), do: to_string(value)

  defp enforce_bytes(data, limit) do
    if :erlang.external_size(data) <= limit,
      do: :ok,
      else: {:error, Error.new(:invalid_input, :catalog_query_limit)}
  end

  defp single_or_unknown([value]), do: value
  defp single_or_unknown([]), do: nil
  defp single_or_unknown(_multiple), do: :mixed
end
