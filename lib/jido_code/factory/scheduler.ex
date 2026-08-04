defmodule JidoCode.Factory.Scheduler do
  @moduledoc """
  Disposable scheduler rebuilt from graph-derived candidates and active leases.

  PubSub notifications only wake discovery. Selection uses deterministic
  priority, fairness, risk, provider, and admission ordering; the injected
  lease boundary remains the sole authority-granting operation.
  """

  use GenServer

  alias JidoCode.Factory.Fleet.Admission
  alias JidoCode.Factory.Fleet.Policy
  alias JidoCode.Knowledge.Error
  alias JidoCode.Observability

  @max_candidates 1_000
  @max_concurrency 32
  @default_limits %{
    global: 16,
    repository: 2,
    cohort: 8,
    provider: 4,
    capability: 4,
    risk: 10
  }

  def start_link(options) do
    name = Keyword.get(options, :name, __MODULE__)

    if is_nil(name),
      do: GenServer.start_link(__MODULE__, options),
      else: GenServer.start_link(__MODULE__, options, name: name)
  end

  @spec trigger(GenServer.server()) :: :ok
  def trigger(server \\ __MODULE__), do: GenServer.cast(server, :discover)

  @spec rediscover(GenServer.server()) :: :ok
  def rediscover(server \\ __MODULE__), do: trigger(server)

  @spec status(GenServer.server()) :: map()
  def status(server \\ __MODULE__), do: GenServer.call(server, :status)

  @impl true
  def init(options) do
    discover = Keyword.get(options, :discover)
    acquire = Keyword.get(options, :acquire)
    interval = Keyword.get(options, :rediscovery_interval_ms, 30_000)
    max_candidates = Keyword.get(options, :max_candidates, 200)
    max_concurrency = Keyword.get(options, :max_concurrency, 4)

    limits =
      @default_limits
      |> Map.merge(Map.new(Keyword.get(options, :limits, [])))
      |> Map.put(:max_candidates, max_candidates)

    with true <- is_function(discover, 0),
         true <- is_function(acquire, 2),
         true <- valid_limits?(limits),
         true <- interval in 10..300_000,
         true <- max_candidates in 1..@max_candidates,
         true <- max_concurrency in 1..@max_concurrency do
      send(self(), :discover)
      Process.send_after(self(), :periodic_rediscovery, interval)

      {:ok,
       %{
         discover: discover,
         acquire: acquire,
         limits: limits,
         interval: interval,
         max_candidates: max_candidates,
         max_concurrency: max_concurrency,
         discovery_count: 0,
         selected_count: 0,
         deferred_count: 0,
         coalesced_discovery_count: 0,
         discovery_scheduled?: true,
         last_results: [],
         last_error: nil
       }}
    else
      _invalid -> {:stop, {:invalid_scheduler_options, options}}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply,
     Map.take(state, [
       :discovery_count,
       :selected_count,
       :deferred_count,
       :coalesced_discovery_count,
       :last_results,
       :last_error
     ]), state}
  end

  @impl true
  def handle_cast(:discover, state) do
    {:noreply, schedule_discovery(state)}
  end

  @impl true
  def handle_info(:periodic_rediscovery, state) do
    Process.send_after(self(), :periodic_rediscovery, state.interval)
    {:noreply, schedule_discovery(state)}
  end

  def handle_info(:discover, state) do
    state = %{
      state
      | discovery_count: state.discovery_count + 1,
        discovery_scheduled?: false
    }

    case Observability.span(:scheduling, fn ->
           safe_discover(state.discover, state.max_candidates)
         end) do
      {:ok, candidates, active_leases, graph_policy} ->
        with {:ok, policy} <- Policy.resolve(graph_policy, state.limits),
             {:ok, admission} <- Admission.select(candidates, active_leases, policy) do
          outcomes = acquire(admission.selected, state.acquire, state.max_concurrency)
          results = Enum.take(outcomes ++ admission.deferred, 200)

          {:noreply,
           %{
             state
             | selected_count: state.selected_count + length(admission.selected),
               deferred_count: state.deferred_count + length(admission.deferred),
               last_results: results,
               last_error: nil
           }}
        else
          {:error, %Error{} = error} -> {:noreply, %{state | last_error: error}}
        end

      {:error, %Error{} = error} ->
        {:noreply, %{state | last_error: error}}
    end
  end

  defp safe_discover(discover, maximum) do
    case discover.() do
      {:ok, candidates} when is_list(candidates) and length(candidates) <= maximum ->
        {:ok, candidates, [], %{}}

      {:ok, %{candidates: candidates, active_leases: active_leases} = snapshot}
      when is_list(candidates) and is_list(active_leases) and length(candidates) <= maximum and
             length(active_leases) <= @max_candidates * 10 ->
        case Map.get(snapshot, :fleet_policy, %{}) do
          graph_policy when is_map(graph_policy) ->
            {:ok, candidates, active_leases, graph_policy}

          _invalid ->
            {:error, Error.new(:invalid_input, :scheduler_discovery_snapshot)}
        end

      {:error, %Error{} = error} ->
        {:error, error}

      _invalid ->
        {:error, Error.new(:unavailable, :scheduler_discovery)}
    end
  rescue
    _error -> {:error, Error.new(:unavailable, :scheduler_discovery)}
  end

  defp acquire(selected, acquire, max_concurrency) do
    selected
    |> Task.async_stream(
      fn selection ->
        outcome = safe_acquire(acquire, selection.candidate, selection.provider)

        %{
          task_iri: selection.candidate.task_iri,
          provider_iri: selection.provider.holder_iri,
          outcome: outcome
        }
      end,
      max_concurrency: max_concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.map(fn
      {:ok, result} ->
        result

      {:exit, _reason} ->
        %{task_iri: nil, outcome: {:error, Error.new(:unavailable, :scheduler_task)}}
    end)
  end

  defp safe_acquire(acquire, candidate, provider) do
    case acquire.(candidate, provider) do
      :ok -> :acquired
      {:ok, value} -> {:acquired, value}
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:unavailable, :scheduler_acquisition)}
    end
  rescue
    _error -> {:error, Error.new(:unavailable, :scheduler_acquisition)}
  end

  defp valid_limits?(limits) do
    Enum.all?([:global, :repository, :cohort, :provider, :capability], fn key ->
      is_integer(limits[key]) and limits[key] > 0
    end) and is_integer(limits.risk) and limits.risk >= 0
  end

  defp schedule_discovery(%{discovery_scheduled?: false} = state) do
    send(self(), :discover)
    %{state | discovery_scheduled?: true}
  end

  defp schedule_discovery(state) do
    %{state | coalesced_discovery_count: state.coalesced_discovery_count + 1}
  end
end
