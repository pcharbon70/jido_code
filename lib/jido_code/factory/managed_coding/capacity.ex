defmodule JidoCode.Factory.ManagedCoding.Capacity do
  @moduledoc "Pure bounded and tenant-fair admission scheduler with low-cardinality health evidence."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CapacityConfig

  @dimensions ~w[tenant repository provider sandbox verifier adapter]a
  @metrics ~w[directive_latency_ms budget_burn crashes retries ambiguity cancellation_lag_ms verifier_lag_ms resource_saturation]a
  @enforce_keys ~w[config active queue last_tenant counters metrics alerts]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(CapacityConfig.t()) :: t()
  def new(%CapacityConfig{} = config) do
    %__MODULE__{
      config: config,
      active: [],
      queue: [],
      last_tenant: nil,
      counters: %{rejected: 0, deferred: 0, expired: 0, completed: 0},
      metrics: Map.new(@metrics, &{&1, []}),
      alerts: []
    }
  end

  @spec admit(t(), map(), non_neg_integer()) ::
          {:admit, t()} | {:defer, t()} | {:reject, atom(), t()}
  def admit(%__MODULE__{} = state, request, now_ms) when is_map(request) and is_integer(now_ms) do
    with :ok <- request(request) do
      state = expire(state, now_ms)

      cond do
        available?(state, request) -> {:admit, %{state | active: [request | state.active]}}
        queue_available?(state, request) -> {:defer, enqueue(state, request, now_ms)}
        true -> {:reject, :capacity_exhausted, count(state, :rejected)}
      end
    else
      _invalid -> {:reject, :invalid_request, state}
    end
  end

  @spec release(t(), String.t(), non_neg_integer()) :: {t(), map() | nil}
  def release(%__MODULE__{} = state, attempt_iri, now_ms) when is_binary(attempt_iri) do
    state = %{state | active: Enum.reject(state.active, &(&1.attempt_iri == attempt_iri))}
    state = state |> count(:completed) |> expire(now_ms)

    case next_fair(state) do
      nil ->
        {state, nil}

      queued ->
        request = Map.drop(queued, [:queued_at, :expires_at])

        if available?(state, request) do
          next = %{
            state
            | active: [request | state.active],
              queue: Enum.reject(state.queue, &(&1.attempt_iri == queued.attempt_iri)),
              last_tenant: request.tenant
          }

          {next, request}
        else
          {state, nil}
        end
    end
  end

  @spec measure(t(), atom(), non_neg_integer()) :: {:ok, t()} | {:error, AdapterError.t()}
  def measure(%__MODULE__{} = state, metric, value)
      when metric in @metrics and is_integer(value) and value >= 0 do
    samples = [value | state.metrics[metric]] |> Enum.take(128)
    {:ok, %{state | metrics: Map.put(state.metrics, metric, samples)}}
  end

  def measure(_state, _metric, _value),
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_capacity_metric)}

  @spec health(t(), non_neg_integer(), map()) :: map()
  def health(%__MODULE__{} = state, now_ms, evidence) when is_map(evidence) do
    queue_age = state.queue |> Enum.map(&(now_ms - &1.queued_at)) |> Enum.max(fn -> 0 end)

    alerts =
      []
      |> alert(queue_age > state.config.queue_ttl_ms, :sustained_capacity_pressure)
      |> alert(evidence[:stuck_attempts] > 0, :stuck_attempts)
      |> alert(evidence[:orphaned_leases] > 0, :orphaned_leases)
      |> alert(evidence[:orphaned_workspaces] > 0, :orphaned_workspaces)
      |> alert(evidence[:missing_outcomes] > 0, :missing_outcomes)
      |> alert(evidence[:fence_conflicts] > 0, :fence_conflicts)
      |> alert(evidence[:evidence_gaps] > 0, :evidence_gaps)

    %{
      status: if(alerts == [], do: :healthy, else: :degraded),
      queue_age_ms: queue_age,
      active_attempts: length(state.active),
      queued_attempts: length(state.queue),
      counters: state.counters,
      metrics: summarize(state.metrics),
      alerts: Enum.reverse(alerts)
    }
  end

  defp request(request) do
    fields = [:attempt_iri, :tenant, :repository, :provider, :sandbox, :verifier, :adapter]
    if Enum.all?(fields, &(is_binary(request[&1]) and request[&1] != "")), do: :ok, else: :error
  end

  defp available?(state, request) do
    global_limit =
      state.config.concurrency.global - if(request[:reserved], do: 0, else: state.config.reserved)

    length(state.active) < global_limit and
      Enum.all?(@dimensions, fn dimension ->
        count_dimension(state.active, dimension, request[dimension]) <
          state.config.concurrency[dimension]
      end)
  end

  defp queue_available?(state, request) do
    length(state.queue) < state.config.queue.global and
      Enum.all?(@dimensions, fn dimension ->
        count_dimension(state.queue, dimension, request[dimension]) <
          state.config.queue[dimension]
      end)
  end

  defp count_dimension(items, dimension, value), do: Enum.count(items, &(&1[dimension] == value))

  defp enqueue(state, request, now_ms) do
    queued =
      Map.merge(request, %{queued_at: now_ms, expires_at: now_ms + state.config.queue_ttl_ms})

    %{count(state, :deferred) | queue: state.queue ++ [queued]}
  end

  defp expire(state, now_ms) do
    {expired, current} = Enum.split_with(state.queue, &(&1.expires_at <= now_ms))
    counters = Map.update!(state.counters, :expired, &(&1 + length(expired)))
    %{state | queue: current, counters: counters}
  end

  defp next_fair(%{queue: []}), do: nil

  defp next_fair(state) do
    tenants = state.queue |> Enum.map(& &1.tenant) |> Enum.uniq() |> Enum.sort()

    next_tenant =
      Enum.find(tenants, &(state.last_tenant == nil or &1 > state.last_tenant)) || hd(tenants)

    Enum.find(state.queue, &(&1.tenant == next_tenant))
  end

  defp count(state, field), do: %{state | counters: Map.update!(state.counters, field, &(&1 + 1))}
  defp alert(alerts, true, name), do: [name | alerts]
  defp alert(alerts, _false, _name), do: alerts

  defp summarize(metrics) do
    Map.new(metrics, fn {metric, samples} ->
      {metric, %{count: length(samples), max: Enum.max(samples, fn -> 0 end)}}
    end)
  end
end
