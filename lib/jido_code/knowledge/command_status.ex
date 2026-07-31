defmodule JidoCode.Knowledge.CommandStatus do
  @moduledoc """
  Authorization-gated projection of a semantic command's durable outcome.

  Lookup requires the original validated command envelope. This binds the
  command IRI and idempotency identity to current semantic authority; an
  idempotency key by itself cannot be queried.
  """

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.AuditPolicy
  alias JidoCode.Knowledge.ChangeSet
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandProvenance
  alias JidoCode.Knowledge.CommandRegistry
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.WriteReceipt

  @outcomes [:unknown, :staged, :committed, :rejected, :superseded, :inaccessible]

  @derive {Inspect,
           only: [
             :outcome,
             :command_iri,
             :receipt_iri,
             :dataset_revision,
             :graph_revisions,
             :retry
           ]}
  @enforce_keys [:outcome, :retry]
  defstruct [
    :outcome,
    :retry,
    :command_iri,
    :receipt_iri,
    :dataset_revision,
    :graph_revisions
  ]

  @type outcome :: :unknown | :staged | :committed | :rejected | :superseded | :inaccessible
  @type t :: %__MODULE__{}

  @spec lookup(CommandEnvelope.t(), GenServer.server(), integer(), DateTime.t()) ::
          {:ok, t()} | {:error, Error.t()}
  def lookup(%CommandEnvelope{} = envelope, store_server, deadline, %DateTime{} = lookup_time)
      when is_integer(deadline) do
    result =
      with {:ok, definition} <-
             CommandRegistry.resolve(envelope.command_type, envelope.command_version),
           {:ok, change_set} <- ChangeSet.new(envelope),
           {:ok, identities} <- CommandProvenance.identities(envelope),
           {:ok, audit_graph} <- AuditPolicy.graph_iri(envelope.issued_at),
           {:ok, policy_graph} <- GraphRegistry.graph_iri(:factory_policy, %{}),
           snapshot_graphs = Enum.uniq(change_set.target_graphs ++ [policy_graph]),
           {:ok, snapshot} <-
             request(store_server, {:semantic_snapshot, snapshot_graphs}, deadline),
           {:ok, _authority} <-
             Authorization.authorize_at(
               envelope,
               definition,
               change_set,
               snapshot,
               lookup_time
             ),
           {:ok, semantic_outcome} <-
             request(
               store_server,
               {:command_outcome,
                %{
                  audit_graph: audit_graph,
                  command_iri: envelope.command_iri,
                  receipt_iri: identities.receipt_iri
                }},
               deadline
             ),
           {:ok, receipt} <- request(store_server, {:receipt, identities.commit_id}, deadline) do
        project(semantic_outcome, receipt, envelope, change_set, identities)
      end

    conceal(result)
  rescue
    _error -> {:ok, inaccessible()}
  catch
    _kind, _reason -> {:ok, inaccessible()}
  end

  def lookup(_envelope, _store_server, _deadline, _lookup_time), do: {:ok, inaccessible()}

  @spec outcomes() :: [outcome()]
  def outcomes, do: @outcomes

  @spec inaccessible() :: t()
  def inaccessible, do: %__MODULE__{outcome: :inaccessible, retry: :never}

  defp project(nil, nil, envelope, _change_set, _identities) do
    {:ok,
     %__MODULE__{
       outcome: :unknown,
       retry: :submit_or_retry,
       command_iri: envelope.command_iri
     }}
  end

  defp project(
         semantic_outcome,
         %WriteReceipt{request_fingerprint: fingerprint, command_iri: command_iri} = receipt,
         envelope,
         change_set,
         identities
       )
       when semantic_outcome in [:committed, :rejected, :superseded] and
              fingerprint == change_set.request_fingerprint and
              command_iri == envelope.command_iri do
    {:ok,
     %__MODULE__{
       outcome: semantic_outcome,
       retry: :never,
       command_iri: envelope.command_iri,
       receipt_iri: identities.receipt_iri,
       dataset_revision: receipt.dataset_revision,
       graph_revisions: receipt.graph_revisions
     }}
  end

  defp project(
         _semantic_outcome,
         %WriteReceipt{},
         _envelope,
         _change_set,
         _identities
       ),
       do: {:ok, inaccessible()}

  defp project(_semantic_outcome, _receipt, _envelope, _change_set, _identities),
    do: {:error, Error.new(:corrupt, :command_status)}

  defp conceal({:ok, %__MODULE__{} = status}), do: {:ok, status}
  defp conceal({:error, %Error{kind: :unauthorized}}), do: {:ok, inaccessible()}
  defp conceal({:error, %Error{kind: :invalid_input}}), do: {:ok, inaccessible()}
  defp conceal({:error, %Error{} = error}), do: {:error, error}

  defp request(server, operation, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    if remaining > 0 do
      StoreServer.request(server, operation, remaining)
    else
      {:error, Error.new(:timeout, :command_status)}
    end
  catch
    :exit, {:timeout, _details} -> {:error, Error.new(:timeout, :command_status)}
    :exit, _reason -> {:error, Error.new(:unavailable, :command_status)}
  end
end
