defmodule JidoCode.Factory.Reconciler do
  @moduledoc """
  Restart-safe, graph-rebuildable reconciliation coordinator.

  Process state contains only coalesced wakeups and diagnostics. Candidate and
  incomplete activity truth is rediscovered through the injected reviewed-query
  boundary whenever this process starts.
  """

  use GenServer

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Error

  @max_candidates 1_000
  @max_concurrency 32

  def start_link(options) do
    name = Keyword.get(options, :name, __MODULE__)

    if is_nil(name),
      do: GenServer.start_link(__MODULE__, options),
      else: GenServer.start_link(__MODULE__, options, name: name)
  end

  @spec trigger(GenServer.server(), map()) :: :ok
  def trigger(server \\ __MODULE__, candidate), do: GenServer.cast(server, {:trigger, candidate})

  @spec cancel(GenServer.server(), String.t()) :: :ok
  def cancel(server \\ __MODULE__, scope_iri), do: GenServer.cast(server, {:cancel, scope_iri})

  @spec rediscover(GenServer.server()) :: :ok
  def rediscover(server \\ __MODULE__), do: GenServer.cast(server, :rediscover)

  @spec status(GenServer.server()) :: map()
  def status(server \\ __MODULE__), do: GenServer.call(server, :status)

  @impl true
  def init(options) do
    discover = Keyword.get(options, :discover)
    reconcile = Keyword.get(options, :reconcile)
    max_concurrency = Keyword.get(options, :max_concurrency, 4)
    max_candidates = Keyword.get(options, :max_candidates, 200)
    retry_delay_ms = Keyword.get(options, :retry_delay_ms, 250)

    with true <- is_function(discover, 0),
         true <- is_function(reconcile, 1),
         true <- max_concurrency in 1..@max_concurrency,
         true <- max_candidates in 1..@max_candidates,
         true <- is_integer(retry_delay_ms) and retry_delay_ms in 1..60_000 do
      state = %{
        discover: discover,
        reconcile: reconcile,
        max_concurrency: max_concurrency,
        max_candidates: max_candidates,
        retry_delay_ms: retry_delay_ms,
        pending: %{},
        cancelled: MapSet.new(),
        draining?: false,
        discovery_count: 0,
        processed_count: 0,
        last_results: [],
        last_error: nil
      }

      send(self(), :discover)
      {:ok, state}
    else
      _invalid -> {:stop, {:invalid_reconciler_options, options}}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply,
     %{
       pending_count: map_size(state.pending),
       draining?: state.draining?,
       discovery_count: state.discovery_count,
       processed_count: state.processed_count,
       last_results: state.last_results,
       last_error: state.last_error
     }, state}
  end

  @impl true
  def handle_cast({:trigger, candidate}, state) do
    {:noreply, state |> enqueue(candidate) |> schedule_drain()}
  end

  def handle_cast({:cancel, scope_iri}, state) do
    if Knowledge.validate_resource_identity(scope_iri) == :ok do
      {:noreply,
       %{
         state
         | pending: Map.delete(state.pending, scope_iri),
           cancelled: MapSet.put(state.cancelled, scope_iri)
       }}
    else
      {:noreply, %{state | last_error: Error.new(:invalid_input, :reconciler_cancel)}}
    end
  end

  def handle_cast(:rediscover, state) do
    send(self(), :discover)
    {:noreply, state}
  end

  @impl true
  def handle_info(:discover, state) do
    state = %{state | discovery_count: state.discovery_count + 1}

    case safe_discover(state.discover) do
      {:ok, candidates} ->
        {:noreply, candidates |> Enum.reduce(state, &enqueue(&2, &1)) |> schedule_drain()}

      {:error, %Error{} = error} ->
        Process.send_after(self(), :discover, state.retry_delay_ms)
        {:noreply, %{state | last_error: error}}
    end
  end

  def handle_info(:drain, %{draining?: false} = state) do
    candidates =
      state.pending
      |> Map.values()
      |> Enum.reject(&MapSet.member?(state.cancelled, &1.scope_iri))
      |> Enum.sort_by(&{Map.get(&1, :priority, 0) * -1, &1.scope_iri})

    state = %{state | pending: %{}, draining?: true}
    results = run_candidates(candidates, state.reconcile, state.max_concurrency)

    Enum.each(results, fn
      %{outcome: {:retry, candidate}} ->
        Process.send_after(self(), {:retry, candidate}, state.retry_delay_ms)

      _result ->
        :ok
    end)

    next = %{
      state
      | draining?: false,
        processed_count: state.processed_count + length(results),
        last_results: Enum.take(results, 100),
        last_error: nil
    }

    {:noreply, schedule_drain(next)}
  end

  def handle_info(:drain, state), do: {:noreply, state}

  def handle_info({:retry, candidate}, state) do
    {:noreply, state |> enqueue(candidate) |> schedule_drain()}
  end

  defp run_candidates(candidates, reconcile, max_concurrency) do
    candidates
    |> Task.async_stream(
      fn candidate ->
        %{scope_iri: candidate.scope_iri, outcome: safe_reconcile(reconcile, candidate)}
      end,
      max_concurrency: max_concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.map(fn
      {:ok, result} ->
        result

      {:exit, _reason} ->
        %{
          scope_iri: nil,
          outcome: {:error, Error.new(:unavailable, :reconciler_task)}
        }
    end)
  end

  defp safe_discover(discover) do
    case discover.() do
      {:ok, candidates} when is_list(candidates) -> {:ok, candidates}
      {:error, %Error{} = error} -> {:error, error}
      _invalid -> {:error, Error.new(:unavailable, :reconciler_discovery)}
    end
  rescue
    _error -> {:error, Error.new(:unavailable, :reconciler_discovery)}
  end

  defp safe_reconcile(reconcile, candidate) do
    reconcile.(candidate)
  rescue
    _error -> {:error, Error.new(:unavailable, :reconciler_execution)}
  end

  defp enqueue(state, %{scope_iri: scope_iri} = candidate) do
    cond do
      Knowledge.validate_resource_identity(scope_iri) != :ok ->
        %{state | last_error: Error.new(:invalid_input, :reconciler_candidate)}

      MapSet.member?(state.cancelled, scope_iri) ->
        state

      map_size(state.pending) >= state.max_candidates and
          not Map.has_key?(state.pending, scope_iri) ->
        %{state | last_error: Error.new(:conflict, :reconciler_capacity)}

      true ->
        pending = Map.update(state.pending, scope_iri, candidate, &newer_candidate(&1, candidate))
        %{state | pending: pending}
    end
  end

  defp enqueue(state, _candidate),
    do: %{state | last_error: Error.new(:invalid_input, :reconciler_candidate)}

  defp newer_candidate(existing, candidate) do
    if Map.get(candidate, :dataset_revision, 0) >= Map.get(existing, :dataset_revision, 0),
      do: candidate,
      else: existing
  end

  defp schedule_drain(%{draining?: false, pending: pending} = state)
       when map_size(pending) > 0 do
    send(self(), :drain)
    state
  end

  defp schedule_drain(state), do: state
end
