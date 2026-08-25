defmodule JidoCode.TestSupport.FakeManagedCodingLifecycleLedger do
  @moduledoc false

  @behaviour JidoCode.Factory.Ports.ManagedCodingLifecycleLedger

  alias JidoCode.Factory.AdapterError

  @impl true
  def current(agent, attempt_iri, fencing_token) do
    state = Agent.get(agent, & &1)

    case state do
      %{attempt_iri: ^attempt_iri, fencing_token: ^fencing_token, events: events} ->
        current = events |> Enum.filter(&(&1.kind == :transition)) |> List.last()
        {:ok, %{state: current.state, sequence: List.last(events).sequence}}

      _stale ->
        {:error, AdapterError.new(:unauthorized, :managed_coding_lifecycle_current)}
    end
  end

  @impl true
  def find(agent, attempt_iri, fencing_token, {kind, cause_iri}) do
    state = Agent.get(agent, & &1)

    cond do
      state.attempt_iri != attempt_iri or state.fencing_token != fencing_token ->
        {:error, AdapterError.new(:unauthorized, :managed_coding_lifecycle_find)}

      event = Enum.find(state.events, &(&1.kind == kind and &1.cause_iri == cause_iri)) ->
        {:ok, event}

      true ->
        :not_found
    end
  end

  @impl true
  def append(agent, event, expected_sequence) do
    Agent.get_and_update(agent, fn state ->
      cond do
        Enum.any?(state.events, &(&1.event_iri == event.event_iri)) ->
          {{:ok, :idempotent}, state}

        List.last(state.events).sequence != expected_sequence ->
          {{:error, AdapterError.new(:conflict, :managed_coding_lifecycle_append)}, state}

        true ->
          send(state.owner, {:lifecycle_append, event})
          {{:ok, :committed}, %{state | events: state.events ++ [event]}}
      end
    end)
  end

  @impl true
  def events(agent, attempt_iri, fencing_token) do
    state = Agent.get(agent, & &1)

    if state.attempt_iri == attempt_iri and state.fencing_token == fencing_token,
      do: {:ok, state.events},
      else: {:error, AdapterError.new(:unauthorized, :managed_coding_lifecycle_events)}
  end
end
