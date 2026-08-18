defmodule JidoCode.Knowledge.Maintenance do
  @moduledoc """
  Serialized, fixed maintenance commands for the embedded graph store.
  """

  use GenServer

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Commands.Retention, as: RetentionCommand
  alias JidoCode.Knowledge.Retention.Plan
  alias JidoCode.Knowledge.Retention.Receipt, as: RetentionReceipt
  alias JidoCode.Knowledge.StoreServer

  @default_timeout 120_000

  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec backup(keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def backup(options \\ []) when is_list(options), do: backup(__MODULE__, options)

  @spec backup(GenServer.server(), keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def backup(server, options) when is_list(options) do
    call(server, :backup, options)
  end

  @spec export(:nquads | :trig, keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def export(format, options \\ []) when format in [:nquads, :trig] and is_list(options) do
    export(__MODULE__, format, options)
  end

  @spec export(GenServer.server(), :nquads | :trig, keyword()) ::
          {:ok, struct()} | {:error, Error.t()}
  def export(server, format, options) when is_list(options) do
    call(server, {:export, format}, options)
  end

  @spec integrity(keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def integrity(options \\ []) when is_list(options), do: integrity(__MODULE__, options)

  @spec integrity(GenServer.server(), keyword()) :: {:ok, struct()} | {:error, Error.t()}
  def integrity(server, options) when is_list(options) do
    call(server, :integrity, options)
  end

  @spec restore(String.t(), keyword()) :: {:ok, map()} | {:error, Error.t()}
  def restore(artifact_id, options \\ []) when is_binary(artifact_id) and is_list(options) do
    restore(__MODULE__, artifact_id, options)
  end

  @spec restore(GenServer.server(), String.t(), keyword()) ::
          {:ok, map()} | {:error, Error.t()}
  def restore(server, artifact_id, options) when is_binary(artifact_id) and is_list(options) do
    if Keyword.get(options, :confirm) == artifact_id do
      call(server, {:restore, artifact_id}, options)
    else
      {:error, Error.new(:invalid_input, :confirm_restore)}
    end
  end

  @spec retention_candidates(non_neg_integer(), keyword()) ::
          {:ok, [String.t()]} | {:error, Error.t()}
  def retention_candidates(keep_latest, options \\ [])
      when is_integer(keep_latest) and is_list(options) do
    retention_candidates(__MODULE__, keep_latest, options)
  end

  @spec retention_candidates(GenServer.server(), non_neg_integer(), keyword()) ::
          {:ok, [String.t()]} | {:error, Error.t()}
  def retention_candidates(server, keep_latest, options) when is_list(options) do
    call(server, {:retention_candidates, keep_latest}, options)
  end

  @spec apply_retention(Plan.t(), keyword()) ::
          {:ok, RetentionReceipt.t()} | {:error, Error.t()}
  def apply_retention(%Plan{} = plan, options \\ []) when is_list(options) do
    apply_retention(__MODULE__, plan, options)
  end

  @spec apply_retention(GenServer.server(), Plan.t(), keyword()) ::
          {:ok, RetentionReceipt.t()} | {:error, Error.t()}
  def apply_retention(server, %Plan{} = plan, options) when is_list(options) do
    if Keyword.get(options, :confirm) == plan.id do
      call(server, {:apply_retention, plan}, options)
    else
      {:error, Error.new(:invalid_input, :confirm_retention)}
    end
  end

  @impl true
  def init(options) do
    {:ok, %{store_server: Keyword.get(options, :store_server, StoreServer)}}
  end

  @impl true
  def handle_call(:backup, _from, state) do
    {:reply, StoreServer.request(state.store_server, :backup, @default_timeout), state}
  end

  def handle_call({:export, format}, _from, state) do
    {:reply, StoreServer.request(state.store_server, {:export, format}, @default_timeout), state}
  end

  def handle_call(:integrity, _from, state) do
    {:reply, StoreServer.request(state.store_server, :integrity, @default_timeout), state}
  end

  def handle_call({:restore, artifact_id}, _from, state) do
    result =
      with {:ok, _receipt} <-
             StoreServer.request(
               state.store_server,
               {:enter_maintenance, :restore},
               @default_timeout
             ) do
        StoreServer.request(state.store_server, {:restore, artifact_id}, @default_timeout)
      end

    {:reply, result, state}
  end

  def handle_call({:retention_candidates, keep_latest}, _from, state) do
    {:reply,
     StoreServer.request(
       state.store_server,
       {:retention_candidates, keep_latest},
       @default_timeout
     ), state}
  end

  def handle_call({:apply_retention, %Plan{} = plan}, _from, state) do
    {:reply, execute_retention(state.store_server, plan), state}
  end

  defp execute_retention(store_server, plan) do
    with {:ok, batch} <- RetentionCommand.batch(plan),
         {:ok, checkpoint} <- StoreServer.request(store_server, :backup, @default_timeout),
         {:ok, _maintenance} <-
           StoreServer.request(
             store_server,
             {:enter_maintenance, :retention},
             @default_timeout
           ),
         {:ok, write_receipt} <- apply_and_leave(store_server, batch),
         {:ok, integrity} <- StoreServer.request(store_server, :integrity, @default_timeout),
         true <- integrity.status == :ok do
      {:ok,
       %RetentionReceipt{
         plan_id: plan.id,
         activity_iri: plan.activity_iri,
         checksum: plan.checksum,
         affected_graph_count: length(plan.affected_graphs),
         archived_resource_count: length(plan.archive),
         removed_resource_count: length(plan.remove),
         erased_resource_count: length(plan.erase),
         removal_count: write_receipt.removals_count,
         dataset_revision: write_receipt.dataset_revision,
         checkpoint_artifact_id: checkpoint.artifact_id,
         integrity_status: integrity.status,
         rebuild_graphs: plan.rebuild_graphs
       }}
    else
      {:error, %Error{} = error} -> {:error, error}
      false -> {:error, Error.new(:corrupt, :retention_integrity)}
      _invalid -> {:error, Error.new(:unavailable, :retention_execution)}
    end
  end

  defp apply_and_leave(store_server, batch) do
    result =
      StoreServer.request(store_server, {:retention_apply, batch}, @default_timeout)

    leave = StoreServer.request(store_server, :leave_maintenance, @default_timeout)

    case {result, leave} do
      {{:ok, write_receipt}, {:ok, _health}} -> {:ok, write_receipt}
      {{:error, %Error{} = error}, _leave} -> {:error, error}
      {_result, {:error, %Error{} = error}} -> {:error, error}
      _invalid -> {:error, Error.new(:unavailable, :retention_execution)}
    end
  end

  defp call(server, request, options) do
    timeout = Keyword.get(options, :caller_timeout, @default_timeout + 1_000)
    GenServer.call(server, request, timeout)
  catch
    :exit, {:timeout, _details} -> {:error, Error.new(:timeout, :maintenance_request)}
    :exit, _reason -> {:error, Error.new(:unavailable, :maintenance_request)}
  end
end
