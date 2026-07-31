defmodule JidoCode.Knowledge.Integrity do
  @moduledoc """
  Read-only physical and graph-contract checks for the authoritative dataset.

  Detection intentionally has no repair path. Repairs require a separate,
  explicitly confirmed maintenance operation.
  """

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.CommitLog
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.IntegrityIssue
  alias JidoCode.Knowledge.IntegrityReport
  alias JidoCode.Knowledge.Metadata
  alias JidoCode.Knowledge.Vocabulary
  alias TripleStore.Backend.RocksDB.ErlangAdapter
  alias TripleStore.Dictionary.Manager
  alias TripleStore.Dictionary.SequenceCounter
  alias TripleStore.QuadOperations
  alias TripleStore.SPARQL.Query

  @max_commits 1_000

  @spec check(TripleStore.store(), map()) ::
          {:ok, IntegrityReport.t()} | {:error, Error.t()}
  def check(store, expected_metadata) when is_map(expected_metadata) do
    with {:ok, summary} <- graph_summary(store),
         {:ok, actual_metadata} <- Metadata.read(store) do
      issues =
        []
        |> check_backend(store)
        |> check_dictionary(store)
        |> check_metadata(actual_metadata, expected_metadata)
        |> check_default_graph(summary)
        |> check_named_graphs(store, summary)
        |> check_commit_receipts(store, actual_metadata)
        |> Enum.reverse()

      {:ok,
       %IntegrityReport{
         status: if(issues == [], do: :ok, else: :error),
         dataset_revision: metadata_value(actual_metadata, :dataset_revision),
         graph_count: summary |> Map.delete(:default) |> map_size(),
         quad_count: summary |> Map.values() |> Enum.sum(),
         issues: issues
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
    end
  catch
    :exit, reason -> {:error, BackendFailure.translate(reason, :check_store_integrity)}
  end

  defp graph_summary(store) do
    case QuadOperations.graphs_summary(store.db) do
      {:ok, summary} -> {:ok, summary}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :check_store_integrity)}
    end
  end

  defp check_backend(issues, store) do
    case ErlangAdapter.is_quad_store?(store.db) do
      {:ok, true} -> issues
      {:ok, false} -> [issue(:backend_schema_mismatch, nil, :restore_compatible_backup) | issues]
      {:error, _reason} -> [issue(:backend_unreadable, nil, :restore_verified_backup) | issues]
    end
  end

  defp check_dictionary(issues, store) do
    result =
      with {:ok, counter} <- Manager.get_counter(store.dict_manager),
           {:ok, uri} <- SequenceCounter.current(counter, :uri),
           {:ok, bnode} <- SequenceCounter.current(counter, :bnode),
           {:ok, literal} <- SequenceCounter.current(counter, :literal),
           true <- Enum.all?([uri, bnode, literal], &(is_integer(&1) and &1 >= 0)) do
        :ok
      else
        _error -> :error
      end

    if result == :ok do
      issues
    else
      [issue(:dictionary_unreadable, nil, :restore_verified_backup) | issues]
    end
  end

  defp check_metadata(issues, nil, _expected) do
    [issue(:metadata_missing, Vocabulary.system_graph(), :restore_verified_backup) | issues]
  end

  defp check_metadata(issues, actual, expected) do
    checks = [
      {:store_schema_version, :store_schema_mismatch, :run_schema_migration},
      {:backend_schema_version, :backend_schema_mismatch, :restore_compatible_backup},
      {:lineage, :lineage_mismatch, :confirm_restore_target},
      {:dataset_revision, :dataset_revision_mismatch, :restore_verified_backup},
      {:system_graph_revision, :system_graph_revision_mismatch, :restore_verified_backup}
    ]

    Enum.reduce(checks, issues, fn {key, code, remediation}, acc ->
      if Map.get(actual, key) == Map.get(expected, key) do
        acc
      else
        [issue(code, Vocabulary.dataset(), remediation) | acc]
      end
    end)
  end

  defp check_default_graph(issues, summary) do
    if Map.get(summary, :default, 0) == 0 do
      issues
    else
      [issue(:default_graph_not_empty, "default", :move_data_to_named_graph) | issues]
    end
  end

  defp check_named_graphs(issues, store, summary) do
    Enum.reduce(summary, issues, fn
      {:default, _count}, acc ->
        acc

      {%RDF.IRI{} = graph, _count}, acc ->
        graph_iri = to_string(graph)

        case Metadata.graph_revision(store, graph_iri) do
          {:ok, revision} when is_integer(revision) and revision >= 0 -> acc
          _error -> [issue(:graph_metadata_missing, graph_iri, :run_graph_metadata_repair) | acc]
        end

      {_invalid_graph, _count}, acc ->
        [issue(:graph_identifier_invalid, nil, :restore_verified_backup) | acc]
    end)
  end

  defp check_commit_receipts(issues, store, metadata) do
    context = %{db: store.db, dict_manager: store.dict_manager, permit_all: true}

    case Query.query(context, commit_query(), timeout: 5_000, use_cache: false) do
      {:ok, rows} when length(rows) <= @max_commits ->
        Enum.reduce(rows, issues, fn row, acc ->
          check_receipt_row(store, row, metadata, acc)
        end)

      {:ok, _rows} ->
        [issue(:integrity_check_limit, nil, :run_offline_integrity_check) | issues]

      {:error, _reason} ->
        [issue(:commit_index_unreadable, nil, :restore_verified_backup) | issues]
    end
  end

  defp check_receipt_row(store, %{"commit" => {:named_node, commit_id}}, metadata, issues) do
    case CommitLog.lookup(store, commit_id) do
      {:ok, receipt} ->
        check_receipt_revisions(store, receipt, metadata, issues)

      {:error, _error} ->
        [issue(:commit_receipt_corrupt, commit_id, :restore_verified_backup) | issues]
    end
  end

  defp check_receipt_row(_store, _row, _metadata, issues) do
    [issue(:commit_receipt_corrupt, nil, :restore_verified_backup) | issues]
  end

  defp check_receipt_revisions(store, receipt, metadata, issues) do
    graph_revisions_valid? =
      Enum.all?(receipt.graph_revisions, fn {graph, %{new: revision}} ->
        match?({:ok, latest} when latest >= revision, Metadata.graph_revision(store, graph))
      end)

    if receipt.dataset_revision <= metadata.dataset_revision and graph_revisions_valid? do
      issues
    else
      [issue(:revision_regression, receipt.commit_id, :restore_verified_backup) | issues]
    end
  end

  defp commit_query do
    """
    SELECT DISTINCT ?commit
    WHERE {
      GRAPH <#{Vocabulary.system_graph()}> {
        ?commit <#{Vocabulary.predicate(:status)}> <#{Vocabulary.committed()}> .
      }
    }
    LIMIT #{@max_commits + 1}
    """
  end

  defp issue(code, reference, remediation) do
    %IntegrityIssue{
      code: code,
      severity: :error,
      reference: bound_reference(reference),
      remediation: remediation
    }
  end

  defp bound_reference(nil), do: nil
  defp bound_reference(reference) when is_binary(reference), do: String.slice(reference, 0, 256)
  defp metadata_value(nil, _key), do: nil
  defp metadata_value(metadata, key), do: Map.get(metadata, key)
end
