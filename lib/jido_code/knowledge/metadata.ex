defmodule JidoCode.Knowledge.Metadata do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Vocabulary
  alias TripleStore.QuadOperations
  alias TripleStore.SPARQL.Query

  @backend_schema_version 2
  @xsd_integer "http://www.w3.org/2001/XMLSchema#integer"
  @xsd_non_negative_integer "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"

  @type t :: %{
          store_schema_version: pos_integer(),
          backend_schema_version: pos_integer(),
          lineage: String.t(),
          dataset_revision: non_neg_integer(),
          system_graph_revision: non_neg_integer()
        }

  @spec ensure(TripleStore.store(), pos_integer(), String.t()) ::
          {:ok, t()} | {:error, Error.t()}
  def ensure(store, expected_schema_version, lineage_iri) do
    case read(store) do
      {:ok, nil} -> bootstrap_empty(store, expected_schema_version, lineage_iri)
      {:ok, metadata} -> validate(metadata, expected_schema_version)
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  @spec read(TripleStore.store()) :: {:ok, t() | nil} | {:error, Error.t()}
  def read(store) do
    context = %{db: store.db, dict_manager: store.dict_manager, permit_all: true}

    case Query.query(context, metadata_query(), timeout: 5_000, use_cache: false) do
      {:ok, []} ->
        {:ok, nil}

      {:ok, [row]} ->
        decode(row)

      {:ok, _rows} ->
        {:error, Error.new(:corrupt, :verify_store_metadata)}

      {:error, reason} ->
        {:error, BackendFailure.translate(reason, :verify_store_metadata)}
    end
  end

  @spec backend_schema_version() :: pos_integer()
  def backend_schema_version, do: @backend_schema_version

  defp bootstrap_empty(store, schema_version, lineage_iri) do
    with {:ok, summary} <- backend_graph_summary(store),
         true <- empty_dataset?(summary),
         {:ok, 6} <- TripleStore.update(store, bootstrap_update(schema_version, lineage_iri)),
         {:ok, metadata} when not is_nil(metadata) <- read(store),
         {:ok, validated} <- validate(metadata, schema_version) do
      {:ok, validated}
    else
      false ->
        {:error, Error.new(:incompatible, :bootstrap_store_metadata)}

      {:ok, nil} ->
        {:error, Error.new(:persistence_failure, :bootstrap_store_metadata)}

      {:ok, _unexpected_count} ->
        {:error, Error.new(:persistence_failure, :bootstrap_store_metadata)}

      {:error, %Error{} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error, BackendFailure.translate(reason, :bootstrap_store_metadata)}
    end
  end

  defp backend_graph_summary(store) do
    case QuadOperations.graphs_summary(store.db) do
      {:ok, summary} -> {:ok, summary}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :inspect_empty_store)}
    end
  end

  defp empty_dataset?(summary) do
    Enum.all?(summary, fn {_graph, count} -> count == 0 end)
  end

  defp validate(metadata, expected_schema_version) do
    cond do
      metadata.store_schema_version != expected_schema_version ->
        {:error, Error.new(:incompatible, :verify_store_metadata)}

      metadata.backend_schema_version != @backend_schema_version ->
        {:error, Error.new(:incompatible, :verify_backend_schema)}

      metadata.dataset_revision < 0 or metadata.system_graph_revision < 0 ->
        {:error, Error.new(:corrupt, :verify_store_metadata)}

      not valid_lineage?(metadata.lineage) ->
        {:error, Error.new(:corrupt, :verify_store_metadata)}

      true ->
        {:ok, metadata}
    end
  end

  defp decode(row) do
    with {:ok, store_schema_version} <- integer_binding(row, "store_schema"),
         {:ok, backend_schema_version} <- integer_binding(row, "backend_schema"),
         {:ok, lineage} <- iri_binding(row, "lineage"),
         {:ok, dataset_revision} <- integer_binding(row, "dataset_revision"),
         {:ok, system_graph_revision} <- integer_binding(row, "system_graph_revision") do
      {:ok,
       %{
         store_schema_version: store_schema_version,
         backend_schema_version: backend_schema_version,
         lineage: lineage,
         dataset_revision: dataset_revision,
         system_graph_revision: system_graph_revision
       }}
    else
      _error -> {:error, Error.new(:corrupt, :verify_store_metadata)}
    end
  end

  defp integer_binding(row, key) do
    case Map.get(row, key) do
      {:literal, :typed, lexical, datatype}
      when datatype in [@xsd_integer, @xsd_non_negative_integer] ->
        case Integer.parse(lexical) do
          {integer, ""} when integer >= 0 -> {:ok, integer}
          _invalid -> :error
        end

      _invalid ->
        :error
    end
  end

  defp iri_binding(row, key) do
    case Map.get(row, key) do
      {:named_node, iri} when is_binary(iri) -> {:ok, iri}
      _invalid -> :error
    end
  end

  defp valid_lineage?(lineage) do
    Regex.match?(~r/^urn:jido-code:lineage:[A-Za-z0-9_-]{8,128}$/, lineage)
  end

  defp bootstrap_update(schema_version, lineage_iri) do
    """
    INSERT DATA {
      GRAPH <#{Vocabulary.system_graph()}> {
        <#{Vocabulary.dataset()}>
          <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <#{Vocabulary.dataset_class()}> ;
          <#{Vocabulary.predicate(:store_schema_version)}> #{schema_version} ;
          <#{Vocabulary.predicate(:backend_schema_version)}> #{@backend_schema_version} ;
          <#{Vocabulary.predicate(:lineage)}> <#{lineage_iri}> ;
          <#{Vocabulary.predicate(:dataset_revision)}> 0 .

        <#{Vocabulary.system_graph()}>
          <#{Vocabulary.predicate(:graph_revision)}> 0 .
      }
    }
    """
  end

  defp metadata_query do
    """
    SELECT ?store_schema ?backend_schema ?lineage ?dataset_revision ?system_graph_revision
    WHERE {
      GRAPH <#{Vocabulary.system_graph()}> {
        <#{Vocabulary.dataset()}>
          <#{Vocabulary.predicate(:store_schema_version)}> ?store_schema ;
          <#{Vocabulary.predicate(:backend_schema_version)}> ?backend_schema ;
          <#{Vocabulary.predicate(:lineage)}> ?lineage ;
          <#{Vocabulary.predicate(:dataset_revision)}> ?dataset_revision .

        <#{Vocabulary.system_graph()}>
          <#{Vocabulary.predicate(:graph_revision)}> ?system_graph_revision .
      }
    }
    """
  end
end
