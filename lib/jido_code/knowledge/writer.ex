defmodule JidoCode.Knowledge.Writer do
  @moduledoc """
  Serialized ingress for persistent graph mutation.

  Callers retain the batch commit identity before submission. A caller timeout
  is therefore an unknown response, not evidence that the commit is absent;
  `lookup/3` resolves the durable outcome by that identity.
  """

  use GenServer

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Telemetry
  alias JidoCode.Knowledge.WriteBatch

  @default_operation_timeout 5_000
  @max_operation_timeout 120_000

  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec commit(WriteBatch.t(), keyword()) :: term()
  def commit(%WriteBatch{} = batch, options \\ []) do
    commit(__MODULE__, batch, options)
  end

  @spec commit(GenServer.server(), WriteBatch.t(), keyword()) :: term()
  def commit(server, %WriteBatch{} = batch, options) when is_list(options) do
    with {:ok, operation_timeout, caller_timeout} <- timeouts(options) do
      deadline = System.monotonic_time(:millisecond) + operation_timeout
      enqueued_at = System.monotonic_time()
      safe_call(server, {:commit, batch, deadline, enqueued_at}, caller_timeout, :commit_response)
    end
  end

  @spec lookup(String.t(), keyword()) :: term()
  def lookup(commit_id, options \\ []) when is_binary(commit_id) do
    lookup(__MODULE__, commit_id, options)
  end

  @spec lookup(GenServer.server(), String.t(), keyword()) :: term()
  def lookup(server, commit_id, options) when is_binary(commit_id) and is_list(options) do
    timeout = Keyword.get(options, :timeout, @default_operation_timeout)

    if valid_timeout?(timeout) do
      safe_call(server, {:lookup, commit_id, timeout}, timeout + 1_000, :receipt_lookup)
    else
      {:error, Error.new(:invalid_input, :write_deadline)}
    end
  end

  @impl true
  def init(options) do
    {:ok, %{store_server: Keyword.get(options, :store_server, StoreServer)}}
  end

  @impl true
  def handle_call({:commit, %WriteBatch{} = batch, deadline, enqueued_at}, _from, state) do
    remaining = deadline - System.monotonic_time(:millisecond)
    queue_duration = max(System.monotonic_time() - enqueued_at, 0)

    reply =
      Telemetry.span(:commit, %{queue_duration: queue_duration}, fn ->
        if remaining > 0 do
          safe_store_request(
            state.store_server,
            {:atomic_update, batch},
            remaining,
            :atomic_commit
          )
        else
          {:error, Error.new(:timeout, :atomic_commit)}
        end
      end)

    {:reply, reply, state}
  end

  def handle_call({:lookup, commit_id, timeout}, _from, state) do
    reply =
      safe_store_request(state.store_server, {:receipt, commit_id}, timeout, :receipt_lookup)

    {:reply, reply, state}
  end

  defp timeouts(options) do
    operation_timeout = Keyword.get(options, :operation_timeout, @default_operation_timeout)
    caller_timeout = Keyword.get(options, :caller_timeout, operation_timeout + 1_000)

    if valid_timeout?(operation_timeout) and
         is_integer(caller_timeout) and caller_timeout >= 0 and
         caller_timeout <= @max_operation_timeout + 1_000 do
      {:ok, operation_timeout, caller_timeout}
    else
      {:error, Error.new(:invalid_input, :write_deadline)}
    end
  end

  defp valid_timeout?(timeout) do
    is_integer(timeout) and timeout > 0 and timeout <= @max_operation_timeout
  end

  defp safe_call(server, request, timeout, operation) do
    GenServer.call(server, request, timeout)
  catch
    :exit, {:timeout, _details} -> {:error, Error.new(:timeout, operation)}
    :exit, _reason -> {:error, Error.new(:unavailable, operation)}
  end

  defp safe_store_request(store_server, request, timeout, operation) do
    StoreServer.request(store_server, request, max(timeout, 1))
  catch
    :exit, {:timeout, _details} -> {:error, Error.new(:timeout, operation)}
    :exit, _reason -> {:error, Error.new(:unavailable, operation)}
  end
end
