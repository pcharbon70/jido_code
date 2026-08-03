defmodule JidoCode.Factory.Scheduler do
  @moduledoc """
  Disposable scheduler rebuilt from graph-derived candidates and active leases.

  PubSub notifications only wake discovery. Selection uses deterministic
  priority, fairness, risk, provider, and admission ordering; the injected
  lease boundary remains the sole authority-granting operation.
  """

  use GenServer

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @max_candidates 1_000
  @max_concurrency 32
  @default_limits %{
    global: 16,
    repository: 2,
    cohort: 8,
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
    limits = Map.merge(@default_limits, Map.new(Keyword.get(options, :limits, [])))
    interval = Keyword.get(options, :rediscovery_interval_ms, 30_000)
    max_candidates = Keyword.get(options, :max_candidates, 200)
    max_concurrency = Keyword.get(options, :max_concurrency, 4)

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
       :last_results,
       :last_error
     ]), state}
  end

  @impl true
  def handle_cast(:discover, state) do
    send(self(), :discover)
    {:noreply, state}
  end

  @impl true
  def handle_info(:periodic_rediscovery, state) do
    send(self(), :discover)
    Process.send_after(self(), :periodic_rediscovery, state.interval)
    {:noreply, state}
  end

  def handle_info(:discover, state) do
    state = %{state | discovery_count: state.discovery_count + 1}

    case safe_discover(state.discover, state.max_candidates) do
      {:ok, candidates, active_leases} ->
        {selected, deferred} = select(candidates, active_leases, state.limits)
        outcomes = acquire(selected, state.acquire, state.max_concurrency)
        results = Enum.take(outcomes ++ deferred, 200)

        {:noreply,
         %{
           state
           | selected_count: state.selected_count + length(selected),
             deferred_count: state.deferred_count + length(deferred),
             last_results: results,
             last_error: nil
         }}

      {:error, %Error{} = error} ->
        {:noreply, %{state | last_error: error}}
    end
  end

  defp safe_discover(discover, maximum) do
    case discover.() do
      {:ok, candidates} when is_list(candidates) and length(candidates) <= maximum ->
        if Enum.all?(candidates, &valid_candidate?/1),
          do: {:ok, candidates, []},
          else: {:error, Error.new(:invalid_input, :scheduler_candidate)}

      {:ok, %{candidates: candidates, active_leases: active_leases}}
      when is_list(candidates) and is_list(active_leases) and length(candidates) <= maximum and
             length(active_leases) <= @max_candidates * 10 ->
        if Enum.all?(candidates, &valid_candidate?/1) and
             Enum.all?(active_leases, &valid_active_lease?/1),
           do: {:ok, candidates, active_leases},
           else: {:error, Error.new(:invalid_input, :scheduler_discovery_snapshot)}

      {:error, %Error{} = error} ->
        {:error, error}

      _invalid ->
        {:error, Error.new(:unavailable, :scheduler_discovery)}
    end
  rescue
    _error -> {:error, Error.new(:unavailable, :scheduler_discovery)}
  end

  defp select(candidates, active_leases, limits) do
    candidates
    |> Enum.sort_by(&{-&1.priority, &1.fairness, &1.risk, &1.task_iri})
    |> Enum.reduce({[], [], initial_usage(active_leases)}, fn
      candidate, {selected, deferred, usage} ->
        case admit(candidate, limits, usage) do
          {:ok, provider, next_usage} ->
            {[%{candidate: candidate, provider: provider} | selected], deferred, next_usage}

          {:defer, reasons} ->
            {selected,
             [%{task_iri: candidate.task_iri, outcome: :deferred, reasons: reasons} | deferred],
             usage}
        end
    end)
    |> then(fn {selected, deferred, _usage} ->
      {Enum.reverse(selected), Enum.reverse(deferred)}
    end)
  end

  defp admit(candidate, limits, usage) do
    provider = choose_provider(candidate.providers, usage, limits)
    repository_count = Map.get(usage.repositories, candidate.repository_iri, 0)

    cohort_full? =
      Enum.any?(candidate.cohort_iris, &(Map.get(usage.cohorts, &1, 0) >= limits.cohort))

    reasons =
      []
      |> add_reason(candidate.risk > limits.risk, :risk_limit)
      |> add_reason(usage.global >= limits.global, :global_capacity)
      |> add_reason(repository_count >= limits.repository, :repository_capacity)
      |> add_reason(cohort_full?, :cohort_capacity)
      |> add_reason(is_nil(provider), :capability_capacity)

    if reasons == [],
      do: {:ok, provider, increment_usage(usage, candidate, provider)},
      else: {:defer, Enum.reverse(reasons)}
  end

  defp choose_provider(providers, usage, limits) do
    providers
    |> Enum.sort_by(fn provider ->
      {Map.get(usage.providers, provider.holder_iri, 0), provider.holder_iri, provider.iri}
    end)
    |> Enum.find(fn provider ->
      assigned = Map.get(usage.providers, provider.holder_iri, 0)
      active = Map.get(provider, :active_leases, 0)
      declared = get_in(provider, [:limits, :concurrency]) || limits.capability
      max(active, assigned) < min(declared, limits.capability)
    end)
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

  defp valid_candidate?(candidate) do
    is_map(candidate) and Knowledge.validate_resource_identity(candidate[:task_iri]) == :ok and
      Knowledge.validate_resource_identity(candidate[:repository_iri]) == :ok and
      is_list(candidate[:cohort_iris]) and is_list(candidate[:providers]) and
      candidate[:providers] != [] and is_integer(candidate[:priority]) and
      is_integer(candidate[:fairness]) and is_integer(candidate[:risk]) and candidate.risk >= 0 and
      Enum.all?(candidate.providers, fn provider ->
        is_map(provider) and Knowledge.validate_resource_identity(provider[:iri]) == :ok and
          Knowledge.validate_resource_identity(provider[:holder_iri]) == :ok
      end)
  end

  defp valid_active_lease?(lease) do
    is_map(lease) and Knowledge.validate_resource_identity(lease[:repository_iri]) == :ok and
      Knowledge.validate_resource_identity(lease[:holder_iri]) == :ok and
      is_list(lease[:cohort_iris]) and
      Enum.all?(lease.cohort_iris, &(Knowledge.validate_resource_identity(&1) == :ok))
  end

  defp increment_usage(usage, candidate, provider) do
    %{
      global: usage.global + 1,
      repositories: Map.update(usage.repositories, candidate.repository_iri, 1, &(&1 + 1)),
      cohorts:
        Enum.reduce(
          candidate.cohort_iris,
          usage.cohorts,
          &Map.update(&2, &1, 1, fn count -> count + 1 end)
        ),
      providers:
        Map.put(
          usage.providers,
          provider.holder_iri,
          max(
            Map.get(usage.providers, provider.holder_iri, 0),
            Map.get(provider, :active_leases, 0)
          ) + 1
        )
    }
  end

  defp initial_usage(active_leases) do
    Enum.reduce(active_leases, empty_usage(), fn lease, usage ->
      %{
        global: usage.global + 1,
        repositories: Map.update(usage.repositories, lease.repository_iri, 1, &(&1 + 1)),
        cohorts:
          Enum.reduce(
            lease.cohort_iris,
            usage.cohorts,
            &Map.update(&2, &1, 1, fn count -> count + 1 end)
          ),
        providers: Map.update(usage.providers, lease.holder_iri, 1, &(&1 + 1))
      }
    end)
  end

  defp empty_usage, do: %{global: 0, repositories: %{}, cohorts: %{}, providers: %{}}

  defp valid_limits?(limits) do
    Enum.all?([:global, :repository, :cohort, :capability], fn key ->
      is_integer(limits[key]) and limits[key] > 0
    end) and is_integer(limits.risk) and limits.risk >= 0
  end

  defp add_reason(reasons, true, reason), do: [reason | reasons]
  defp add_reason(reasons, false, _reason), do: reasons
end
