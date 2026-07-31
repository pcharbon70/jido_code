defmodule JidoCode.Knowledge.AtomicCommit do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.CommitLog
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Revision
  alias JidoCode.Knowledge.WriteBatch
  alias JidoCode.Knowledge.WriteReceipt

  @max_update_quads 10_000

  @spec apply(TripleStore.store(), map(), WriteBatch.t()) ::
          {:ok, WriteReceipt.t(), map()}
          | {:error, Error.t()}
          | {:error, Error.t(), JidoCode.Knowledge.RevisionReceipt.t()}
  def apply(store, metadata, %WriteBatch{} = batch) do
    with :ok <- validate_removals(batch),
         {:ok, existing} <- CommitLog.lookup(store, batch.commit_id) do
      case existing do
        nil ->
          commit_new(store, metadata, batch)

        %WriteReceipt{batch_digest: digest} = receipt when digest == batch.batch_digest ->
          {:ok, WriteReceipt.replayed(receipt), metadata}

        %WriteReceipt{} ->
          {:error, Error.new(:conflict, :commit_identity_reuse)}
      end
    end
  end

  def apply(_store, _metadata, _batch) do
    {:error, Error.new(:invalid_input, :atomic_commit)}
  end

  defp commit_new(store, metadata, batch) do
    with {:ok, current} <- Revision.current(store, metadata, batch.target_graphs),
         :ok <-
           Revision.verify_preconditions(
             current,
             batch.expected_dataset_revision,
             batch.expected_graph_revisions
           ),
         {:ok, next} <- Revision.next(current),
         {receipt_quads, receipt} <- CommitLog.build(batch, current, next),
         all_quads <- batch.additions ++ receipt_quads,
         :ok <- validate_update_size(all_quads),
         update <- compile_insert(all_quads),
         {:ok, committed_receipt} <-
           execute_and_reconcile(store, batch, receipt, update, length(all_quads)) do
      next_metadata = %{
        metadata
        | dataset_revision: committed_receipt.dataset_revision,
          system_graph_revision: next.system_graph_revision
      }

      {:ok, committed_receipt, next_metadata}
    end
  end

  defp validate_removals(%WriteBatch{removals: []}), do: :ok

  defp validate_removals(%WriteBatch{}) do
    {:error, Error.new(:invalid_input, :atomic_removal_not_supported)}
  end

  defp validate_update_size(quads) do
    if length(quads) <= @max_update_quads do
      :ok
    else
      {:error, Error.new(:invalid_input, :atomic_update_too_large)}
    end
  end

  defp execute_and_reconcile(store, batch, receipt, update, expected_count) do
    result = execute_update(store, update)

    case result do
      {:ok, ^expected_count} ->
        {:ok, receipt}

      other ->
        reconcile_uncertain_result(store, batch, other)
    end
  end

  defp execute_update(store, update) do
    TripleStore.update(store, update)
  rescue
    _error -> {:error, :update_exception}
  catch
    :exit, _reason -> {:error, :update_exit}
    _kind, _reason -> {:error, :update_failure}
  end

  defp reconcile_uncertain_result(store, batch, backend_result) do
    case CommitLog.lookup(store, batch.commit_id) do
      {:ok, %WriteReceipt{batch_digest: digest} = receipt} when digest == batch.batch_digest ->
        {:ok, WriteReceipt.replayed(receipt)}

      {:ok, %WriteReceipt{}} ->
        {:error, Error.new(:corrupt, :verify_commit_receipt)}

      {:ok, nil} ->
        {:error, BackendFailure.translate(backend_result, :atomic_commit)}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp compile_insert(quads) do
    body =
      quads
      |> Enum.group_by(fn {_, _, _, graph} -> graph end)
      |> Enum.sort_by(fn {graph, _graph_quads} -> RDF.IRI.to_string(graph) end)
      |> Enum.map_join("\n", fn {graph, graph_quads} ->
        statements =
          graph_quads
          |> Enum.map(fn {subject, predicate, object, _graph} ->
            [term(subject), " ", term(predicate), " ", term(object), " ."]
          end)
          |> Enum.sort()
          |> Enum.intersperse("\n")

        ["GRAPH ", term(graph), " {\n", statements, "\n}"]
      end)

    IO.iodata_to_binary(["INSERT DATA {\n", body, "\n}"])
  end

  defp term(rdf_term), do: RDF.NTriples.Encoder.term(rdf_term)
end
