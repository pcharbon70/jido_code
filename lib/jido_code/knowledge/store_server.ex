defmodule JidoCode.Knowledge.StoreServer do
  @moduledoc """
  Exclusive owner and execution boundary for the embedded `TripleStore`.

  Raw handles never leave this process. Internal callers are authorized by
  supervised process identity and can invoke only the fixed operation catalog.
  """

  use GenServer

  alias JidoCode.Knowledge.AtomicCommit
  alias JidoCode.Knowledge.BackendFailure
  alias JidoCode.Knowledge.Backup
  alias JidoCode.Knowledge.CommitLog
  alias JidoCode.Knowledge.CommandOutcome
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.DatasetSelector
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.Identity
  alias JidoCode.Knowledge.Integrity
  alias JidoCode.Knowledge.IntegrityReport
  alias JidoCode.Knowledge.Metadata
  alias JidoCode.Knowledge.Ontology.StartupGate
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.RestoreLog
  alias JidoCode.Knowledge.QueryExecution
  alias JidoCode.Knowledge.SemanticSnapshot
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
    graph_metadata: :read,
    catalog_query: :read,
    semantic_snapshot: :write,
    command_outcome: :write,
    atomic_update: :write,
    receipt: :write,
    checkpoint: :maintenance,
    backup: :maintenance,
    export: :maintenance,
    integrity: :maintenance,
    retention_candidates: :maintenance,
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
    :last_integrity,
    :last_backup,
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
      {:error, %Error{} = error} ->
        {:reply, {:error, error}, state}

      {:error, %Error{} = error, details} ->
        {:reply, {:error, error, details}, state}

      {:error_with_state, %Error{} = error, next_state} ->
        {:reply, {:error, error}, next_state}
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
         {:ok, last_backup} <- Backup.latest_checkpoint(config),
         {:ok, store} <- bounded_open(config),
         {:ok, metadata} <- verify_store(state.readiness, store, config) do
      monitors = monitor_store_processes(store)

      %{
        state
        | store: store,
          metadata: metadata,
          monitors: monitors,
          last_backup: last_backup
      }
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
    with {:ok, selection} <- DatasetSelector.current(config) do
      bounded_open_path(selection.path, config.open_timeout)
    end
  end

  defp bounded_open_path(path, timeout) do
    parent = self()
    token = make_ref()
    lock_release_deadline = System.monotonic_time(:millisecond) + min(timeout, 250)

    {opener, monitor} =
      spawn_monitor(fn ->
        result =
          Telemetry.span(:open, fn ->
            open_store(path, lock_release_deadline)
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
        adopt_open_result(result)

      {:DOWN, ^monitor, :process, ^opener, reason} ->
        {:error, BackendFailure.translate(reason, :open_store)}
    after
      timeout ->
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
         :ok <- StartupGate.verify(store),
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
      schema_compatible?: schema_compatible?(state),
      last_integrity: state.last_integrity,
      backup_age_seconds: backup_age_seconds(state.last_backup),
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

  defp dispatch({:graph_metadata, graph_iri}, state) do
    case GraphMetadata.read(state.store, graph_iri) do
      {:ok, metadata} -> {:ok, metadata, state}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp dispatch({:catalog_query, request}, state) do
    case QueryExecution.execute(state.store, state.metadata, request) do
      {:ok, result} -> {:ok, result, state}
      {:error, %Error{} = error} -> {:error, error}
      {:error, %Error{} = error, receipt} -> {:error, error, receipt}
    end
  end

  defp dispatch({:semantic_snapshot, graph_iris}, state) do
    case SemanticSnapshot.read(state.store, state.metadata, graph_iris) do
      {:ok, snapshot} -> {:ok, snapshot, state}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp dispatch(
         {:command_outcome,
          %{
            audit_graph: audit_graph,
            command_iri: command_iri,
            receipt_iri: receipt_iri
          }},
         state
       ) do
    case CommandOutcome.lookup(state.store, audit_graph, command_iri, receipt_iri) do
      {:ok, outcome} -> {:ok, outcome, state}
      {:error, %Error{} = error} -> {:error, error}
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

  defp dispatch(:backup, state) do
    run_backup(state, :backup, fn ->
      Backup.create_checkpoint(state.store, state.metadata, state.config)
    end)
  end

  defp dispatch(:checkpoint, state), do: dispatch(:backup, state)

  defp dispatch({:export, format}, state) do
    run_backup(state, :export, fn ->
      Backup.create_export(state.store, state.metadata, state.config, format)
    end)
  end

  defp dispatch(:integrity, state) do
    case Telemetry.span(:integrity, fn -> Integrity.check(state.store, state.metadata) end) do
      {:ok, report} -> {:ok, report, record_integrity(state, report)}
      {:error, %Error{} = error} -> {:error, error}
    end
  end

  defp dispatch({:retention_candidates, keep_latest}, state) do
    case Backup.retention_candidates(state.config, keep_latest) do
      {:ok, candidates} -> {:ok, candidates, state}
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

  defp dispatch({:restore, artifact_id}, state) do
    Telemetry.span(:restore, fn -> perform_restore(state, artifact_id) end)
  end

  defp dispatch(_request, _state), do: {:error, Error.new(:invalid_input, :store_request)}

  defp gate_request(_state, operation) when operation in [:leave_maintenance], do: :ok

  defp gate_request(state, :restore) do
    case Readiness.snapshot(state.readiness) do
      %{state: :maintenance, maintenance_reason: :restore} -> :ok
      _health -> {:error, Error.new(:unavailable, :restore)}
    end
  end

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

  defp adopt_open_result(result) do
    with {:ok, store} <- normalize_open_result(result),
         :ok <- link_store_processes(store) do
      {:ok, store}
    else
      {:error, %Error{} = error} ->
        close_open_result(result)
        {:error, error}
    end
  end

  defp link_store_processes(store) do
    [store.db, store.dict_manager]
    |> Enum.filter(&is_pid/1)
    |> Enum.uniq()
    |> Enum.each(&Process.link/1)

    :ok
  catch
    :exit, reason -> {:error, BackendFailure.translate(reason, :open_store)}
  end

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

  defp open_store(path, deadline) do
    case TripleStore.open(path, schema: :quad) do
      {:error, {:db_open, reason}} = error ->
        if transient_lock?(reason) and System.monotonic_time(:millisecond) < deadline do
          Process.sleep(20)
          open_store(path, deadline)
        else
          error
        end

      result ->
        result
    end
  end

  defp transient_lock?(reason) do
    reason
    |> to_string()
    |> String.contains?(["/LOCK", "lock hold", "No locks available"])
  rescue
    _error -> false
  end

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

  defp run_backup(state, operation, callback) do
    with {:ok, _health} <- Readiness.transition(state.readiness, :begin_backup) do
      result = safe_backup_callback(operation, callback)
      finish_result = Readiness.transition(state.readiness, :finish_backup)

      case {result, finish_result} do
        {{:ok, receipt}, {:ok, _health}} ->
          {:ok, receipt, record_backup(state, operation, receipt)}

        {{:error, %Error{} = error}, {:ok, _health}} ->
          {:error, error}

        {_result, {:error, %Error{} = error}} ->
          {:error, error}
      end
    end
  end

  defp safe_backup_callback(operation, callback) do
    Telemetry.span(operation, callback)
  rescue
    _error -> {:error, Error.new(:persistence_failure, :create_backup_artifact)}
  catch
    _kind, reason -> {:error, BackendFailure.translate(reason, :create_backup_artifact)}
  end

  defp perform_restore(state, artifact_id) do
    with {:ok, _health} <- Readiness.transition(state.readiness, :begin_recovery) do
      case restore_candidate(state, artifact_id) do
        {:ok, receipt, next_state} -> finish_restore(next_state, {:ok, receipt})
        {:error, %Error{} = error, next_state} -> finish_restore(next_state, {:error, error})
      end
    end
  end

  defp restore_candidate(state, artifact_id) do
    with {:ok, old_selection} <- DatasetSelector.current(state.config),
         {:ok, manifest, checkpoint_path} <- Backup.load_checkpoint(state.config, artifact_id),
         {:ok, dataset_id, candidate_path} <-
           Backup.stage_checkpoint(state.config, checkpoint_path) do
      restore_staged_candidate(state, old_selection, manifest, dataset_id, candidate_path)
    else
      {:error, %Error{} = error} -> {:error, error, state}
    end
  end

  defp restore_staged_candidate(state, old_selection, manifest, dataset_id, candidate_path) do
    closed_state = close_owned_store(state)

    case open_validated_candidate(closed_state, candidate_path, manifest) do
      {:ok, candidate_store, candidate_metadata} ->
        activate_restored_candidate(
          closed_state,
          old_selection,
          manifest,
          dataset_id,
          candidate_path,
          candidate_store,
          candidate_metadata
        )

      {:error, %Error{} = error} ->
        rollback_restore(closed_state, state, old_selection, candidate_path, error)
    end
  end

  defp open_validated_candidate(state, candidate_path, manifest) do
    case bounded_open_path(candidate_path, state.config.open_timeout) do
      {:ok, candidate_store} ->
        expected = manifest_metadata(manifest)

        with :ok <- verify_quad_schema(candidate_store),
             {:ok, metadata} when not is_nil(metadata) <- Metadata.read(candidate_store),
             :ok <- verify_expected_metadata(metadata, expected),
             {:ok, report} <- Integrity.check(candidate_store, expected),
             true <- IntegrityReport.healthy?(report),
             {:ok, restored_metadata} <-
               RestoreLog.record(candidate_store, metadata, manifest.payload_sha256),
             :ok <- verify_restore_increment(metadata, restored_metadata),
             {:ok, post_report} <- Integrity.check(candidate_store, restored_metadata),
             true <- IntegrityReport.healthy?(post_report) do
          {:ok, candidate_store, restored_metadata}
        else
          false -> close_candidate_error(candidate_store, :restore_integrity)
          {:ok, nil} -> close_candidate_error(candidate_store, :restore_metadata)
          {:error, %Error{} = error} -> close_candidate_error(candidate_store, error)
          {:error, _reason} -> close_candidate_error(candidate_store, :restore_candidate)
        end

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp activate_restored_candidate(
         state,
         old_selection,
         manifest,
         dataset_id,
         candidate_path,
         candidate_store,
         candidate_metadata
       ) do
    safe_close(candidate_store)

    with :ok <- DatasetSelector.activate(state.config, dataset_id),
         {:ok, selected} <- DatasetSelector.current(state.config),
         true <- selected.id == dataset_id and selected.path == candidate_path,
         {:ok, active_store} <- bounded_open_path(selected.path, state.config.open_timeout) do
      validate_activated_store(
        state,
        old_selection,
        manifest,
        candidate_path,
        active_store,
        candidate_metadata
      )
    else
      false ->
        error = Error.new(:persistence_failure, :activate_restored_dataset)
        rollback_restore(state, state, old_selection, candidate_path, error)

      {:error, %Error{} = error} ->
        rollback_restore(state, state, old_selection, candidate_path, error)
    end
  end

  defp validate_activated_store(
         state,
         old_selection,
         manifest,
         candidate_path,
         active_store,
         expected_metadata
       ) do
    with :ok <- verify_quad_schema(active_store),
         {:ok, actual_metadata} when not is_nil(actual_metadata) <- Metadata.read(active_store),
         :ok <- verify_expected_metadata(actual_metadata, expected_metadata),
         {:ok, report} <- Integrity.check(active_store, expected_metadata),
         true <- IntegrityReport.healthy?(report) do
      monitors = monitor_store_processes(active_store)

      receipt = %{
        artifact_id: manifest.artifact_id,
        dataset_revision: actual_metadata.dataset_revision,
        lineage: actual_metadata.lineage,
        integrity_status: report.status
      }

      {:ok, receipt,
       %{
         state
         | store: active_store,
           metadata: actual_metadata,
           monitors: monitors,
           last_error: nil,
           last_integrity: integrity_observation(report)
       }}
    else
      false ->
        safe_close(active_store)
        error = Error.new(:corrupt, :verify_restored_dataset)
        rollback_restore(state, state, old_selection, candidate_path, error)

      {:ok, nil} ->
        safe_close(active_store)
        error = Error.new(:corrupt, :verify_restored_dataset)
        rollback_restore(state, state, old_selection, candidate_path, error)

      {:error, %Error{} = error} ->
        safe_close(active_store)
        rollback_restore(state, state, old_selection, candidate_path, error)
    end
  end

  defp rollback_restore(closed_state, original_state, old_selection, candidate_path, cause) do
    with :ok <- DatasetSelector.activate(closed_state.config, old_selection.id),
         {:ok, rollback_store, rollback_metadata} <-
           open_validated_rollback(closed_state, old_selection.path, original_state.metadata) do
      Backup.remove_staged(candidate_path)
      monitors = monitor_store_processes(rollback_store)

      {:error, cause,
       %{
         closed_state
         | store: rollback_store,
           metadata: rollback_metadata,
           monitors: monitors,
           last_error: nil
       }}
    else
      _rollback_failure ->
        rollback_error = Error.new(:unavailable, :rollback_restore)
        Readiness.transition(closed_state.readiness, {:fail, rollback_error})

        {:error, rollback_error,
         %{closed_state | store: nil, metadata: nil, monitors: %{}, last_error: rollback_error}}
    end
  end

  defp open_validated_rollback(state, path, expected_metadata) do
    case bounded_open_path(path, state.config.open_timeout) do
      {:ok, rollback_store} ->
        with :ok <- verify_quad_schema(rollback_store),
             {:ok, rollback_metadata} when not is_nil(rollback_metadata) <-
               Metadata.read(rollback_store),
             :ok <- verify_expected_metadata(rollback_metadata, expected_metadata),
             {:ok, report} <- Integrity.check(rollback_store, expected_metadata),
             true <- IntegrityReport.healthy?(report) do
          {:ok, rollback_store, rollback_metadata}
        else
          _failure ->
            safe_close(rollback_store)
            {:error, Error.new(:unavailable, :rollback_restore)}
        end

      {:error, %Error{} = error} ->
        {:error, error}
    end
  end

  defp finish_restore(state, result) do
    if is_nil(state.store) do
      case result do
        {:error, %Error{} = error} -> {:error_with_state, error, state}
        {:ok, _receipt} -> {:error_with_state, Error.new(:unavailable, :restore), state}
      end
    else
      with {:ok, _health} <- Readiness.transition(state.readiness, :finish_recovery),
           {:ok, _health} <- Readiness.transition(state.readiness, :leave_maintenance) do
        case result do
          {:ok, receipt} -> {:ok, receipt, state}
          {:error, %Error{} = error} -> {:error_with_state, error, state}
        end
      else
        {:error, %Error{} = error} -> {:error_with_state, error, state}
      end
    end
  end

  defp close_candidate_error(store, %Error{} = error) do
    safe_close(store)
    {:error, error}
  end

  defp close_candidate_error(store, operation) do
    safe_close(store)
    {:error, Error.new(:corrupt, operation)}
  end

  defp close_owned_store(state) do
    Enum.each(Map.keys(state.monitors), &Process.demonitor(&1, [:flush]))
    safe_close(state.store)
    %{state | store: nil, monitors: %{}}
  end

  defp manifest_metadata(manifest) do
    %{
      store_schema_version: manifest.store_schema_version,
      backend_schema_version: manifest.backend_schema_version,
      lineage: manifest.lineage,
      dataset_revision: manifest.dataset_revision,
      system_graph_revision: manifest.system_graph_revision
    }
  end

  defp verify_expected_metadata(actual, expected) do
    keys = [
      :store_schema_version,
      :backend_schema_version,
      :lineage,
      :dataset_revision,
      :system_graph_revision
    ]

    if Map.take(actual, keys) == Map.take(expected, keys) do
      :ok
    else
      {:error, Error.new(:incompatible, :verify_restored_dataset)}
    end
  end

  defp verify_restore_increment(before, after_restore) do
    cond do
      after_restore.store_schema_version != before.store_schema_version ->
        {:error, Error.new(:corrupt, :record_restore_activity)}

      after_restore.backend_schema_version != before.backend_schema_version ->
        {:error, Error.new(:corrupt, :record_restore_activity)}

      after_restore.lineage != before.lineage ->
        {:error, Error.new(:corrupt, :record_restore_activity)}

      after_restore.dataset_revision != before.dataset_revision + 1 ->
        {:error, Error.new(:corrupt, :record_restore_activity)}

      after_restore.system_graph_revision != before.system_graph_revision + 1 ->
        {:error, Error.new(:corrupt, :record_restore_activity)}

      true ->
        :ok
    end
  end

  defp record_backup(state, :backup, receipt), do: %{state | last_backup: receipt}
  defp record_backup(state, _operation, _receipt), do: state

  defp record_integrity(state, report) do
    %{state | last_integrity: integrity_observation(report)}
  end

  defp integrity_observation(report) do
    %{
      status: report.status,
      dataset_revision: report.dataset_revision,
      issue_count: length(report.issues),
      checked_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
  end

  defp schema_compatible?(%{config: %Config{} = config, metadata: metadata})
       when is_map(metadata) do
    metadata.store_schema_version == config.schema_version and
      metadata.backend_schema_version == Metadata.backend_schema_version()
  end

  defp schema_compatible?(_state), do: false

  defp backup_age_seconds(nil), do: nil

  defp backup_age_seconds(%{created_at: created_at}) do
    case DateTime.from_iso8601(created_at) do
      {:ok, created, _offset} -> max(DateTime.diff(DateTime.utc_now(), created, :second), 0)
      _invalid -> nil
    end
  end
end
