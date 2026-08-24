defmodule JidoCode.Runtime.ManagedCoding.SingleAgentLoop do
  @moduledoc "Host-controlled coordinator for one disposable Jido coding agent."

  use GenServer

  alias Jido.Signal
  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.LoopBudget
  alias JidoCode.Runtime.ManagedCoding.Dispatcher
  alias JidoCode.Runtime.ManagedCoding.LoopControl

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) do
    server_options = if options[:name], do: [name: options[:name]], else: []
    GenServer.start_link(__MODULE__, options, server_options)
  end

  @spec attach_dispatcher(GenServer.server(), GenServer.server()) :: :ok
  def attach_dispatcher(server, dispatcher), do: GenServer.call(server, {:attach, dispatcher})

  @spec begin(GenServer.server()) :: :ok | {:error, AdapterError.t()}
  def begin(server), do: GenServer.call(server, :begin)

  @spec deliver(GenServer.server(), pid(), Signal.t()) :: :ok
  def deliver(server, target, %Signal{} = signal) do
    send(server, {:directive_result, target, signal})
    :ok
  end

  @spec status(GenServer.server()) :: map()
  def status(server), do: GenServer.call(server, :status)

  @impl true
  def init(options) do
    with agent when is_pid(agent) <- options[:agent_server],
         %LoopBudget{} = budget <- options[:budget],
         directive_factory when is_function(directive_factory, 3) <- options[:directive_factory],
         observation_provider when is_function(observation_provider, 2) <-
           Keyword.get(options, :observation_provider, fn _effect, _signal -> {%{}, []} end) do
      {:ok,
       %{
         agent_server: agent,
         budget: budget,
         directive_factory: directive_factory,
         observation_provider: observation_provider,
         dispatcher: nil,
         active_effect: nil,
         status: :idle,
         last_error: nil
       }}
    else
      _invalid -> {:stop, AdapterError.new(:invalid_input, :managed_coding_single_agent_loop)}
    end
  end

  @impl true
  def handle_call({:attach, dispatcher}, _from, %{dispatcher: nil} = state) do
    {:reply, :ok, %{state | dispatcher: dispatcher}}
  end

  def handle_call(:begin, _from, %{dispatcher: dispatcher, status: :idle} = state)
      when not is_nil(dispatcher) do
    with {:ok, agent} <- agent_state(state.agent_server),
         {:ok, signal} <-
           Signal.new("jido_code.managed_coding.begin", correlation(agent, agent.sequence + 1)),
         {:ok, _updated} <- Jido.AgentServer.call(state.agent_server, signal) do
      send(self(), :continue)
      {:reply, :ok, %{state | status: :running}}
    else
      _invalid ->
        error = AdapterError.new(:unavailable, :managed_coding_single_agent_begin)
        {:reply, {:error, error}, fail(state, error)}
    end
  end

  def handle_call(:begin, _from, state) do
    {:reply, {:error, AdapterError.new(:conflict, :managed_coding_single_agent_begin)}, state}
  end

  def handle_call(:status, _from, state) do
    agent =
      case agent_state(state.agent_server) do
        {:ok, value} -> value
        _error -> nil
      end

    {:reply,
     %{
       status: state.status,
       active_effect: state.active_effect,
       budget: LoopBudget.snapshot(state.budget),
       agent: agent,
       last_error: state.last_error
     }, state}
  end

  @impl true
  def handle_info(:continue, %{status: :running, active_effect: nil} = state) do
    with {:ok, agent} <- agent_state(state.agent_server) do
      case LoopControl.next(agent, state.budget, %{}) do
        {:dispatch, effect, payload, budget} ->
          dispatch(state, agent, effect, payload, budget)

        {:stop, :terminal, budget} ->
          terminal_status =
            if agent.phase in [:candidate_ready, :completed], do: :completed, else: agent.phase

          {:noreply, %{state | status: terminal_status, budget: budget}}

        {:stop, reason, budget} when reason != :awaiting_result ->
          {:noreply, %{state | status: :stopped, budget: budget, last_error: reason}}

        {:stop, :awaiting_result, budget} ->
          {:noreply, %{state | budget: budget}}

        {:error, error} ->
          {:noreply, fail(state, error)}
      end
    else
      _invalid ->
        {:noreply, fail(state, AdapterError.new(:unavailable, :managed_coding_agent_state))}
    end
  end

  def handle_info({:directive_result, target, %Signal{} = signal}, state) do
    cond do
      target != state.agent_server or is_nil(state.active_effect) ->
        {:noreply, state}

      true ->
        case Jido.AgentServer.call(state.agent_server, signal) do
          {:ok, _agent} ->
            {observations, options} =
              state.observation_provider.(state.active_effect, signal)

            case LoopBudget.after_effect(state.budget, observations, options) do
              {:ok, budget} ->
                send(self(), :continue)
                {:noreply, %{state | active_effect: nil, budget: budget}}

              {:error, error} ->
                {:noreply, fail(state, error)}
            end

          _invalid ->
            {:noreply, fail(state, AdapterError.new(:corrupt, :managed_coding_directive_result))}
        end
    end
  rescue
    _error ->
      {:noreply, fail(state, AdapterError.new(:unavailable, :managed_coding_directive_result))}
  end

  defp dispatch(state, agent, effect, payload, budget) do
    case state.directive_factory.(effect, payload, agent) do
      {:ok, directive} ->
        case Dispatcher.dispatch(state.dispatcher, directive, state.agent_server) do
          :ok -> {:noreply, %{state | active_effect: effect, budget: budget}}
          {:error, error} -> {:noreply, fail(state, error)}
        end

      {:error, %AdapterError{} = error} ->
        {:noreply, fail(state, error)}

      _invalid ->
        {:noreply, fail(state, AdapterError.new(:corrupt, :managed_coding_directive_factory))}
    end
  rescue
    _error ->
      {:noreply, fail(state, AdapterError.new(:unavailable, :managed_coding_directive_factory))}
  end

  defp agent_state(server) do
    with {:ok, server_state} <- Jido.AgentServer.state(server),
         agent when is_map(agent) <- server_state.agent.state do
      {:ok, agent}
    end
  end

  defp correlation(agent, sequence) do
    %{
      attempt_iri: agent.attempt_iri,
      fencing_token: agent.fencing_token,
      sequence: sequence
    }
  end

  defp fail(state, error), do: %{state | status: :failed, active_effect: nil, last_error: error}
end
