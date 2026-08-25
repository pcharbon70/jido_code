defmodule JidoCode.Factory.ManagedCoding.Lifecycle do
  @moduledoc "Factory coordinator for fenced, idempotent durable managed-attempt lifecycle facts."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.LifecycleEvent
  alias JidoCode.Factory.ManagedCoding.LifecycleProjection

  @legal %{
    admitted: ~w[preparing cancelled failed]a,
    preparing: ~w[running cancelled failed]a,
    running: ~w[awaiting_actor assembling_candidate cancelled failed]a,
    awaiting_actor: ~w[running cancelled failed]a,
    assembling_candidate: ~w[candidate_ready cancelled failed]a,
    candidate_ready: ~w[verifying cancelled failed]a,
    verifying: ~w[dispositioned failed]a,
    dispositioned: [],
    cancelled: [],
    failed: []
  }

  @spec transition(module(), term(), map()) ::
          {:ok, LifecycleEvent.t()} | {:error, AdapterError.t()}
  def transition(ledger_module, ledger, attributes) when is_atom(ledger_module) do
    case existing(ledger_module, ledger, attributes, :transition) do
      {:ok, event} ->
        same_event(event, attributes, :transition)

      :not_found ->
        with {:ok, current} <- current(ledger_module, ledger, attributes),
             :ok <- legal_transition(current.state, attributes[:state]),
             {:ok, event} <-
               LifecycleEvent.new(
                 event_attributes(attributes, current, :transition)
                 |> Map.put(:previous_state, current.state)
               ),
             {:ok, outcome} <- ledger_module.append(ledger, event, current.sequence),
             true <- outcome in [:committed, :idempotent] do
          {:ok, event}
        else
          {:error, %AdapterError{} = error} -> {:error, error}
          _invalid -> conflict(:managed_coding_lifecycle_transition)
        end

      {:error, %AdapterError{} = error} ->
        {:error, error}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_lifecycle_transition)}
  end

  @spec observe(module(), term(), map()) ::
          {:ok, LifecycleEvent.t()} | {:error, AdapterError.t()}
  def observe(ledger_module, ledger, attributes) when is_atom(ledger_module) do
    kind = attributes[:kind]

    case existing(ledger_module, ledger, attributes, kind) do
      {:ok, event} ->
        same_event(event, attributes, kind)

      :not_found ->
        with true <- kind in LifecycleEvent.observation_kinds(),
             {:ok, current} <- current(ledger_module, ledger, attributes),
             true <- attributes[:state] == current.state,
             {:ok, event} <- LifecycleEvent.new(event_attributes(attributes, current, kind)),
             {:ok, outcome} <- ledger_module.append(ledger, event, current.sequence),
             true <- outcome in [:committed, :idempotent] do
          {:ok, event}
        else
          {:error, %AdapterError{} = error} -> {:error, error}
          _invalid -> conflict(:managed_coding_lifecycle_observation)
        end

      {:error, %AdapterError{} = error} ->
        {:error, error}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_lifecycle_observation)}
  end

  @spec project(module(), term(), String.t(), pos_integer()) ::
          {:ok, LifecycleProjection.t()} | {:error, AdapterError.t()}
  def project(ledger_module, ledger, attempt_iri, fencing_token) do
    with {:ok, events} <- ledger_module.events(ledger, attempt_iri, fencing_token) do
      LifecycleProjection.from_events(events)
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :managed_coding_lifecycle_projection)}
  end

  defp current(module, ledger, attributes) do
    module.current(ledger, attributes[:attempt_iri], attributes[:fencing_token])
  end

  defp existing(module, ledger, attributes, kind) do
    module.find(
      ledger,
      attributes[:attempt_iri],
      attributes[:fencing_token],
      {kind, attributes[:cause_iri]}
    )
  end

  defp same_event(event, attributes, kind) do
    if event.kind == kind and event.state == attributes[:state] and
         event.subject_iri == attributes[:subject_iri] and
         event.actor_iri == attributes[:actor_iri],
       do: {:ok, event},
       else: conflict(:managed_coding_lifecycle_idempotency)
  end

  defp legal_transition(previous, next) do
    if next in Map.get(@legal, previous, []),
      do: :ok,
      else: {:error, AdapterError.new(:conflict, :managed_coding_lifecycle_transition)}
  end

  defp event_attributes(attributes, current, kind) do
    attributes
    |> Map.put(:kind, kind)
    |> Map.put(:sequence, current.sequence + 1)
    |> Map.put_new(:origin_sequence, current.sequence + 1)
    |> Map.put_new(:late_observation, false)
  end

  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
end
