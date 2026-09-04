defmodule JidoCode.Knowledge.CommandPipelineTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Authorization
  alias JidoCode.Knowledge.ChangeEvent
  alias JidoCode.Knowledge.ChangeFeed
  alias JidoCode.Knowledge.CommandEnvelope
  alias JidoCode.Knowledge.CommandStatus
  alias JidoCode.Knowledge.Commands.Graphs
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Filesystem

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_invalidated "http://www.w3.org/ns/prov#invalidatedAtTime"
  @issued ~U[2026-07-31 16:50:00Z]

  setup context do
    root = unique_root(context)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    substrate = start_substrate!(config)

    on_exit(fn ->
      stop_process(substrate.writer)
      stop_process(substrate.server)
      Filesystem.remove_root!(root)
    end)

    %{substrate: substrate}
  end

  test "commits provenance and audit atomically and recovers equivalent replay", %{
    substrate: substrate
  } do
    fixture = bootstrap_fixture!(substrate)
    envelope = envelope!(fixture, fixture.actor, 4, 1, "delivery-1", 20)

    assert :ok = ChangeFeed.subscribe(fixture.owner_scope)

    assert {:ok, %CommandStatus{outcome: :unknown}} =
             Writer.command_status(substrate.writer, envelope)

    assert {:ok, committed} = Writer.execute(substrate.writer, envelope)
    assert committed.outcome == :committed
    assert committed.dataset_revision == 5
    assert committed.assertion_count == 2
    assert committed.receipt_iri == envelope.command_iri <> "/receipt"
    assert fixture.audit_graph in committed.affected_graphs
    assert fixture.control_graph in committed.affected_graphs

    assert_receive {:jido_code_change, %ChangeEvent{} = event}
    assert event.dataset_revision == 5
    assert event.scope_iri == fixture.owner_scope
    assert event.command_class == "ProposeGoal"
    assert event.receipt_iri == committed.receipt_iri
    assert %{family: :repository_control, revision: 2} in event.affected_graphs

    assert {:refresh, %{hinted_dataset_revision: 5}} = ChangeFeed.requery(event, 4)

    assert {:ok, control_metadata} =
             StoreServer.request(substrate.server, {:graph_metadata, fixture.control_graph})

    assert control_metadata.graph_revision == 2

    assert {:ok, replayed} = Writer.execute(substrate.writer, envelope)
    assert replayed.outcome == :already_committed
    assert replayed.dataset_revision == 5
    refute_receive {:jido_code_change, _event}, 25
    assert StoreServer.summary(substrate.server).dataset_revision == 5

    assert {:ok, status} = Writer.command_status(substrate.writer, envelope)
    assert status.outcome == :committed
    assert status.command_iri == envelope.command_iri
    assert status.receipt_iri == committed.receipt_iri
    assert status.dataset_revision == 5

    divergent =
      envelope!(fixture, fixture.actor, 4, 1, "delivery-1", 21, command_iri: envelope.command_iri)

    assert {:ok, conflict} = Writer.execute(substrate.writer, divergent)
    assert conflict.outcome == :conflicted

    assert {:ok, %CommandStatus{outcome: :inaccessible}} =
             Writer.command_status(substrate.writer, divergent)

    assert StoreServer.summary(substrate.server).dataset_revision == 5

    revoke_grant!(substrate, fixture)

    assert {:ok, %CommandStatus{outcome: :inaccessible}} =
             Writer.command_status(substrate.writer, envelope)

    assert {:ok, revoked_replay} = Writer.execute(substrate.writer, envelope)
    assert revoked_replay.outcome == :unauthorized
    refute_receive {:jido_code_change, _event}, 25
  end

  test "fails closed for unauthorized, invalid, stale, and revoked commands", %{
    substrate: substrate
  } do
    fixture = bootstrap_fixture!(substrate)

    unauthorized_actor = resource!("pipeline-unauthorized-actor")
    unauthorized = envelope!(fixture, unauthorized_actor, 4, 1, "unauthorized", 30)

    assert {:ok, %CommandStatus{outcome: :inaccessible}} =
             Writer.command_status(substrate.writer, unauthorized)

    assert {:ok, denied} = Writer.execute(substrate.writer, unauthorized)
    assert denied.outcome == :unauthorized
    assert denied.command_iri == nil
    assert StoreServer.summary(substrate.server).dataset_revision == 4

    invalid =
      envelope!(fixture, fixture.actor, 4, 1, "invalid", 31,
        additions: [
          {local!(:goal, 31), @rdf_type, RDF.iri(@jf <> "CredentialReference")}
        ]
      )

    assert {:ok, rejected} = Writer.execute(substrate.writer, invalid)
    assert rejected.outcome == :invalid
    assert "class_not_allowed" in rejected.issues
    assert StoreServer.summary(substrate.server).dataset_revision == 4

    stale = envelope!(fixture, fixture.actor, 3, 1, "stale", 32)
    assert {:ok, stale_receipt} = Writer.execute(substrate.writer, stale)
    assert stale_receipt.outcome == :conflicted
    assert stale_receipt.current_revisions == %{fixture.control_graph => 1}

    revoked_fixture = revoke_grant!(substrate, fixture)
    revoked = envelope!(revoked_fixture, fixture.actor, 5, 1, "revoked", 33)
    assert {:ok, revoked_receipt} = Writer.execute(substrate.writer, revoked)
    assert revoked_receipt.outcome == :unauthorized
    assert StoreServer.summary(substrate.server).dataset_revision == 5
  end

  defp bootstrap_fixture!(substrate) do
    assert {:ok, loaded} = Release.load(store_server: substrate.server, writer: substrate.writer)
    assert loaded.receipt.dataset_revision == 1

    repository = resource!("pipeline-repository")
    actor = resource!("pipeline-actor")
    principal = actor
    owner_scope = scope!(:repository, "pipeline-repository")
    grant = resource!("pipeline-grant")
    creation = local!(:activity, 10)
    {:ok, policy_graph} = GraphRegistry.graph_iri(:factory_policy, %{})
    {:ok, audit_graph} = GraphRegistry.graph_iri(:security_audit, %{period: "2026-07"})

    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    create_graph!(
      substrate,
      :factory_policy,
      %{},
      1,
      :policy_writer,
      [
        {grant, @rdf_type, RDF.iri(@jf <> "AuthorizationGrant")},
        {grant, @jf <> "grantee", RDF.iri(actor)},
        {grant, @jf <> "grantsCapability", RDF.iri(Authorization.capability_iri(:proposal))},
        {grant, @jf <> "validFor", RDF.iri(owner_scope)},
        {grant, @jf <> "validFrom", RDF.XSD.DateTime.new(~U[2026-01-01 00:00:00Z])},
        {grant, @jf <> "validTo", RDF.XSD.DateTime.new(~U[2027-01-01 00:00:00Z])}
      ],
      attributes(owner_scope, creation)
    )

    create_graph!(
      substrate,
      :security_audit,
      %{period: "2026-07"},
      2,
      :security_auditor,
      [],
      attributes(owner_scope, local!(:activity, 11))
    )

    create_graph!(
      substrate,
      :repository_control,
      %{repository: repository},
      3,
      :control_writer,
      [],
      attributes(owner_scope, local!(:activity, 12))
    )

    %{
      repository: repository,
      actor: actor,
      principal: principal,
      owner_scope: owner_scope,
      grant: grant,
      policy_graph: policy_graph,
      audit_graph: audit_graph,
      control_graph: control_graph
    }
  end

  defp revoke_grant!(substrate, fixture) do
    assert {:ok, metadata} =
             StoreServer.request(substrate.server, {:graph_metadata, fixture.policy_graph})

    quad =
      RDF.quad(
        fixture.grant,
        @prov_invalidated,
        RDF.XSD.DateTime.new(@issued),
        fixture.policy_graph
      )

    dataset_revision = StoreServer.summary(substrate.server).dataset_revision

    {:ok, batch} =
      JidoCode.Knowledge.WriteBatch.new([quad],
        expected_dataset_revision: dataset_revision,
        expected_graph_revisions: %{fixture.policy_graph => metadata.graph_revision},
        operation_metadata: %{class: :test_grant_revocation},
        commit_id: "urn:jido-code:commit:test_grant_revocation"
      )

    assert {:ok, receipt} = Writer.commit(substrate.writer, batch, [])
    assert receipt.dataset_revision == dataset_revision + 1
    fixture
  end

  defp envelope!(
         fixture,
         actor,
         dataset_revision,
         graph_revision,
         idempotency,
         timestamp,
         options \\ []
       ) do
    goal = local!(:goal, timestamp)

    additions =
      Keyword.get(options, :additions, [
        {goal, @rdf_type, RDF.iri(@jf <> "Goal")},
        {goal, @jf <> "about", RDF.iri(fixture.repository)}
      ])

    attrs = %{
      command_type: "ProposeGoal",
      command_version: "1.0.0",
      command_iri: Keyword.get(options, :command_iri, local!(:command, timestamp)),
      principal_iri: actor,
      actor_iri: actor,
      delegated_agent_iri: nil,
      delegation_iri: nil,
      scope_iri: fixture.owner_scope,
      idempotency_key: idempotency,
      correlation_iri: local!(:activity, timestamp + 50),
      causation_iri: local!(:command, timestamp + 100),
      ontology_version: "1.0.0",
      shape_version: "1.0.0",
      expected_dataset_revision: dataset_revision,
      expected_graph_revisions: %{fixture.control_graph => graph_revision},
      reason: "pipeline fixture",
      payload: %{
        changes: [
          %{
            family: :repository_control,
            graph_iri: fixture.control_graph,
            operation: :append,
            metadata: %{lifecycle_state: :open},
            additions: additions,
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ]
      }
    }

    {:ok, envelope} = CommandEnvelope.new(attrs, clock: fn -> @issued end)
    envelope
  end

  defp create_graph!(substrate, family, scopes, revision, capability, payload, attrs) do
    assert {:ok, created} =
             Graphs.create(family, scopes, payload, attrs,
               capability: capability,
               expected_dataset_revision: revision,
               writer: substrate.writer
             )

    created
  end

  defp attributes(owner_scope, activity) do
    %{
      owner_scope: owner_scope,
      ontology_version: "https://jido.run/ontology/release/1.0.0",
      creation_activity: activity,
      created_at: @issued
    }
  end

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, :writer, make_ref()}}

    server =
      start_child!(
        {StoreServer,
         name: nil,
         readiness: readiness,
         config: config,
         authorized_callers: %{
           read: [self()],
           write: [writer_name],
           maintenance: [self()]
         }}
      )

    assert await_health(server, :ready).ready?
    writer = start_child!({Writer, name: writer_name, store_server: server})
    %{server: server, writer: writer}
  end

  defp start_child!(child) do
    child
    |> Supervisor.child_spec(id: make_ref(), restart: :temporary)
    |> start_supervised!()
  end

  defp await_health(server, expected, attempts \\ 500)
  defp await_health(server, _expected, 0), do: StoreServer.summary(server)

  defp await_health(server, expected, attempts) do
    summary = StoreServer.summary(server)

    if summary.health_state == expected do
      summary
    else
      Process.sleep(10)
      await_health(server, expected, attempts - 1)
    end
  end

  defp stop_process(pid) do
    if Process.alive?(pid), do: GenServer.stop(pid)
  catch
    :exit, _reason -> :ok
  end

  defp resource!(value) do
    {:ok, iri} = ResourceIdentity.repository(value)
    iri
  end

  defp scope!(kind, value) do
    {:ok, iri} = ResourceIdentity.scope(kind, value)
    iri
  end

  defp local!(kind, timestamp) do
    entropy = :binary.copy(<<rem(timestamp, 255)>>, 10)
    {:ok, iri} = ResourceIdentity.local(kind, timestamp, entropy)
    iri
  end

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    timestamp = System.system_time(:nanosecond)
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-command-pipeline-#{name}-#{timestamp}-#{unique}")
  end
end
