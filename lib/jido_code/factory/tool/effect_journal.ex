defmodule JidoCode.Factory.Tool.EffectJournal do
  @moduledoc "Reference effect-sink journal with atomic claim, replay, and reconciliation."

  use GenServer

  @behaviour JidoCode.Factory.Ports.EffectSink

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.EffectIdentity
  alias JidoCode.Factory.Tool.Result

  @external_id_sinks ~w[git_write provider_write artifact_publication]a

  @type server :: GenServer.server()

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options \\ []) when is_list(options) do
    GenServer.start_link(__MODULE__, %{}, Keyword.take(options, [:name]))
  end

  @impl true
  def claim(server, sink, %EffectIdentity{} = identity),
    do: GenServer.call(server, {:claim, sink, identity})

  @impl true
  def complete(server, sink, %EffectIdentity{} = identity, %Result{} = result),
    do: GenServer.call(server, {:complete, sink, identity, result})

  @impl true
  def ambiguous(server, sink, %EffectIdentity{} = identity),
    do: GenServer.call(server, {:ambiguous, sink, identity})

  @spec reconcile(server(), atom(), EffectIdentity.t(), :not_applied | {:applied, Result.t()}) ::
          {:ok, :retry | :committed | :idempotent} | {:error, AdapterError.t()}
  def reconcile(server, sink, %EffectIdentity{} = identity, resolution),
    do: GenServer.call(server, {:reconcile, sink, identity, resolution})

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_call({:claim, sink, identity}, _from, state) do
    key = key(sink, identity)

    case Map.get(state, key) do
      nil -> {:reply, {:ok, :dispatch}, Map.put(state, key, {:claimed, identity})}
      {:completed, _identity, result} -> {:reply, {:ok, {:replay, result}}, state}
      {:claimed, _identity} -> {:reply, conflict(:effect_already_claimed), state}
      {:ambiguous, _identity} -> {:reply, conflict(:effect_reconciliation_required), state}
    end
  end

  def handle_call({:complete, sink, identity, result}, _from, state) do
    key = key(sink, identity)

    case {external_id?(sink, result), Map.get(state, key)} do
      {false, _entry} ->
        {:reply, {:error, AdapterError.new(:corrupt, :stable_external_effect_id)}, state}

      {true, {:claimed, ^identity}} ->
        {:reply, {:ok, :committed}, Map.put(state, key, {:completed, identity, result})}

      {true, {:completed, ^identity, ^result}} ->
        {:reply, {:ok, :idempotent}, state}

      _other ->
        {:reply, conflict(:effect_completion), state}
    end
  end

  def handle_call({:ambiguous, sink, identity}, _from, state) do
    key = key(sink, identity)

    case Map.get(state, key) do
      {:claimed, ^identity} ->
        {:reply, {:ok, :committed}, Map.put(state, key, {:ambiguous, identity})}

      {:ambiguous, ^identity} ->
        {:reply, {:ok, :idempotent}, state}

      _other ->
        {:reply, conflict(:effect_ambiguity), state}
    end
  end

  def handle_call({:reconcile, sink, identity, :not_applied}, _from, state) do
    key = key(sink, identity)

    case Map.get(state, key) do
      {:ambiguous, ^identity} -> {:reply, {:ok, :retry}, Map.delete(state, key)}
      _other -> {:reply, conflict(:effect_reconciliation), state}
    end
  end

  def handle_call({:reconcile, sink, identity, {:applied, %Result{} = result}}, _from, state) do
    key = key(sink, identity)

    case {external_id?(sink, result), Map.get(state, key)} do
      {false, _entry} ->
        {:reply, {:error, AdapterError.new(:corrupt, :stable_external_effect_id)}, state}

      {true, {:ambiguous, ^identity}} ->
        {:reply, {:ok, :committed}, Map.put(state, key, {:completed, identity, result})}

      {true, {:completed, ^identity, ^result}} ->
        {:reply, {:ok, :idempotent}, state}

      _other ->
        {:reply, conflict(:effect_reconciliation), state}
    end
  end

  def handle_call({:reconcile, _sink, _identity, _resolution}, _from, state),
    do: {:reply, {:error, AdapterError.new(:invalid_input, :effect_reconciliation)}, state}

  defp key(sink, identity), do: {sink, identity.value}

  defp external_id?(sink, result) when sink in @external_id_sinks,
    do: is_binary(result.external_effect_id)

  defp external_id?(_sink, _result), do: true
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
end
