defmodule JidoCode.Knowledge.GraphTopologyTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Commands.Graphs
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer

  setup context do
    root = unique_root(context)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{config: config}
  end

  test "atomically creates a registered graph with queryable metadata", %{config: config} do
    substrate = start_substrate!(config)
    {:ok, owner_scope} = ResourceIdentity.scope(:factory, "jido")
    {:ok, activity} = ResourceIdentity.local(:activity, 100, <<1::80>>)
    {:ok, repository} = ResourceIdentity.repository("repository:one")
    {:ok, locator} = ResourceIdentity.repository_locator("github.com", "agentjido", "jido_code")
    {:ok, graph_iri} = GraphRegistry.graph_iri(:factory_catalog, %{})

    payload = [
      RDF.triple(repository, rdf_type(), RDF.iri(term("SoftwareRepository"))),
      RDF.triple(repository, term("locatedBy"), RDF.iri(locator.iri)),
      RDF.triple(locator.iri, rdf_type(), RDF.iri(term("RepositoryLocator"))),
      RDF.triple(locator.iri, term("canonicalLocator"), locator.canonical)
    ]

    attributes = %{
      owner_scope: owner_scope,
      ontology_version: "https://jido.run/ontology/release/1.0.0",
      creation_activity: activity,
      created_at: ~U[2026-07-31 12:00:00Z]
    }

    assert {:ok, created} =
             Graphs.create(:factory_catalog, %{}, payload, attributes,
               capability: :catalog_writer,
               expected_dataset_revision: 0,
               writer: substrate.writer
             )

    assert created.graph_iri == graph_iri
    assert created.receipt.dataset_revision == 1
    assert created.receipt.graph_revisions[graph_iri] == %{prior: 0, new: 1}

    assert {:ok, metadata} =
             QueryRunner.graph_metadata(graph_iri, server: substrate.query_runner)

    assert metadata.type == "https://jido.run/ontology/factory#NamedGraph"
    assert metadata.owner_scope == owner_scope
    assert metadata.ontology_version == "https://jido.run/ontology/release/1.0.0"
    assert metadata.graph_revision == 1
    assert metadata.retention_class == "permanent"
    refute Map.has_key?(metadata, :canonical_locator)
  end

  test "rejects unregistered placement, wrong capabilities, and metadata impersonation", %{
    config: config
  } do
    substrate = start_substrate!(config)
    {:ok, owner_scope} = ResourceIdentity.scope(:factory, "jido")
    {:ok, activity} = ResourceIdentity.local(:activity, 100, <<2::80>>)
    {:ok, graph_iri} = GraphRegistry.graph_iri(:factory_catalog, %{})

    attributes = %{
      owner_scope: owner_scope,
      ontology_version: "https://jido.run/ontology/release/1.0.0",
      creation_activity: activity,
      created_at: ~U[2026-07-31 12:00:00Z]
    }

    assert {:error, %Error{kind: :unauthorized}} =
             Graphs.prepare_create(:factory_catalog, %{}, [], attributes,
               capability: :policy_writer,
               expected_dataset_revision: 0
             )

    forged = RDF.quad(graph_iri, term("ownerScope"), owner_scope, graph_iri)

    assert {:error, %Error{operation: :graph_metadata_authority}} =
             Graphs.prepare_create(:factory_catalog, %{}, [forged], attributes,
               capability: :catalog_writer,
               expected_dataset_revision: 0
             )

    assert {:error, %Error{operation: :graph_family}} =
             Graphs.prepare_create(:unknown, %{}, [], attributes,
               capability: :catalog_writer,
               expected_dataset_revision: 0,
               writer: substrate.writer
             )
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
           read: [query_name],
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

  defp rdf_type, do: "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  defp term(local), do: "https://jido.run/ontology/factory##{local}"

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-topology-#{name}-#{unique}")
  end
end
