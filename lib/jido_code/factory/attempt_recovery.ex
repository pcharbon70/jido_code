defmodule JidoCode.Factory.AttemptRecovery do
  @moduledoc "Startup and periodic graph-driven reconciliation of disposable attempt state."

  use GenServer

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Execution.Request
  alias JidoCode.Factory.ExecutionRuntime
  alias JidoCode.Factory.Recovery.Decision
  alias JidoCode.Knowledge

  @default_interval 30_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec ready?(GenServer.server()) :: boolean()
  def ready?(server \\ __MODULE__), do: GenServer.call(server, :ready?)

  @spec status(GenServer.server()) :: map()
  def status(server \\ __MODULE__), do: GenServer.call(server, :status)

  @spec recover_now(GenServer.server()) :: {:ok, map()} | {:error, AdapterError.t()}
  def recover_now(server \\ __MODULE__), do: GenServer.call(server, :recover, 120_000)

  @impl true
  def init(options) do
    state = %{
      ready?: false,
      recovering?: false,
      control_graphs: Keyword.get(options, :control_graphs, []),
      query: Keyword.get(options, :query),
      load_projection: Keyword.get(options, :load_projection),
      runtime_adapter: Keyword.get(options, :runtime_adapter),
      runtime_options: Keyword.get(options, :runtime_options, []),
      sandbox_inspector:
        Keyword.get(options, :sandbox_inspector, fn _request -> :not_configured end),
      transition: Keyword.get(options, :transition),
      orphan_inventory: Keyword.get(options, :orphan_inventory, fn -> {:ok, []} end),
      cleanup_orphan: Keyword.get(options, :cleanup_orphan, fn _ref -> :ok end),
      available_runtime_versions: Keyword.get(options, :available_runtime_versions, []),
      current_snapshot: Keyword.get(options, :current_snapshot),
      policy_current?: Keyword.get(options, :policy_current?),
      clock: Keyword.get(options, :clock, &DateTime.utc_now/0),
      interval: Keyword.get(options, :interval, @default_interval),
      last_report: nil
    }

    send(self(), :recover)
    {:ok, state}
  end

  @impl true
  def handle_call(:ready?, _from, state), do: {:reply, state.ready?, state}

  def handle_call(:status, _from, state),
    do: {:reply, Map.take(state, [:ready?, :recovering?, :last_report]), state}

  def handle_call(:recover, _from, state) do
    {reply, updated} = perform_recovery(%{state | recovering?: true})
    {:reply, reply, updated}
  end

  @impl true
  def handle_info(:recover, state) do
    {_reply, updated} = perform_recovery(%{state | recovering?: true})
    schedule(updated.interval)
    {:noreply, updated}
  end

  defp perform_recovery(state) do
    with :ok <- validate_state(state),
         {:ok, candidates} <- candidates(state),
         {:ok, results, active_refs} <- reconcile_candidates(candidates, state),
         {:ok, cleaned} <- cleanup_orphans(active_refs, state) do
      report = %{
        scanned_at: state.clock.(),
        candidate_count: length(candidates),
        results: results,
        cleaned_orphan_refs: cleaned
      }

      {{:ok, report}, %{state | ready?: true, recovering?: false, last_report: report}}
    else
      {:error, %AdapterError{} = error} ->
        {{:error, error},
         %{state | ready?: false, recovering?: false, last_report: %{error: error.kind}}}
    end
  rescue
    _error ->
      error = AdapterError.new(:unavailable, :attempt_recovery)

      {{:error, error},
       %{state | ready?: false, recovering?: false, last_report: %{error: error.kind}}}
  catch
    :exit, _reason ->
      error = AdapterError.new(:unavailable, :attempt_recovery)

      {{:error, error},
       %{state | ready?: false, recovering?: false, last_report: %{error: error.kind}}}
  end

  defp validate_state(state) do
    if is_list(state.control_graphs) and length(state.control_graphs) <= 100 and
         is_function(state.query, 2) and is_function(state.load_projection, 1) and
         is_atom(state.runtime_adapter) and not is_nil(state.runtime_adapter) and
         Code.ensure_loaded?(state.runtime_adapter) and is_list(state.runtime_options) and
         is_function(state.sandbox_inspector, 1) and
         is_function(state.transition, 3) and is_function(state.orphan_inventory, 0) and
         is_function(state.cleanup_orphan, 1) and is_function(state.current_snapshot, 1) and
         is_function(state.policy_current?, 1) and is_function(state.clock, 0) and
         is_list(state.available_runtime_versions) and
         length(state.available_runtime_versions) <= 100 and
         Enum.all?(state.available_runtime_versions, &is_binary/1) and
         is_integer(state.interval) and state.interval >= 1_000 do
      :ok
    else
      {:error, AdapterError.new(:invalid_input, :attempt_recovery_config)}
    end
  end

  defp candidates(state) do
    state.control_graphs
    |> Task.async_stream(
      fn graph -> {graph, state.query.(:active_attempts, %{graph: graph})} end,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, {graph, {:ok, result}}}, {:ok, candidates} ->
        case Knowledge.execution_recovery_candidates(result, graph) do
          {:ok, decoded} -> {:cont, {:ok, candidates ++ decoded}}
          {:error, _error} -> {:halt, {:error, AdapterError.new(:corrupt, :recovery_query)}}
        end

      _failure, _acc ->
        {:halt, {:error, AdapterError.new(:unavailable, :recovery_query)}}
    end)
  end

  defp reconcile_candidates(candidates, state) do
    Enum.reduce_while(candidates, {:ok, [], MapSet.new()}, fn candidate, {:ok, results, refs} ->
      with {:ok, projection} <- state.load_projection.(candidate),
           {:ok, request} <- request(projection),
           runtime_status <-
             ExecutionRuntime.status(state.runtime_adapter, request, state.runtime_options),
           sandbox_status <- state.sandbox_inspector.(request),
           {:ok, decision} <-
             Decision.evaluate(
               projection,
               candidate,
               runtime_status,
               sandbox_status,
               state.clock.(),
               available_runtime_versions: state.available_runtime_versions,
               current_snapshot_iri: state.current_snapshot.(projection),
               policy_current?: state.policy_current?.(projection)
             ),
           :ok <- apply_decision(state.transition, decision, candidate, projection) do
        result = %{attempt_iri: candidate.attempt_iri, decision: decision}

        refs =
          if retain_runtime_ref?(decision),
            do: MapSet.put(refs, Request.runtime_key(request)),
            else: refs

        {:cont, {:ok, results ++ [result], refs}}
      else
        {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
        _failure -> {:halt, {:error, AdapterError.new(:unavailable, :attempt_recovery)}}
      end
    end)
  end

  defp cleanup_orphans(active_refs, state) do
    with {:ok, refs} when is_list(refs) and length(refs) <= 1_000 <- state.orphan_inventory.() do
      orphans =
        refs |> Enum.uniq() |> Enum.reject(&MapSet.member?(active_refs, &1)) |> Enum.sort()

      Enum.reduce_while(orphans, {:ok, []}, fn ref, {:ok, cleaned} ->
        case state.cleanup_orphan.(ref) do
          :ok -> {:cont, {:ok, cleaned ++ [ref]}}
          _failure -> {:halt, {:error, AdapterError.new(:unavailable, :orphan_cleanup)}}
        end
      end)
    else
      _failure -> {:error, AdapterError.new(:unavailable, :orphan_inventory)}
    end
  end

  defp request(projection) do
    Request.new(%{
      attempt_iri: projection.attempt_iri,
      lease_iri: projection.lease_iri,
      task_iri: projection.task_iri,
      goal_iri: projection.goal_iri,
      plan_iri: projection.plan_iri,
      repository_iri: projection.repository_iri,
      snapshot_iri: projection.source_snapshot_iri,
      actor_iri: projection.actor_iri,
      agent_iri: projection.agent_iri,
      capability_iri: projection.capability_iri,
      fencing_token: projection.fencing_token,
      context_digest: projection.context_digest,
      runtime_version: projection.runtime_version,
      constraints: projection.constraints
    })
  end

  defp apply_decision(callback, decision, candidate, projection) do
    case callback.(decision, candidate, projection) do
      :ok -> :ok
      {:ok, _receipt} -> :ok
      {:error, %AdapterError{} = error} -> {:error, error}
      _failure -> {:error, AdapterError.new(:unavailable, :recovery_transition)}
    end
  end

  defp retain_runtime_ref?(decision)
       when decision in [
              :observe,
              :resume,
              :retry_later,
              :propagate_cancellation,
              :reject_stale_event
            ],
       do: true

  defp retain_runtime_ref?(_decision), do: false

  defp schedule(interval), do: Process.send_after(self(), :recover, interval)
end
