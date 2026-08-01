defmodule JidoCode.Knowledge.AtomicCommit do
  @moduledoc false

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.CommitLog
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Revision
  alias JidoCode.Knowledge.WriteBatch
  alias JidoCode.Knowledge.WriteReceipt

  @max_update_quads 10_000
  @max_modify_template_quads 1_000
  @created_at "https://jido.run/ontology/factory#createdAt"

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
         :ok <- validate_update_size(all_quads, batch.removals),
         update <- compile_update(all_quads, batch.removals),
         {:ok, committed_receipt} <-
           execute_and_reconcile(
             store,
             batch,
             receipt,
             update,
             length(all_quads) + length(batch.removals)
           ) do
      next_metadata = %{
        metadata
        | dataset_revision: committed_receipt.dataset_revision,
          system_graph_revision: next.system_graph_revision
      }

      {:ok, committed_receipt, next_metadata}
    end
  end

  defp validate_removals(%WriteBatch{removals: []}), do: :ok

  defp validate_removals(%WriteBatch{
         removal_policy: :maintenance,
         operation_metadata: %{
           class: :semantic_command,
           command_type: "PublishDerivedGraph",
           command_version: "1.1.0"
         }
       }),
       do: :ok

  defp validate_removals(%WriteBatch{}) do
    {:error, Error.new(:invalid_input, :atomic_removal_not_supported)}
  end

  defp validate_update_size(additions, removals) do
    total = length(additions) + length(removals)

    modify_templates_bounded? =
      removals == [] or
        (length(additions) <= @max_modify_template_quads and
           length(removals) <= @max_modify_template_quads)

    if total <= @max_update_quads and modify_templates_bounded? do
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

  defp compile_update(additions, []), do: compile_insert(additions)

  defp compile_update(additions, removals) do
    {delete_body, where_body} = compile_delete_template(removals)

    IO.iodata_to_binary([
      "DELETE {\n",
      delete_body,
      "\n}\nINSERT {\n",
      compile_graph_body(additions),
      "\n}\nWHERE {\n",
      where_body,
      "\n}"
    ])
  end

  defp compile_insert(quads) do
    IO.iodata_to_binary(["INSERT DATA {\n", compile_graph_body(quads), "\n}"])
  end

  defp compile_graph_body(quads) do
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
  end

  # TripleStore normalizes xsd:dateTime lexical forms on storage. Binding the
  # mandatory graph createdAt value from the dataset avoids relying on lexical
  # equality while retaining one atomic DELETE/INSERT RocksDB write batch.
  defp compile_delete_template(removals) do
    case Enum.split_with(removals, fn
           {subject, %RDF.IRI{value: @created_at}, _object, graph} ->
             RDF.Term.equal_value?(subject, graph)

           _other ->
             false
         end) do
      {[{subject, predicate, _object, graph}], remaining} ->
        variable_quad =
          IO.iodata_to_binary([
            "GRAPH ",
            term(graph),
            " {\n",
            term(subject),
            " ",
            term(predicate),
            " ?existingCreatedAt .\n}"
          ])

        {Enum.join([compile_graph_body(remaining), variable_quad], "\n"), variable_quad}

      _no_single_created_at ->
        {compile_graph_body(removals), ""}
    end
  end

  defp term(rdf_term), do: RDF.NTriples.Encoder.term(rdf_term)
end
