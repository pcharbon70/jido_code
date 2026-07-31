defmodule JidoCode.Knowledge.StoreServer do
  @moduledoc """
  Exclusive owner and execution boundary for the embedded `TripleStore`.

  Raw handles never leave this process. Internal callers are authorized by
  supervised process identity and can invoke only the fixed operation catalog.
  """

  use GenServer

  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.AtomicCommit
  alias JidoCode.Knowledge.CommitLog
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Identity
  alias JidoCode.Knowledge.Metadata
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.Telemetry
  alias TripleStore.Backend.RocksDB.ErlangAdapter
  alias TripleStore.QuadOperations

  @default_callers %{
    read: [JidoCode.Knowledge.QueryRunner, JidoCode.Knowledge.Integrity],
    write: [JidoCode.Knowledge.Writer],
    maintenance: [JidoCode.Knowledge.Maintenance]
  }

  @operation_roles %{
    metadata: :read,
    statistics: :read,
    graph_counts: :read,
    atomic_update: :write,
    receipt: :write,
    checkpoint: :maintenance,
    backup: :maintenance,
    export: :maintenance,
    integrity: :maintenance,
    restore: :maintenance,
    enter_maintenance: :maintenance,
    leave_maintenance: :maintenance
  }

  defstruct [
    :config,
    :store,
    :metadata,
    :last_error,
    :readiness,
    :native,
    :authorized_callers,
    monitors: %{}
  ]

  @type server :: GenServer.server()

  def start_link(options \\ []) do
    case Keyword.get(options, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, options)
      name -> GenServer.start_link(__MODULE__, options, name: name)
    end
  end

  @spec summary(server()) :: map()
  def summary(server \\ __MODULE__), do: GenServer.call(server, :summary)

  @doc false
  def request(server \\ __MODULE__, request, timeout \\ 5_000) do
    GenServer.call(server, {:request, request}, timeout)
  end

  @impl true
  def init(options) do
    readiness = Keyword.get(options, :readiness, Readiness)
    :ok = Readiness.monitor_store(readiness, self())

    state = %__MODULE__{
      readiness: readiness,
      native: Keyword.get(options, :native, JidoCode.Knowledge.Native),
      authorized_callers: Keyword.get(options, :authorized_callers, @default_callers)
    }

    {:ok, {state, options}, {:continue, :open}}
  end

  @impl true
  def handle_continue(:open, {state, options}) do
    state = initialize(state, options)
    {:noreply, state}
  end

  @impl true
  def handle_call(:summary, _from, state), do: {:reply, public_summary(state), state}

  def handle_call({:request, request}, {caller, _tag}, state) do
    operation = operation(request)

    with {:ok, role} <- role_for(operation),
         :ok <- authorize(state, role, caller),
         :ok <- gate_request(state, operation),
         {:ok, reply, next_state} <-
           Telemetry.span(operation_class(role), fn -> dispatch(request, state) end) do
      {:reply, {:ok, reply}, next_state}
    else
      {:error, %Error{} = error} -> {:reply, {:error, error}, state}
      {:error, %Error{} = error, details} -> {:reply, {:error, error, details}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, reference, :process, _pid, _reason}, state) do
    if Map.has_key?(state.monitors, reference) do
      error = Error.new(:unavailable, :store_backend_down)
      safe_close(state.store)
      Readiness.transition(state.readiness, {:fail, error})

      {:noreply, %{state | store: nil, metadata: nil, last_error: error, monitors: %{}}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    safe_close(state.store)
    :ok
  end

  defp initialize(state, options) do
    Readiness.transition(state.readiness, :opening)

    case load_config(options) do
      {:ok, config} ->
        initialize_config(%{state | config: config}, config)

      {:error, %Error{} = error} ->
        fail_startup(state, error)

      {:error, reason} ->
        fail_startup(state, BackendFailure.translate(reason, :open_store))
    end
  end

  defp initialize_config(state, config) do
    with :ok <- ensure_enabled(config),
         :ok <- state.native.verify(),
         :ok <- Config.prepare_directories(config),
         {:ok, store} <- bounded_open(config),
         {:ok, metadata} <- verify_store(state.readiness, store, config) do
      monitors = monitor_store_processes(store)
      %{state | store: store, metadata: metadata, monitors: monitors}
    else
      {:error, %Error{} = error} -> fail_startup(state, error)
      {:error, reason} -> fail_startup(state, BackendFailure.translate(reason, :open_store))
    end
  end

  defp load_config(options) do
    case Keyword.get(options, :config) do
      %Config{} = config -> {:ok, config}
      nil -> Config.load(Keyword.get(options, :config_overrides, []))
      _invalid -> {:error, Error.new(:invalid_input, :load_store_config)}
    end
  end

  defp ensure_enabled(%Config{enabled?: true}), do: :ok
  defp ensure_enabled(%Config{}), do: {:error, Error.new(:unavailable, :open_store)}

  defp bounded_open(config) do
    parent = self()
    token = make_ref()

    {opener, monitor} =
      spawn_monitor(fn ->
        result =
          Telemetry.span(:open, fn ->
            TripleStore.open(Config.active_store_path(config), schema: :quad)
          end)

        send(parent, {:store_open_result, token, self(), result})

        receive do
          {:adopt_store, ^token} -> :ok
          {:cancel_store_open, ^token} -> close_open_result(result)
        after
          5_000 -> close_open_result(result)
        end
      end)

    receive do
      {:store_open_result, ^token, ^opener, result} ->
        send(opener, {:adopt_store, token})
        await_opener(monitor, opener)
        normalize_open_result(result)

      {:DOWN, ^monitor, :process, ^opener, reason} ->
        {:error, BackendFailure.translate(reason, :open_store)}
    after
      config.open_timeout ->
        cancel_opener(opener, monitor, token)
        {:error, Error.new(:timeout, :open_store)}
    end
  end

  defp verify_store(readiness, store, config) do
    Telemetry.span(:verify, fn -> do_verify_store(readiness, store, config) end)
  end

  defp do_verify_store(readiness, store, config) do
    with {:ok, _health} <- Readiness.transition(readiness, :begin_verification),
         :ok <- verify_quad_schema(store),
         {:ok, _health} <- Readiness.transition(readiness, :store_verified),
         lineage <- config.lineage_iri || Identity.lineage_iri(),
         {:ok, metadata} <- Metadata.ensure(store, config.schema_version, lineage),
         {:ok, _health} <- Readiness.transition(readiness, :ready) do
      {:ok, metadata}
    else
      {:error, %Error{} = error} ->
        safe_close(store)
        {:error, error}

      {:error, reason} ->
        safe_close(store)
        {:error, BackendFailure.translate(reason, :verify_store_schema)}
    end
  end

  defp verify_quad_schema(store) do
    case ErlangAdapter.is_quad_store?(store.db) do
      {:ok, true} -> :ok
      {:ok, false} -> {:error, Error.new(:incompatible, :verify_store_schema)}
      {:error, reason} -> {:error, BackendFailure.translate(reason, :verify_store_schema)}
    end
  end

  defp monitor_store_processes(store) do
    [store.db, store.dict_manager]
    |> Enum.filter(&is_pid/1)
    |> Enum.uniq()
    |> Map.new(fn pid -> {Process.monitor(pid), pid} end)
  end

  defp fail_startup(state, error) do
    Readiness.transition(state.readiness, {:fail, error})
    %{state | store: nil, metadata: nil, last_error: error, monitors: %{}}
  end

  defp public_summary(state) do
    health = Readiness.snapshot(state.readiness)

    %{
      ready?: JidoCode.Knowledge.Health.ready?(health),
      health_state: health.state,
      store_open?: not is_nil(state.store),
      schema: config_value(state.config, :schema),
      schema_version: config_value(state.config, :schema_version),
      durability: config_value(state.config, :durability),
      dataset_revision: metadata_value(state.metadata, :dataset_revision),
      lineage_present?: is_map(state.metadata) and is_binary(state.metadata.lineage),
      failure: public_error(state.last_error)
    }
  end

  defp dispatch(:metadata, state) do
    metadata = %{
      store_schema_version: state.metadata.store_schema_version,
      backend_schema_version: state.metadata.backend_schema_version,
      dataset_revision: state.metadata.dataset_revision,
      system_graph_revision: state.metadata.system_graph_revision,
      lineage_present?: is_binary(state.metadata.lineage)
    }

    {:ok, metadata, state}
  end

  defp dispatch(:statistics, state) do
    case QuadOperations.graphs_summary(state.store.db) do
      {:ok, graphs} ->
        statistics = %{
          graph_count: map_size(graphs),
          quad_count: graphs |> Map.values() |> Enum.sum()
        }

        {:ok, statistics, state}

      {:error, reason} ->
        {:error, BackendFailure.translate(reason, :store_statistics)}
    end
  end

  defp dispatch({:graph_counts, graphs}, state) when is_list(graphs) and length(graphs) <= 100 do
    if Enum.all?(graphs, &(is_binary(&1) and RDF.IRI.valid?(&1))) do
      counts =
        Map.new(graphs, fn graph ->
          count =
            case QuadOperations.graph_quad_count(
                   state.store.db,
                   state.store.dict_manager,
                   RDF.iri(graph)
                 ) do
              {:ok, value} -> value
              {:error, _reason} -> :unavailable
            end

          {graph, count}
        end)

      if Enum.any?(counts, fn {_graph, count} -> count == :unavailable end) do
        {:error, Error.new(:unavailable, :read_graph_counts)}
      else
        {:ok, counts, state}
      end
    else
      {:error, Error.new(:invalid_input, :read_graph_counts)}
    end
  end

  defp dispatch({:atomic_update, batch}, state) do
    case AtomicCommit.apply(state.store, state.metadata, batch) do
      {:ok, receipt, metadata} -> {:ok, receipt, %{state | metadata: metadata}}
      {:error, %Error{} = error} -> {:error, error}
      {:error, %Error{} = error, details} -> {:error, error, details}
    end
  end

  defp dispatch({:receipt, commit_id}, state) do
    case CommitLog.lookup(state.store, commit_id) do
      {:ok, receipt} -> {:ok, receipt, state}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp dispatch({:enter_maintenance, reason}, state) do
    case Readiness.transition(state.readiness, {:enter_maintenance, reason}) do
      {:ok, health} ->
        {:ok, %{health_state: health.state, reason: health.maintenance_reason}, state}

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp dispatch(:leave_maintenance, state) do
    case Readiness.transition(state.readiness, :leave_maintenance) do
      {:ok, health} -> {:ok, %{health_state: health.state}, state}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp dispatch(_request, _state), do: {:error, Error.new(:invalid_input, :store_request)}

  defp gate_request(_state, operation) when operation in [:leave_maintenance], do: :ok

  defp gate_request(state, :enter_maintenance) do
    Readiness.gate(state.readiness, :enter_maintenance)
  end

  defp gate_request(state, _operation) do
    Readiness.gate(state.readiness, :store_request)
  end

  defp operation(operation) when is_atom(operation), do: operation
  defp operation({operation, _payload}) when is_atom(operation), do: operation
  defp operation(_request), do: nil

  defp role_for(operation) do
    case Map.fetch(@operation_roles, operation) do
      {:ok, role} -> {:ok, role}
      :error -> {:error, Error.new(:invalid_input, :store_request)}
    end
  end

  defp operation_class(:read), do: :read
  defp operation_class(:write), do: :write
  defp operation_class(:maintenance), do: :maintenance

  defp authorize(state, role, caller) do
    authorized = Map.get(state.authorized_callers, role, [])

    if Enum.any?(authorized, &caller_matches?(&1, caller)) do
      :ok
    else
      {:error, Error.new(:unauthorized, :store_request)}
    end
  end

  defp caller_matches?(pid, caller) when is_pid(pid), do: pid == caller

  defp caller_matches?(name, caller) when is_atom(name) do
    Process.whereis(name) == caller
  end

  defp caller_matches?({:global, name}, caller) do
    :global.whereis_name(name) == caller
  end

  defp caller_matches?(_identity, _caller), do: false

  defp normalize_open_result({:ok, store}), do: {:ok, store}

  defp normalize_open_result({:error, reason}),
    do: {:error, BackendFailure.translate(reason, :open_store)}

  defp normalize_open_result(_result), do: {:error, Error.new(:unavailable, :open_store)}

  defp cancel_opener(opener, monitor, token) do
    send(opener, {:cancel_store_open, token})

    receive do
      {:DOWN, ^monitor, :process, ^opener, _reason} -> :ok
    after
      250 ->
        Process.exit(opener, :kill)
        await_opener(monitor, opener)
    end
  end

  defp await_opener(monitor, opener) do
    receive do
      {:DOWN, ^monitor, :process, ^opener, _reason} -> :ok
    after
      1_000 -> Process.demonitor(monitor, [:flush])
    end
  end

  defp close_open_result({:ok, store}), do: safe_close(store)
  defp close_open_result(_result), do: :ok

  defp safe_close(nil), do: :ok

  defp safe_close(store) do
    TripleStore.close(store)
  catch
    :exit, _reason -> :ok
  end

  defp config_value(nil, _key), do: nil
  defp config_value(config, key), do: Map.fetch!(config, key)

  defp metadata_value(nil, _key), do: nil
  defp metadata_value(metadata, key), do: Map.fetch!(metadata, key)

  defp public_error(nil), do: nil
  defp public_error(%Error{} = error), do: Error.public(error)
end
