defmodule JidoCode.Factory.RepositoryWiki.Scheduler do
  @moduledoc "Bounded disposable scheduler rebuilt from authoritative trigger and wiki graph state."

  use GenServer

  alias JidoCode.Knowledge

  @skip_actions [:no_change, :stale_only, :unsupported]

  def start_link(options \\ []) do
    GenServer.start_link(__MODULE__, options, name: Keyword.get(options, :name, __MODULE__))
  end

  def enqueue(server \\ __MODULE__, trigger), do: GenServer.call(server, {:enqueue, trigger})
  def next(server \\ __MODULE__, current), do: GenServer.call(server, {:next, current})

  def complete(server \\ __MODULE__, tenant_iri, repository_iri, result),
    do: GenServer.call(server, {:complete, tenant_iri, repository_iri, result})

  def hydrate(server \\ __MODULE__, triggers), do: GenServer.call(server, {:hydrate, triggers})
  def status(server \\ __MODULE__), do: GenServer.call(server, :status)

  @impl true
  def init(options) do
    {:ok,
     %{
       maximum_pending: Keyword.get(options, :maximum_pending, 64),
       maximum_active: Keyword.get(options, :maximum_active, 8),
       maximum_per_tenant: Keyword.get(options, :maximum_per_tenant, 4),
       revalidator: Keyword.get(options, :revalidator, &default_revalidator/2),
       pending: [],
       active: %{},
       terminal: [],
       sequence: 0
     }}
  end

  @impl true
  def handle_call({:enqueue, trigger}, _from, state) do
    case enqueue_trigger(state, trigger) do
      {:ok, outcome, next_state} -> {:reply, {:ok, outcome}, next_state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:hydrate, triggers}, _from, state) when is_list(triggers) do
    if length(triggers) <= state.maximum_pending do
      next = Enum.reduce(triggers, %{state | pending: []}, &hydrate_trigger/2)
      {:reply, {:ok, length(next.pending)}, next}
    else
      {:reply, {:error, :backpressure}, state}
    end
  end

  def handle_call({:next, current}, _from, state) when is_map(current) do
    if map_size(state.active) >= state.maximum_active do
      {:reply, {:error, :fleet_capacity}, state}
    else
      dispatch_next(state, current)
    end
  end

  def handle_call({:complete, tenant_iri, repository_iri, result}, _from, state) do
    key = {tenant_iri, repository_iri}

    case Map.pop(state.active, key) do
      {nil, _active} ->
        {:reply, {:error, :not_active}, state}

      {trigger, active} ->
        terminal = terminal_evidence(trigger, :completed, result)

        {:reply, :ok,
         %{state | active: active, terminal: bounded_prepend(terminal, state.terminal)}}
    end
  end

  def handle_call(:status, _from, state) do
    {:reply,
     %{
       pending_count: length(state.pending),
       active_count: map_size(state.active),
       terminal_count: length(state.terminal),
       repositories: state.active |> Map.keys() |> Enum.sort()
     }, state}
  end

  defp enqueue_trigger(state, trigger) when is_map(trigger) do
    cond do
      Enum.any?(state.pending, &(&1.idempotency_key == trigger[:idempotency_key])) ->
        {:ok, :duplicate, state}

      active_for?(state, trigger) ->
        {:error, :repository_active}

      compatible = Enum.find(state.pending, &compatible?(&1, trigger)) ->
        coalesced = coalesce(compatible, trigger)
        pending = Enum.map(state.pending, &if(&1.iri == compatible.iri, do: coalesced, else: &1))
        {:ok, :coalesced, %{state | pending: pending}}

      length(state.pending) >= state.maximum_pending ->
        {:error, :backpressure}

      true ->
        queued = Map.put(trigger, :queue_sequence, state.sequence + 1)
        {:ok, :queued, %{state | pending: [queued | state.pending], sequence: state.sequence + 1}}
    end
  rescue
    _error -> {:error, :invalid_trigger}
  end

  defp enqueue_trigger(_state, _trigger), do: {:error, :invalid_trigger}

  defp dispatch_next(state, current) do
    eligible =
      state.pending
      |> Enum.reject(&active_for?(state, &1))
      |> Enum.reject(&tenant_full?(state, &1.tenant_iri))
      |> Enum.sort_by(
        &{-Knowledge.repository_wiki_trigger_priority(&1.priority), &1.queue_sequence,
         &1.repository_iri}
      )

    case eligible do
      [] ->
        {:reply, :empty, state}

      [trigger | _rest] ->
        pending = Enum.reject(state.pending, &(&1.iri == trigger.iri))

        case state.revalidator.(trigger, current) do
          {:ok, %{action: action} = classification} when action in @skip_actions ->
            evidence = terminal_evidence(trigger, :skipped, classification)

            next = %{
              state
              | pending: pending,
                terminal: bounded_prepend(evidence, state.terminal)
            }

            {:reply, {:skipped, evidence}, next}

          {:ok, %{action: action} = classification}
          when action in [:metadata_refresh, :targeted_rebuild, :full_rebuild] ->
            admitted = Map.put(trigger, :admitted_classification, classification)
            key = {trigger.tenant_iri, trigger.repository_iri}
            next = %{state | pending: pending, active: Map.put(state.active, key, admitted)}
            {:reply, {:ok, admitted}, next}

          {:error, reason} ->
            evidence = terminal_evidence(trigger, :revalidation_failed, reason)

            next = %{
              state
              | pending: pending,
                terminal: bounded_prepend(evidence, state.terminal)
            }

            {:reply, {:skipped, evidence}, next}

          _invalid ->
            evidence = terminal_evidence(trigger, :revalidation_failed, :invalid)

            next = %{
              state
              | pending: pending,
                terminal: bounded_prepend(evidence, state.terminal)
            }

            {:reply, {:skipped, evidence}, next}
        end
    end
  end

  defp compatible?(left, right) do
    left.repository_iri == right.repository_iri and left.tenant_iri == right.tenant_iri and
      left.profile_digest == right.profile_digest and
      left.policy_revision == right.policy_revision
  end

  defp coalesce(left, right) do
    latest =
      if DateTime.compare(left.recorded_at, right.recorded_at) == :gt, do: left, else: right

    causes = (left.causal_iris ++ right.causal_iris) |> Enum.uniq() |> Enum.sort()

    latest
    |> Map.put(:causal_iris, causes)
    |> Map.put(:coalesced_trigger_count, Map.get(left, :coalesced_trigger_count, 0) + 1)
    |> Map.put(
      :queue_sequence,
      min(left.queue_sequence, Map.get(right, :queue_sequence, left.queue_sequence))
    )
  end

  defp active_for?(state, trigger),
    do: Map.has_key?(state.active, {trigger.tenant_iri, trigger.repository_iri})

  defp tenant_full?(state, tenant_iri) do
    Enum.count(state.active, fn {{tenant, _repository}, _trigger} -> tenant == tenant_iri end) >=
      state.maximum_per_tenant
  end

  defp terminal_evidence(trigger, state, detail) do
    value = %{
      trigger_iri: trigger.iri,
      repository_iri: trigger.repository_iri,
      tenant_iri: trigger.tenant_iri,
      source_fence: trigger.source_fence,
      state: state,
      detail: detail,
      causal_iris: trigger.causal_iris
    }

    Map.put(value, :digest, Knowledge.repository_wiki_digest(value))
  end

  defp hydrate_trigger(trigger, state) do
    case enqueue_trigger(state, trigger) do
      {:ok, _outcome, next} -> next
      {:error, _reason} -> state
    end
  end

  defp bounded_prepend(item, values), do: [item | values] |> Enum.take(256)
  defp default_revalidator(_trigger, _current), do: {:error, :revalidator_unavailable}
end
