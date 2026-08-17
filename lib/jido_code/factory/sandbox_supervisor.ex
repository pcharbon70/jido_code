defmodule JidoCode.Factory.SandboxSupervisor do
  @moduledoc "Supervises production-tier sandbox lifecycle and post-capture destruction."

  use GenServer

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Sandbox
  alias JidoCode.Factory.Sandbox.ArtifactCapture
  alias JidoCode.Factory.Sandbox.Event
  alias JidoCode.Factory.Sandbox.Instance
  alias JidoCode.Factory.Sandbox.IsolationProfile
  alias JidoCode.Factory.Sandbox.Request
  alias JidoCode.Factory.Sandbox.ResourceEnforcer
  alias JidoCode.Factory.Sandbox.Session
  alias JidoCode.Factory.Sandbox.Tier
  alias JidoCode.Factory.Sandbox.Workload

  @operations ~w[materialize execute inspect cancel]a

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(options) when is_list(options) do
    GenServer.start_link(__MODULE__, options, Keyword.take(options, [:name]))
  end

  @spec provision(GenServer.server(), atom(), Request.t(), keyword()) ::
          {:ok, Session.t(), Event.t()} | {:error, AdapterError.t()}
  def provision(server, workload, %Request{} = request, options \\ []) do
    GenServer.call(server, {:provision, workload, request, options}, :infinity)
  end

  @spec materialize(GenServer.server(), Request.t(), map(), keyword()) ::
          {:ok, Event.t()} | {:error, AdapterError.t()}
  def materialize(server, %Request{} = request, snapshot, options \\ []),
    do: dispatch(server, :materialize, request, snapshot, options)

  @spec execute(GenServer.server(), Request.t(), map(), keyword()) ::
          {:ok, Event.t()} | {:error, AdapterError.t()}
  def execute(server, %Request{} = request, command, options \\ []),
    do: dispatch(server, :execute, request, command, options)

  @spec inspect(GenServer.server(), Request.t(), keyword()) ::
          {:ok, Event.t()} | {:error, AdapterError.t()}
  def inspect(server, %Request{} = request, options \\ []),
    do: dispatch(server, :inspect, request, nil, options)

  @spec cancel(GenServer.server(), Request.t(), keyword()) ::
          {:ok, Event.t()} | {:error, AdapterError.t()}
  def cancel(server, %Request{} = request, options \\ []),
    do: dispatch(server, :cancel, request, nil, options)

  @spec finish(GenServer.server(), Request.t(), [map()], map(), keyword()) ::
          {:ok, map()} | {:error, AdapterError.t()}
  def finish(server, %Request{} = request, candidates, artifact_context, options \\ [])
      when is_list(candidates) and is_map(artifact_context) do
    GenServer.call(
      server,
      {:finish, request, candidates, artifact_context, options},
      :infinity
    )
  end

  @impl true
  def init(options) do
    adapters = Keyword.get(options, :adapters)

    case validate_adapters(adapters) do
      {:ok, validated} -> {:ok, %{adapters: validated, sessions: %{}}}
      {:error, %AdapterError{} = error} -> {:stop, error}
    end
  end

  @impl true
  def handle_call({:provision, workload, request, options}, _from, state) do
    attempt = request.execution.attempt_iri

    with nil <- Map.get(state.sessions, attempt),
         {:ok, tier} <- Tier.select(workload),
         {:ok, registration} <- Map.fetch(state.adapters, tier),
         true <- registration.profile |> IsolationProfile.admits?(request.limits),
         {:ok, %Event{} = event} <-
           Sandbox.provision(
             registration.module,
             registration.adapter,
             request,
             Keyword.put(options, :isolation_profile, registration.profile)
           ),
         {:ok, instance} <-
           Instance.new(request, registration.profile, event.provider_ref, event.occurred_at),
         {:ok, reporting_event} <-
           Event.new(%{
             attempt_iri: event.attempt_iri,
             operation: event.operation,
             outcome: event.outcome,
             occurred_at: event.occurred_at,
             provider_ref: event.provider_ref,
             details: Map.merge(event.details, Instance.event_details(instance))
           }) do
      session = %Session{
        attempt_iri: attempt,
        workload: workload,
        tier: tier,
        profile: registration.profile,
        instance: instance,
        adapter_module: registration.module,
        adapter: registration.adapter
      }

      updated = put_in(state, [:sessions, attempt], session)
      {:reply, {:ok, session, reporting_event}, updated}
    else
      %Session{} -> {:reply, conflict(:sandbox_already_provisioned), state}
      :error -> {:reply, unavailable(:sandbox_tier_adapter), state}
      false -> {:reply, unauthorized(:sandbox_tier_limits), state}
      {:error, %AdapterError{} = error} -> {:reply, {:error, error}, state}
      _invalid -> {:reply, invalid(:sandbox_provision), state}
    end
  end

  def handle_call({:dispatch, operation, request, argument, options}, _from, state) do
    case Map.fetch(state.sessions, request.execution.attempt_iri) do
      {:ok, session} ->
        {result, next_state} =
          dispatch_session(operation, session, request, argument, options, state)

        {:reply, result, next_state}

      :error ->
        {:reply, conflict(:sandbox_session), state}
    end
  end

  def handle_call({:finish, request, candidates, artifact_context, options}, _from, state) do
    attempt = request.execution.attempt_iri

    case Map.fetch(state.sessions, attempt) do
      {:ok, session} ->
        result = finish_session(session, request, candidates, artifact_context, options)
        {:reply, result, update_in(state, [:sessions], &Map.delete(&1, attempt))}

      :error ->
        {:reply, conflict(:sandbox_session), state}
    end
  end

  defp dispatch(server, operation, request, argument, options)
       when operation in @operations and is_list(options) do
    GenServer.call(server, {:dispatch, operation, request, argument, options}, :infinity)
  end

  defp finish_session(session, request, candidates, artifact_context, options) do
    collect =
      with {:ok, %Event{} = event} <-
             Sandbox.collect(
               session.adapter_module,
               session.adapter,
               request,
               Keyword.put(options, :isolation_profile, session.profile)
             ),
           :ok <- ResourceEnforcer.validate_collection(event, request.limits) do
        {:ok, event}
      end

    artifacts =
      with {:ok, %Event{}} <- collect,
           :ok <- ResourceEnforcer.validate_capture(candidates, request.limits) do
        capture_all(candidates, artifact_context, options)
      end

    destroy =
      Sandbox.destroy(
        session.adapter_module,
        session.adapter,
        request,
        Keyword.put(options, :isolation_profile, session.profile)
      )

    case {collect, artifacts, destroy} do
      {{:ok, %Event{} = collected}, {:ok, captured}, {:ok, %Event{} = destroyed}} ->
        {:ok,
         %{
           instance: Instance.observation(session.instance),
           collected: collected,
           artifacts: captured,
           destroyed: destroyed
         }}

      {_collect, _artifacts, {:error, %AdapterError{} = error}} ->
        {:error, error}

      {{:error, %AdapterError{} = error}, _artifacts, _destroy} ->
        {:error, error}

      {_collect, {:error, %AdapterError{} = error}, _destroy} ->
        {:error, error}

      _invalid ->
        invalid(:sandbox_finish)
    end
  end

  defp capture_all(candidates, context, options) do
    Enum.reduce_while(candidates, {:ok, []}, fn candidate, {:ok, captured} ->
      case ArtifactCapture.capture(candidate, context, options) do
        {:ok, artifact} -> {:cont, {:ok, [artifact | captured]}}
        {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
      end
    end)
    |> then(fn
      {:ok, captured} -> {:ok, Enum.reverse(captured)}
      {:error, %AdapterError{} = error} -> {:error, error}
    end)
  end

  defp dispatch_session(:execute, session, request, command, options, state) do
    result =
      with :ok <-
             Workload.authorize_command(session.workload, command, request.command_allowlist),
           {:ok, %Event{} = event} <- invoke(:execute, session, request, command, options),
           :ok <- ResourceEnforcer.validate_execution(event, request.limits) do
        {:ok, event}
      end

    case result do
      {:ok, %Event{}} ->
        {result, state}

      {:error, %AdapterError{} = error} ->
        terminated = terminate_session(session, request, options, error)
        {terminated, drop_session(state, request)}

      _invalid ->
        error = AdapterError.new(:corrupt, :sandbox_execution_boundary)
        terminated = terminate_session(session, request, options, error)
        {terminated, drop_session(state, request)}
    end
  end

  defp dispatch_session(operation, session, request, argument, options, state) do
    {invoke(operation, session, request, argument, options), state}
  end

  defp terminate_session(session, request, options, original_error) do
    sandbox_options = Keyword.put(options, :isolation_profile, session.profile)

    _cancel =
      Sandbox.cancel(session.adapter_module, session.adapter, request, sandbox_options)

    case Sandbox.destroy(session.adapter_module, session.adapter, request, sandbox_options) do
      {:ok, %Event{}} -> {:error, original_error}
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> unavailable(:sandbox_emergency_destroy)
    end
  end

  defp drop_session(state, request) do
    update_in(state, [:sessions], &Map.delete(&1, request.execution.attempt_iri))
  end

  defp invoke(:materialize, session, request, argument, options) do
    Sandbox.materialize(
      session.adapter_module,
      session.adapter,
      request,
      argument,
      Keyword.put(options, :isolation_profile, session.profile)
    )
  end

  defp invoke(:execute, session, request, argument, options) do
    Sandbox.execute(
      session.adapter_module,
      session.adapter,
      request,
      argument,
      Keyword.put(options, :isolation_profile, session.profile)
    )
  end

  defp invoke(operation, session, request, nil, options) when operation in [:inspect, :cancel] do
    apply(Sandbox, operation, [
      session.adapter_module,
      session.adapter,
      request,
      Keyword.put(options, :isolation_profile, session.profile)
    ])
  end

  defp validate_adapters(adapters) when is_map(adapters) do
    if MapSet.new(Map.keys(adapters)) == MapSet.new(Tier.all()) do
      Enum.reduce_while(adapters, {:ok, %{}}, fn {tier, registration}, {:ok, valid} ->
        case validate_adapter(tier, registration) do
          {:ok, value} -> {:cont, {:ok, Map.put(valid, tier, value)}}
          {:error, %AdapterError{} = error} -> {:halt, {:error, error}}
        end
      end)
    else
      invalid(:sandbox_adapter_registry)
    end
  end

  defp validate_adapters(_adapters), do: invalid(:sandbox_adapter_registry)

  defp validate_adapter(tier, {module, adapter}) when is_atom(module) do
    with true <- production_adapter?(module),
         {:ok, %IsolationProfile{} = attested} <- module.isolation_profile(adapter),
         {:ok, expected} <- Tier.profile(tier),
         true <- IsolationProfile.digest(attested) == IsolationProfile.digest(expected) do
      {:ok, %{module: module, adapter: adapter, profile: attested}}
    else
      {:error, %AdapterError{} = error} -> {:error, error}
      _invalid -> unauthorized(:sandbox_adapter_attestation)
    end
  rescue
    _error -> unavailable(:sandbox_adapter_attestation)
  catch
    :exit, _reason -> unavailable(:sandbox_adapter_attestation)
  end

  defp validate_adapter(_tier, _registration), do: invalid(:sandbox_adapter_registry)

  defp production_adapter?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :isolation_profile, 1) and
      Enum.all?(
        [
          {:provision, 3},
          {:materialize, 4},
          {:execute, 4},
          {:inspect, 3},
          {:cancel, 3},
          {:collect, 3},
          {:destroy, 3}
        ],
        fn {function, arity} -> function_exported?(module, function, arity) end
      )
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
  defp unavailable(operation), do: {:error, AdapterError.new(:unavailable, operation)}
  defp conflict(operation), do: {:error, AdapterError.new(:conflict, operation)}
end
