defmodule JidoCode.Runtime.JidoHarness.RunRegistry do
  @moduledoc "BEAM-lifetime-only registry for disposable JidoHarness references."

  use GenServer

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Runtime.JidoHarness.RunRecord

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: Keyword.get(options, :name, __MODULE__))
  end

  @spec prepare(GenServer.server(), Request.t(), map()) ::
          {:ok, RunRecord.t()} | {:error, AdapterError.t()}
  def prepare(server \\ __MODULE__, %Request{} = request, profile) do
    GenServer.call(server, {:prepare, request, profile})
  end

  @spec fetch(GenServer.server(), Request.t()) :: {:ok, RunRecord.t()} | :error
  def fetch(server \\ __MODULE__, %Request{} = request) do
    GenServer.call(server, {:fetch, Request.runtime_key(request)})
  end

  @spec started(GenServer.server(), Request.t(), map()) ::
          {:ok, RunRecord.t()} | {:error, AdapterError.t()}
  def started(server \\ __MODULE__, %Request{} = request, receipt) do
    GenServer.call(server, {:started, Request.runtime_key(request), receipt})
  end

  @spec observe(GenServer.server(), Request.t(), [map()]) ::
          {:ok, RunRecord.t()} | {:error, AdapterError.t()}
  def observe(server \\ __MODULE__, %Request{} = request, observations)
      when is_list(observations) do
    GenServer.call(server, {:observe, Request.runtime_key(request), observations})
  end

  @spec finish(GenServer.server(), Request.t(), atom(), map()) ::
          {:ok, RunRecord.t()} | {:error, AdapterError.t()}
  def finish(server \\ __MODULE__, %Request{} = request, state, final) do
    GenServer.call(server, {:finish, Request.runtime_key(request), state, final})
  end

  @spec delete(GenServer.server(), Request.t()) :: :ok
  def delete(server \\ __MODULE__, %Request{} = request) do
    GenServer.call(server, {:delete, Request.runtime_key(request)})
  end

  @impl true
  def init(_state), do: {:ok, %{}}

  @impl true
  def handle_call({:prepare, request, profile}, _from, state) do
    key = Request.runtime_key(request)
    profile_name = profile[:name]

    case Map.fetch(state, key) do
      {:ok, record}
      when record.attempt_iri == request.attempt_iri and
             record.fencing_token == request.fencing_token and
             record.profile_name == profile_name ->
        {:reply, {:ok, record}, state}

      {:ok, _record} ->
        {:reply, {:error, AdapterError.new(:conflict, :jido_harness_run)}, state}

      :error ->
        case RunRecord.new(request, profile) do
          {:ok, record} -> {:reply, {:ok, record}, Map.put(state, key, record)}
          {:error, %AdapterError{} = error} -> {:reply, {:error, error}, state}
        end
    end
  end

  def handle_call({:fetch, key}, _from, state) do
    case Map.fetch(state, key) do
      {:ok, record} -> {:reply, {:ok, record}, state}
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:started, key, receipt}, _from, state) do
    update_record(state, key, &RunRecord.start(&1, receipt))
  end

  def handle_call({:observe, key, observations}, _from, state) do
    update_record(state, key, fn record ->
      Enum.reduce_while(observations, {:ok, record}, fn observation, {:ok, current} ->
        case RunRecord.observe(current, observation) do
          {:ok, updated} -> {:cont, {:ok, updated}}
          {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
        end
      end)
    end)
  end

  def handle_call({:finish, key, status, final}, _from, state) do
    update_record(state, key, &RunRecord.finish(&1, status, final))
  end

  def handle_call({:delete, key}, _from, state),
    do: {:reply, :ok, Map.delete(state, key)}

  defp update_record(state, key, function) do
    with {:ok, record} <- Map.fetch(state, key),
         {:ok, updated} <- function.(record) do
      {:reply, {:ok, updated}, Map.put(state, key, updated)}
    else
      :error -> {:reply, {:error, AdapterError.new(:unavailable, :jido_harness_run)}, state}
      {:error, %AdapterError{} = error} -> {:reply, {:error, error}, state}
    end
  end
end
