defmodule JidoCode.TestSupport.Phase04Fixture do
  @moduledoc false

  alias JidoCode.Knowledge.Bootstrap
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @issued ~U[2026-07-31 19:00:00Z]
  @token "phase-04-integration-operator-token"

  def start!(context) do
    root = unique_root(context)
    {:ok, config} = Config.for_test(Path.join(root, "store"))

    identity = System.unique_integer([:positive, :monotonic])
    readiness = {:global, {__MODULE__, :readiness, identity}}
    store_server = {:global, {__MODULE__, :store, identity}}
    writer = {:global, {__MODULE__, :writer, identity}}
    query_runner = {:global, {__MODULE__, :query, identity}}
    maintenance = {:global, {__MODULE__, :maintenance, identity}}

    ExUnit.Callbacks.on_exit(fn ->
      Enum.each([writer, query_runner, maintenance, store_server, readiness], &stop_process/1)
      remove_root!(root)
    end)

    start_child!({Readiness, name: readiness})

    start_child!(
      {StoreServer,
       name: store_server,
       readiness: readiness,
       config: config,
       authorized_callers: %{
         read: [self(), query_runner],
         write: [writer],
         maintenance: [maintenance]
       }}
    )

    assert_ready!(store_server)
    start_child!({QueryRunner, name: query_runner, store_server: store_server})

    start_child!(
      {Writer,
       name: writer,
       store_server: store_server,
       clock: fn -> @issued end,
       bootstrap_config: %{
         enabled?: true,
         token_digest: Bootstrap.token_digest(@token)
       }}
    )

    start_child!({Maintenance, name: maintenance, store_server: store_server})

    %{
      root: root,
      config: config,
      readiness: readiness,
      store_server: store_server,
      writer: writer,
      query_runner: query_runner,
      maintenance: maintenance,
      issued_at: @issued
    }
  end

  def bootstrap!(substrate) do
    {:ok, ontology} =
      Release.load(store_server: substrate.store_server, writer: substrate.writer)

    actor = resource!("phase-04-actor")

    attributes = %{
      command_iri: local!(:command, 1),
      factory_iri: resource!("phase-04-factory"),
      principal_iri: actor,
      actor_iri: actor,
      factory_scope_iri: scope!(:factory, "phase-04-factory"),
      expected_dataset_revision: ontology.receipt.dataset_revision
    }

    {:ok, receipt} =
      Writer.bootstrap(substrate.writer, attributes, operator_token: @token)

    Map.merge(substrate, %{
      actor: actor,
      factory_iri: attributes.factory_iri,
      factory_scope: attributes.factory_scope_iri,
      bootstrap_command_iri: attributes.command_iri,
      graphs: receipt.graph_iris
    })
  end

  def enroll!(fixture) do
    repository = resource!("phase-04-managed-repository")
    repository_scope = scope!(:repository, "phase-04-managed-repository")

    envelope =
      envelope!(
        fixture,
        "EnrollRepository",
        local!(:command, 10),
        repository_scope,
        "phase-04-enrollment",
        %{
          fixture.graphs.catalog => 1
        },
        [
          %{
            family: :factory_catalog,
            graph_iri: fixture.graphs.catalog,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: [
              {repository, @rdf_type, iri("SoftwareRepository")},
              {repository, @jf <> "inScope", RDF.iri(repository_scope)}
            ],
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ],
        causation_iri: fixture.bootstrap_command_iri
      )

    {:ok, receipt} = Writer.execute(fixture.writer, envelope)

    Map.merge(fixture, %{
      repository: repository,
      repository_scope: repository_scope,
      enrollment_envelope: envelope,
      enrollment_receipt: receipt
    })
  end

  def assert_outcome!(fixture) do
    command_iri = local!(:command, 20)
    desired_outcome = local!(:goal, 21)
    goal = local!(:goal, 22)

    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: fixture.repository})

    control_metadata =
      metadata!(
        control_graph,
        fixture.repository_scope,
        command_iri,
        fixture.issued_at,
        :open
      )

    {:ok, control_metadata_quads} = GraphMetadata.quads(control_metadata)

    envelope =
      envelope!(
        fixture,
        "AssertDesiredOutcome",
        command_iri,
        fixture.repository_scope,
        "phase-04-desired-outcome",
        %{
          fixture.graphs.policy => 1,
          control_graph => 0
        },
        [
          %{
            family: :factory_policy,
            graph_iri: fixture.graphs.policy,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: [
              {desired_outcome, @rdf_type, iri("DesiredOutcome")},
              {desired_outcome, @jf <> "about", RDF.iri(fixture.repository)}
            ],
            supersessions: [],
            invalidations: [],
            removals: []
          },
          %{
            family: :repository_control,
            graph_iri: control_graph,
            operation: :create,
            metadata: control_metadata,
            additions:
              control_metadata_quads ++
                [
                  {goal, @rdf_type, iri("Goal"), control_graph},
                  {goal, @jf <> "about", RDF.iri(fixture.repository), control_graph}
                ],
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ],
        causation_iri: fixture.enrollment_envelope.command_iri
      )

    {:ok, receipt} = Writer.execute(fixture.writer, envelope)

    Map.merge(fixture, %{
      control_graph: control_graph,
      desired_outcome: desired_outcome,
      goal: goal,
      outcome_envelope: envelope,
      outcome_receipt: receipt
    })
  end

  def observe!(fixture) do
    command_iri = local!(:command, 30)
    batch = local!(:activity, 31)

    {:ok, observation_graph} =
      GraphRegistry.graph_iri(:observation_batch, %{
        repository: fixture.repository,
        batch: batch
      })

    metadata =
      metadata!(
        observation_graph,
        fixture.repository_scope,
        command_iri,
        fixture.issued_at,
        :closed
      )

    {:ok, metadata_quads} = GraphMetadata.quads(metadata)

    envelope =
      envelope!(
        fixture,
        "RecordObservationBatch",
        command_iri,
        fixture.repository_scope,
        "phase-04-observation",
        %{observation_graph => 0},
        [
          %{
            family: :observation_batch,
            graph_iri: observation_graph,
            operation: :create,
            metadata: metadata,
            additions:
              metadata_quads ++
                [
                  {batch, @rdf_type, iri("ObservationBatch"), observation_graph},
                  {batch, @jf <> "about", RDF.iri(fixture.repository), observation_graph}
                ],
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ],
        causation_iri: fixture.outcome_envelope.command_iri
      )

    {:ok, receipt} = Writer.execute(fixture.writer, envelope)

    Map.merge(fixture, %{
      observation_batch: batch,
      observation_graph: observation_graph,
      observation_envelope: envelope,
      observation_receipt: receipt
    })
  end

  def envelope!(
        fixture,
        command_type,
        command_iri,
        scope_iri,
        idempotency_key,
        expected_graph_revisions,
        changes,
        options \\ []
      ) do
    dataset_revision = StoreServer.summary(fixture.store_server).dataset_revision
    timestamp = :erlang.phash2(command_iri, 200) + 100

    {:ok, envelope} =
      CommandEnvelope.new(
        %{
          command_type: command_type,
          command_version: "1.0.0",
          command_iri: command_iri,
          principal_iri: fixture.actor,
          actor_iri: fixture.actor,
          delegated_agent_iri: nil,
          delegation_iri: nil,
          scope_iri: scope_iri,
          idempotency_key: idempotency_key,
          correlation_iri: local!(:activity, timestamp),
          causation_iri: Keyword.get(options, :causation_iri, fixture.bootstrap_command_iri),
          ontology_version: "1.0.0",
          shape_version: "1.0.0",
          expected_dataset_revision:
            Keyword.get(options, :expected_dataset_revision, dataset_revision),
          expected_graph_revisions: expected_graph_revisions,
          reason: Keyword.get(options, :reason, "phase 04 integration fixture"),
          payload: %{
            changes: changes,
            guards: Keyword.get(options, :guards, [])
          }
        },
        clock: fn -> fixture.issued_at end
      )

    envelope
  end

  def export_dataset!(fixture) do
    {:ok, export} = Maintenance.export(fixture.maintenance, :nquads, [])
    path = Path.join([fixture.config.backup_root, export.artifact_id, "dataset.nq"])
    {:ok, dataset} = path |> File.read!() |> RDF.NQuads.read_string()
    dataset
  end

  def current_graph_revision!(fixture, graph) do
    {:ok, metadata} = StoreServer.request(fixture.store_server, {:graph_metadata, graph})
    metadata.graph_revision
  end

  def restart_writer!(fixture) do
    start_child!(
      {Writer,
       name: fixture.writer,
       store_server: fixture.store_server,
       clock: fn -> @issued end,
       bootstrap_config: %{
         enabled?: true,
         token_digest: Bootstrap.token_digest(@token)
       }}
    )

    fixture
  end

  def kill_writer!(fixture) do
    pid = GenServer.whereis(fixture.writer)
    reference = Process.monitor(pid)
    Process.exit(pid, :kill)

    receive do
      {:DOWN, ^reference, :process, ^pid, :killed} -> :ok
    after
      5_000 -> raise "phase 04 writer did not terminate"
    end
  end

  def resource!(value) do
    {:ok, iri} = ResourceIdentity.repository(value)
    iri
  end

  def scope!(kind, value) do
    {:ok, iri} = ResourceIdentity.scope(kind, value)
    iri
  end

  def local!(kind, timestamp) do
    entropy = :binary.copy(<<rem(timestamp, 255)>>, 10)
    {:ok, iri} = ResourceIdentity.local(kind, timestamp, entropy)
    iri
  end

  defp metadata!(graph, owner_scope, activity, created_at, :open) do
    {:ok, metadata} =
      GraphMetadata.new(graph, %{
        owner_scope: owner_scope,
        ontology_version: "https://jido.run/ontology/release/1.0.0",
        creation_activity: activity,
        created_at: created_at,
        lifecycle_state: :open,
        completeness_state: :complete,
        graph_revision: 1
      })

    metadata
  end

  defp metadata!(graph, owner_scope, activity, created_at, :closed) do
    {:ok, metadata} =
      GraphMetadata.new(graph, %{
        owner_scope: owner_scope,
        ontology_version: "https://jido.run/ontology/release/1.0.0",
        creation_activity: activity,
        created_at: created_at,
        lifecycle_state: :closed,
        completeness_state: :complete,
        graph_revision: 1,
        closed_at: created_at
      })

    metadata
  end

  defp start_child!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> ExUnit.Callbacks.start_supervised!()
  end

  defp assert_ready!(server, attempts \\ 500)

  defp assert_ready!(server, 0) do
    raise "phase 04 store did not become ready: #{inspect(StoreServer.summary(server))}"
  end

  defp assert_ready!(server, attempts) do
    if StoreServer.summary(server).ready? do
      :ok
    else
      Process.sleep(10)
      assert_ready!(server, attempts - 1)
    end
  end

  defp iri(local), do: RDF.iri(@jf <> local)

  defp stop_process(name) do
    case GenServer.whereis(name) do
      pid when is_pid(pid) ->
        if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)

      _missing ->
        :ok
    end
  catch
    :exit, _reason -> :ok
  end

  defp remove_root!(root, attempts \\ 20)
  defp remove_root!(root, 0), do: File.rm_rf!(root)

  defp remove_root!(root, attempts) do
    case File.rm_rf(root) do
      {:ok, _paths} ->
        :ok

      {:error, _reason, _path} ->
        Process.sleep(25)
        remove_root!(root, attempts - 1)
    end
  end

  defp unique_root(context) do
    suffix = System.unique_integer([:positive, :monotonic])
    timestamp = System.system_time(:nanosecond)
    test = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-phase-04-#{test}-#{timestamp}-#{suffix}")
  end
end
