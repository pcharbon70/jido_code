defmodule JidoCode.Knowledge.CommitLog do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Identity
  alias JidoCode.Knowledge.Vocabulary
  alias JidoCode.Knowledge.WriteBatch
  alias JidoCode.Knowledge.WriteReceipt
  alias TripleStore.SPARQL.Query

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @xsd_integer "http://www.w3.org/2001/XMLSchema#integer"
  @xsd_non_negative_integer "http://www.w3.org/2001/XMLSchema#nonNegativeInteger"
  @xsd_string "http://www.w3.org/2001/XMLSchema#string"
  @max_receipt_rows 256

  @spec build(WriteBatch.t(), map(), map()) :: {[RDF.Quad.t()], WriteReceipt.t()}
  def build(batch, current, next) do
    graph_changes =
      Map.new(batch.target_graphs, fn graph ->
        {graph,
         %{
           prior: Map.fetch!(current.graph_revisions, graph),
           new: Map.fetch!(next.graph_revisions, graph)
         }}
      end)

    receipt = %WriteReceipt{
      commit_id: batch.commit_id,
      batch_digest: batch.batch_digest,
      prior_dataset_revision: current.dataset_revision,
      dataset_revision: next.dataset_revision,
      graph_revisions: graph_changes,
      additions_count: length(batch.additions),
      removals_count: length(batch.removals),
      durability: :sync,
      replayed?: false
    }

    {receipt_quads(receipt, next.system_graph_revision), receipt}
  end

  @spec lookup(TripleStore.store(), String.t()) ::
          {:ok, WriteReceipt.t() | nil} | {:error, Error.t()}
  def lookup(store, commit_id) do
    if Identity.valid_commit_iri?(commit_id) do
      context = %{db: store.db, dict_manager: store.dict_manager, permit_all: true}

      case Query.query(context, receipt_query(commit_id), timeout: 5_000, use_cache: false) do
        {:ok, []} -> confirm_absent(context, commit_id)
        {:ok, rows} when length(rows) <= @max_receipt_rows -> decode(commit_id, rows)
        {:ok, _rows} -> {:error, Error.new(:corrupt, :read_commit_receipt)}
        {:error, reason} -> {:error, BackendFailure.translate(reason, :read_commit_receipt)}
      end
    else
      {:error, Error.new(:invalid_input, :validate_commit_identity)}
    end
  end

  defp receipt_quads(receipt, system_graph_revision) do
    graph = Vocabulary.system_graph()
    commit = receipt.commit_id

    commit_quads = [
      RDF.quad(commit, @rdf_type, RDF.iri(Vocabulary.commit_class()), graph),
      RDF.quad(commit, Vocabulary.predicate(:status), RDF.iri(Vocabulary.committed()), graph),
      RDF.quad(commit, Vocabulary.predicate(:batch_digest), receipt.batch_digest, graph),
      RDF.quad(
        commit,
        Vocabulary.predicate(:prior_dataset_revision),
        receipt.prior_dataset_revision,
        graph
      ),
      RDF.quad(commit, Vocabulary.predicate(:dataset_revision), receipt.dataset_revision, graph),
      RDF.quad(commit, Vocabulary.predicate(:additions_count), receipt.additions_count, graph),
      RDF.quad(commit, Vocabulary.predicate(:removals_count), receipt.removals_count, graph),
      RDF.quad(
        commit,
        Vocabulary.predicate(:durability),
        RDF.iri(Vocabulary.sync_durability()),
        graph
      ),
      RDF.quad(
        Vocabulary.dataset(),
        Vocabulary.predicate(:dataset_revision),
        receipt.dataset_revision,
        graph
      ),
      RDF.quad(
        Vocabulary.system_graph(),
        Vocabulary.predicate(:graph_revision),
        system_graph_revision,
        graph
      )
    ]

    revision_quads =
      Enum.flat_map(receipt.graph_revisions, fn {target_graph, revisions} ->
        change = graph_change_iri(commit, target_graph)

        [
          RDF.quad(commit, Vocabulary.predicate(:graph_change), RDF.iri(change), graph),
          RDF.quad(change, @rdf_type, RDF.iri(Vocabulary.graph_change_class()), graph),
          RDF.quad(
            change,
            Vocabulary.predicate(:changed_graph),
            RDF.iri(target_graph),
            graph
          ),
          RDF.quad(
            change,
            Vocabulary.predicate(:prior_graph_revision),
            revisions.prior,
            graph
          ),
          RDF.quad(change, Vocabulary.predicate(:graph_revision), revisions.new, graph),
          RDF.quad(
            target_graph,
            Vocabulary.predicate(:graph_revision),
            revisions.new,
            graph
          )
        ]
      end)

    commit_quads ++ revision_quads
  end

  defp graph_change_iri(commit, graph) do
    suffix = graph |> then(&:crypto.hash(:sha256, &1)) |> Base.url_encode64(padding: false)
    commit <> ":graph:" <> suffix
  end

  defp decode(commit_id, rows) do
    with {:ok, common} <- common_values(rows),
         true <- common.dataset_revision == common.prior_dataset_revision + 1,
         true <- valid_digest?(common.batch_digest),
         {:ok, graph_revisions} <- graph_revisions(rows),
         true <- map_size(graph_revisions) > 0 do
      {:ok,
       %WriteReceipt{
         commit_id: commit_id,
         batch_digest: common.batch_digest,
         prior_dataset_revision: common.prior_dataset_revision,
         dataset_revision: common.dataset_revision,
         graph_revisions: graph_revisions,
         additions_count: common.additions_count,
         removals_count: common.removals_count,
         durability: :sync,
         replayed?: false
       }}
    else
      _invalid -> {:error, Error.new(:corrupt, :read_commit_receipt)}
    end
  end

  defp common_values(rows) do
    decoded =
      Enum.map(rows, fn row ->
        with {:ok, batch_digest} <- string_binding(row, "digest"),
             {:ok, prior_dataset_revision} <- integer_binding(row, "prior_dataset_revision"),
             {:ok, dataset_revision} <- integer_binding(row, "dataset_revision"),
             {:ok, additions_count} <- integer_binding(row, "additions"),
             {:ok, removals_count} <- integer_binding(row, "removals"),
             {:ok, durability} <- iri_binding(row, "durability"),
             true <- durability == Vocabulary.sync_durability() do
          {:ok,
           %{
             batch_digest: batch_digest,
             prior_dataset_revision: prior_dataset_revision,
             dataset_revision: dataset_revision,
             additions_count: additions_count,
             removals_count: removals_count
           }}
        end
      end)

    case Enum.uniq(decoded) do
      [{:ok, common}] -> {:ok, common}
      _invalid -> :error
    end
  end

  defp graph_revisions(rows) do
    Enum.reduce_while(rows, {:ok, %{}}, fn row, {:ok, revisions} ->
      with {:ok, graph} <- iri_binding(row, "graph"),
           {:ok, prior} <- integer_binding(row, "prior_graph_revision"),
           {:ok, new} <- integer_binding(row, "graph_revision"),
           true <- new == prior + 1,
           false <- Map.has_key?(revisions, graph) do
        {:cont, {:ok, Map.put(revisions, graph, %{prior: prior, new: new})}}
      else
        _invalid -> {:halt, :error}
      end
    end)
  end

  defp confirm_absent(context, commit_id) do
    query = """
    ASK {
      GRAPH <#{Vocabulary.system_graph()}> {
        <#{commit_id}> ?predicate ?object .
      }
    }
    """

    case Query.query(context, query, timeout: 5_000, use_cache: false) do
      {:ok, false} -> {:ok, nil}
      {:ok, true} -> {:error, Error.new(:corrupt, :read_commit_receipt)}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :read_commit_receipt)}
      _invalid -> {:error, Error.new(:corrupt, :read_commit_receipt)}
    end
  end

  defp valid_digest?(digest) do
    byte_size(digest) == 64 and Regex.match?(~r/^[0-9a-f]{64}$/, digest)
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

  defp string_binding(row, key) do
    case Map.get(row, key) do
      {:literal, :simple, value} when is_binary(value) -> {:ok, value}
      {:literal, :typed, value, @xsd_string} when is_binary(value) -> {:ok, value}
      _invalid -> :error
    end
  end

  defp iri_binding(row, key) do
    case Map.get(row, key) do
      {:named_node, iri} when is_binary(iri) -> {:ok, iri}
      _invalid -> :error
    end
  end

  defp receipt_query(commit_id) do
    """
    SELECT ?digest ?prior_dataset_revision ?dataset_revision ?additions ?removals
           ?durability ?graph ?prior_graph_revision ?graph_revision
    WHERE {
      GRAPH <#{Vocabulary.system_graph()}> {
        <#{commit_id}>
          <#{@rdf_type}> <#{Vocabulary.commit_class()}> ;
          <#{Vocabulary.predicate(:status)}> <#{Vocabulary.committed()}> ;
          <#{Vocabulary.predicate(:batch_digest)}> ?digest ;
          <#{Vocabulary.predicate(:prior_dataset_revision)}> ?prior_dataset_revision ;
          <#{Vocabulary.predicate(:dataset_revision)}> ?dataset_revision ;
          <#{Vocabulary.predicate(:additions_count)}> ?additions ;
          <#{Vocabulary.predicate(:removals_count)}> ?removals ;
          <#{Vocabulary.predicate(:durability)}> ?durability ;
          <#{Vocabulary.predicate(:graph_change)}> ?change .

        ?change
          <#{Vocabulary.predicate(:changed_graph)}> ?graph ;
          <#{Vocabulary.predicate(:prior_graph_revision)}> ?prior_graph_revision ;
          <#{Vocabulary.predicate(:graph_revision)}> ?graph_revision .
      }
    }
    LIMIT #{@max_receipt_rows + 1}
    """
  end
end
