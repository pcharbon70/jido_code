defmodule JidoCode.Knowledge.Validation.QuarantineMigrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Commands.Graphs
  alias JidoCode.Knowledge.Commands.Migrations
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Validation.Quarantine
  alias JidoCode.Knowledge.Writer

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  setup context do
    root = unique_root(context)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{substrate: start_substrate!(config)}
  end

  test "records only a bounded failed-import report through the audit path", %{
    substrate: substrate
  } do
    {:ok, repository} = ResourceIdentity.repository("quarantine-repository")
    {:ok, graph} = GraphRegistry.graph_iri(:evidence, %{repository: repository})
    {:ok, owner_scope} = ResourceIdentity.scope(:repository, "quarantine-repository")
    {:ok, activity} = ResourceIdentity.local(:activity, 100, <<1::80>>)
    {:ok, claim} = ResourceIdentity.local(:claim, 101, <<2::80>>)

    attributes = %{
      owner_scope: owner_scope,
      ontology_version: "https://jido.run/ontology/release/1.0.0",
      creation_activity: activity,
      created_at: ~U[2026-07-31 12:00:00Z]
    }

    invalid_payload = [
      RDF.triple(claim, @rdf_type, RDF.iri(@jf <> "Claim")),
      RDF.triple(claim, @jf <> "credentialKey", "token=do-not-store-this")
    ]

    assert {:error, %Error{operation: :semantic_validation}, report} =
             Graphs.prepare_create(
               :evidence,
               %{repository: repository},
               invalid_payload,
               attributes,
               capability: :evidence_writer,
               expected_dataset_revision: 0
             )

    refute inspect(report) =~ "do-not-store-this"
    assert {:ok, %{^graph => 0}} = StoreServer.request(substrate.server, {:graph_counts, [graph]})

    {:ok, audit_activity} = ResourceIdentity.local(:activity, 102, <<3::80>>)

    assert {:ok, recorded} =
             Quarantine.record(
               report,
               %{
                 period: "2026-07",
                 owner_scope: owner_scope,
                 activity: audit_activity,
                 recorded_at: ~U[2026-07-31 12:01:00Z]
               },
               expected_dataset_revision: 0,
               writer: substrate.writer
             )

    assert recorded.receipt.dataset_revision == 1
    assert String.ends_with?(recorded.graph_iri, "/security/audit/2026-07")
    refute recorded.batch.additions |> inspect() =~ "do-not-store-this"
  end

  test "creates an attributed migration target without rewriting the source graph", %{
    substrate: substrate
  } do
    {:ok, repository} = ResourceIdentity.repository("migration-repository")
    {:ok, source_batch} = ResourceIdentity.local(:activity, 90, <<4::80>>)

    {:ok, source_graph} =
      GraphRegistry.graph_iri(:observation_batch, %{
        repository: repository,
        batch: source_batch
      })

    {:ok, target_revision} =
      ResourceIdentity.git_object(:sha1, String.duplicate("b", 40))

    target_scopes = %{repository: repository, revision: target_revision}
    {:ok, target_graph} = GraphRegistry.graph_iri(:source_revision, target_scopes)
    {:ok, owner_scope} = ResourceIdentity.scope(:repository, "migration-repository")
    {:ok, activity} = ResourceIdentity.local(:migration, 200, <<5::80>>)
    {:ok, actor} = ResourceIdentity.repository("migration-actor")

    {:ok, validation_report} =
      ResourceIdentity.deterministic(:validation_report, "migration-validation")

    payload = [
      RDF.triple(
        "https://jido.run/id/content/sha256/#{String.duplicate("c", 64)}",
        @rdf_type,
        RDF.iri(@jf <> "SourceArtifact")
      )
    ]

    attributes = %{
      source_graph: source_graph,
      source_version: "0.9.0",
      target_version: "1.0.0",
      transformer_version: "2.0.0",
      actor: actor,
      activity: activity,
      owner_scope: owner_scope,
      validation_report: validation_report,
      rollback_posture: :retain_source,
      started_at: ~U[2026-07-31 12:00:00Z],
      completed_at: ~U[2026-07-31 12:00:01Z],
      source_count: 1,
      source_revision: target_revision
    }

    assert {:ok, migrated} =
             Migrations.create(:source_revision, target_scopes, payload, attributes,
               capability: :source_writer,
               expected_dataset_revision: 0,
               writer: substrate.writer
             )

    assert migrated.graph_iri == target_graph
    assert migrated.metadata.parent_graph == source_graph

    assert {:ok, counts} =
             StoreServer.request(substrate.server, {:graph_counts, [source_graph, target_graph]})

    assert counts[source_graph] == 0
    assert counts[target_graph] > 1
  end

  test "malformed quarantine and migration envelopes fail closed" do
    assert {:error, %Error{operation: :validation_quarantine}} =
             Quarantine.record(%{conforms?: false}, %{})

    assert {:error, %Error{operation: :graph_migration}} =
             Migrations.create(:source_revision, %{}, [], %{})
  end

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, :writer, make_ref()}}
    query_name = {:global, {__MODULE__, :query, make_ref()}}

    server =
      start_child!(
        {StoreServer,
         name: nil,
         readiness: readiness,
         config: config,
         authorized_callers: %{
           read: [query_name, self()],
           write: [writer_name],
           maintenance: [self()]
         }}
      )

    assert await_health(server, :ready).ready?
    writer = start_child!({Writer, name: writer_name, store_server: server})
    query_runner = start_child!({QueryRunner, name: query_name, store_server: server})
    %{server: server, writer: writer, query_runner: query_runner}
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

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-validation-#{name}-#{unique}")
  end
end
