defmodule JidoCode.Knowledge.CommandPipeline do
  @moduledoc """
  Governed semantic command orchestration inside the serialized writer.

  The pipeline fingerprints before reading mutable state, evaluates one
  bounded snapshot, and submits domain, provenance, audit, and receipt data as
  one Phase 2 atomic batch.
  """

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.AuditPolicy
  alias JidoCode.Knowledge.ChangeSet
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandPrecommit
  alias JidoCode.Knowledge.CommandProvenance
  alias JidoCode.Knowledge.CommandReceipt
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.WriteBatch
  alias JidoCode.Knowledge.WriteReceipt

  @spec execute(CommandEnvelope.t(), GenServer.server(), integer()) ::
          {:ok, CommandReceipt.t()}
  def execute(%CommandEnvelope{} = envelope, store_server, deadline) do
    result =
      with {:ok, definition} <-
             CommandRegistry.resolve(envelope.command_type, envelope.command_version),
           {:ok, change_set} <- ChangeSet.new(envelope),
           {:ok, identities} <- CommandProvenance.identities(envelope) do
        recover_or_commit(envelope, definition, change_set, identities, store_server, deadline)
      end

    normalize_outcome(result, envelope)
  rescue
    _error -> {:ok, CommandReceipt.failure(:unavailable, command_iri: envelope.command_iri)}
  catch
    _kind, _reason ->
      {:ok, CommandReceipt.failure(:unavailable, command_iri: envelope.command_iri)}
  end

  defp recover_or_commit(envelope, definition, change_set, identities, store_server, deadline) do
    with {:ok, existing} <- request(store_server, {:receipt, identities.commit_id}, deadline) do
      case existing do
        nil ->
          commit_new(envelope, definition, change_set, identities, store_server, deadline)

        %WriteReceipt{} = receipt ->
          recover_existing(
            envelope,
            definition,
            change_set,
            identities,
            receipt,
            store_server,
            deadline
          )
      end
    end
  end

  defp recover_existing(
         envelope,
         definition,
         change_set,
         identities,
         receipt,
         store_server,
         deadline
       ) do
    with {:ok, policy_graph} <- GraphRegistry.graph_iri(:factory_policy, %{}),
         snapshot_graphs =
           Enum.uniq(
             change_set.target_graphs ++
               Map.keys(envelope.expected_graph_revisions) ++ [policy_graph]
           ),
         {:ok, snapshot} <-
           request(store_server, {:semantic_snapshot, snapshot_graphs}, deadline),
         {:ok, _authority} <-
           Authorization.authorize(envelope, definition, change_set, snapshot) do
      case receipt do
        %WriteReceipt{request_fingerprint: fingerprint, command_iri: command_iri}
        when fingerprint == change_set.request_fingerprint and
               command_iri == envelope.command_iri ->
          {:ok, semantic_receipt(:already_committed, envelope, change_set, identities, receipt)}

        %WriteReceipt{} ->
          {:error, Error.new(:conflict, :command_idempotency_reuse)}
      end
    end
  end

  defp commit_new(envelope, definition, change_set, identities, store_server, deadline) do
    with {:ok, audit_graph} <- AuditPolicy.graph_iri(envelope.issued_at),
         {:ok, policy_graph} <- GraphRegistry.graph_iri(:factory_policy, %{}),
         snapshot_graphs =
           Enum.uniq(
             change_set.target_graphs ++
               Map.keys(envelope.expected_graph_revisions) ++ [audit_graph, policy_graph]
           ),
         {:ok, snapshot} <-
           request(store_server, {:semantic_snapshot, snapshot_graphs}, deadline),
         {:ok, authority} <- Authorization.authorize(envelope, definition, change_set, snapshot),
         provenance =
           CommandProvenance.quads(envelope, change_set, authority, identities, audit_graph),
         {:ok, audit} <- audit_partition(envelope, snapshot, audit_graph, provenance),
         :ok <- AuditPolicy.validate(audit.additions),
         {:ok, _reports} <-
           CommandPrecommit.validate(
             envelope,
             change_set,
             snapshot,
             audit,
             deadline
           ),
         {:ok, batch} <-
           build_batch(envelope, change_set, identities, audit),
         {:ok, receipt} <- request(store_server, {:atomic_update, batch}, deadline) do
      {:ok, semantic_receipt(:committed, envelope, change_set, identities, receipt)}
    end
  end

  defp build_batch(envelope, change_set, identities, audit) do
    graph_revisions =
      change_set.expected_graph_revisions
      |> Map.take(change_set.target_graphs)
      |> Map.put(audit.graph_iri, audit.expected_graph_revision)

    WriteBatch.new(change_set.additions ++ audit.additions,
      commit_id: identities.commit_id,
      removals: change_set.removals,
      removal_policy: if(change_set.removals == [], do: :forbid, else: :maintenance),
      expected_dataset_revision: envelope.expected_dataset_revision,
      expected_graph_revisions: graph_revisions,
      operation_metadata: %{
        class: :semantic_command,
        command_iri: envelope.command_iri,
        command_type: envelope.command_type,
        command_version: envelope.command_version,
        request_fingerprint: change_set.request_fingerprint,
        registry_version: envelope.command_version
      }
    )
  end

  defp audit_partition(envelope, snapshot, graph, provenance) do
    case Map.get(snapshot.graph_metadata, graph) do
      metadata when is_map(metadata) ->
        {:ok,
         %{
           graph_iri: graph,
           operation: :append,
           metadata: metadata,
           expected_graph_revision: Map.fetch!(snapshot.graph_revisions, graph),
           additions: provenance
         }}

      nil ->
        create_audit_partition(envelope, snapshot, graph, provenance)
    end
  end

  defp create_audit_partition(envelope, snapshot, graph, provenance) do
    with {:ok, policy_graph} <- GraphRegistry.graph_iri(:factory_policy, %{}),
         policy_metadata when is_map(policy_metadata) <-
           Map.get(snapshot.graph_metadata, policy_graph),
         {:ok, metadata} <-
           GraphMetadata.new(graph, %{
             owner_scope: policy_metadata.owner_scope,
             ontology_version: "https://jido.run/ontology/release/#{envelope.ontology_version}",
             creation_activity: envelope.command_iri,
             created_at: envelope.issued_at,
             lifecycle_state: :open,
             completeness_state: :complete,
             graph_revision: 1
           }),
         {:ok, metadata_quads} <- GraphMetadata.quads(metadata) do
      {:ok,
       %{
         graph_iri: graph,
         operation: :create,
         metadata: metadata,
         expected_graph_revision: 0,
         additions: metadata_quads ++ provenance
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      _missing -> {:error, Error.new(:unavailable, :audit_graph_required)}
    end
  end

  defp semantic_receipt(outcome, envelope, change_set, identities, receipt) do
    CommandReceipt.success(outcome, %{
      command_iri: envelope.command_iri,
      receipt_iri: identities.receipt_iri,
      change_set_iri: change_set.change_set_iri,
      dataset_revision: receipt.dataset_revision,
      graph_revisions: receipt.graph_revisions,
      affected_graphs: Map.keys(receipt.graph_revisions),
      assertion_count: change_set.assertion_count,
      supersession_count: change_set.supersession_count,
      actor_iri: envelope.actor_iri,
      committed_at: envelope.issued_at
    })
  end

  defp request(server, operation, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining > 0 do
      StoreServer.request(server, operation, remaining)
    else
      {:error, Error.new(:timeout, :semantic_command)}
    end
  catch
    :exit, {:timeout, _details} -> {:error, Error.new(:timeout, :semantic_command)}
    :exit, _reason -> {:error, Error.new(:unavailable, :semantic_command)}
  end

  defp normalize_outcome({:ok, %CommandReceipt{} = receipt}, _envelope), do: {:ok, receipt}

  defp normalize_outcome({:error, %Error{kind: :unauthorized}}, _envelope),
    do: {:ok, CommandReceipt.failure(:unauthorized)}

  defp normalize_outcome({:error, %Error{kind: kind}, current}, envelope)
       when kind in [:stale_precondition, :conflict] and is_map(current) do
    {:ok,
     CommandReceipt.failure(:conflicted,
       command_iri: envelope.command_iri,
       current_revisions: current
     )}
  end

  defp normalize_outcome({:error, %Error{} = error, report}, envelope) when is_map(report) do
    issues = Enum.map(Map.get(report, :issues, []), & &1.issue_code)

    {:ok,
     CommandReceipt.failure(outcome(error),
       command_iri: envelope.command_iri,
       issues: issues
     )}
  end

  defp normalize_outcome({:error, %Error{} = error}, envelope) do
    {:ok, CommandReceipt.failure(outcome(error), command_iri: envelope.command_iri)}
  end

  defp outcome(%Error{kind: :unauthorized}), do: :unauthorized
  defp outcome(%Error{kind: kind}) when kind in [:conflict, :stale_precondition], do: :conflicted
  defp outcome(%Error{kind: :invalid_input}), do: :invalid
  defp outcome(%Error{kind: :timeout}), do: :unknown_after_timeout
  defp outcome(%Error{}), do: :unavailable
end
