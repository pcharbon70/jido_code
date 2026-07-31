defmodule JidoCode.Knowledge.DerivedAuthorityTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Commands.Graphs
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.DerivedAuthority
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer

  setup do
    {:ok, repository} = ResourceIdentity.repository("derived-repository")
    {:ok, revision_id} = ResourceIdentity.git_object(:sha1, String.duplicate("d", 40))

    {:ok, source_graph} =
      GraphRegistry.graph_iri(:source_revision, %{repository: repository, revision: revision_id})

    {:ok, graph_iri} = GraphRegistry.graph_iri(:derived, %{rule_set: "eligibility", revision: 1})
    {:ok, owner_scope} = ResourceIdentity.scope(:repository, "derived-repository")
    {:ok, activity} = ResourceIdentity.local(:activity, 100, <<1::80>>)
    {:ok, rule_set} = ResourceIdentity.repository("eligibility-rules-v1")

    attributes = %{
      owner_scope: owner_scope,
      ontology_version: "https://jido.run/ontology/release/1.0.0",
      creation_activity: activity,
      created_at: ~U[2026-07-31 12:00:00Z],
      closed_at: ~U[2026-07-31 12:00:00Z],
      lifecycle_state: :closed,
      completeness_state: :complete,
      rule_set: rule_set,
      source_graph_revisions: [%{graph: source_graph, revision: 1}],
      invalidation_state: :current
    }

    {:ok, metadata} = GraphMetadata.new(graph_iri, attributes)

    %{
      metadata: metadata,
      attributes: attributes,
      source_graph: source_graph,
      owner_scope: owner_scope,
      activity: activity,
      rule_set: rule_set
    }
  end

  test "requires reproducible metadata on every derived graph", context do
    assert {:ok, prepared} =
             Graphs.prepare_create(
               :derived,
               %{rule_set: "eligibility", revision: 1},
               [],
               context.attributes,
               capability: :reasoner,
               expected_dataset_revision: 0
             )

    assert prepared.metadata.invalidation_state == :current

    assert prepared.metadata.source_graph_revisions == [
             %{graph: context.source_graph, revision: 1}
           ]

    refute inspect(prepared.batch.additions) =~ "#{context.source_graph}|1"

    assert Enum.any?(prepared.batch.additions, fn
             {_subject, %RDF.IRI{value: predicate}, %RDF.IRI{}, _graph} ->
               predicate == "https://jido.run/ontology/factory#sourceGraphRevision"

             _other ->
               false
           end)

    invalid = Map.delete(context.attributes, :invalidation_state)

    assert {:error, %Error{operation: :derived_graph_metadata}} =
             GraphMetadata.new(context.metadata.graph_iri, invalid)
  end

  test "round-trips first-class source revision references through the store", context do
    root =
      Path.join(
        System.tmp_dir!(),
        "jido-derived-metadata-#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    substrate = start_substrate!(config)

    assert {:ok, created} =
             Graphs.create(
               :derived,
               %{rule_set: "eligibility", revision: 1},
               [],
               context.attributes,
               capability: :reasoner,
               expected_dataset_revision: 0,
               writer: substrate.writer
             )

    assert {:ok, metadata} =
             QueryRunner.graph_metadata(created.graph_iri, server: substrate.query_runner)

    assert metadata.source_graph_revisions == [%{graph: context.source_graph, revision: 1}]
    assert metadata.invalidation_state == :current
  end

  test "classifies current, stale, incompatible, and invalidated graphs", context do
    assert {:ok, :current} =
             DerivedAuthority.status(context.metadata, [
               %{graph: context.source_graph, revision: 1}
             ])

    assert {:ok, :stale} =
             DerivedAuthority.status(context.metadata, [
               %{graph: context.source_graph, revision: 2}
             ])

    assert {:ok, :incompatible} =
             DerivedAuthority.status(
               context.metadata,
               [
                 %{graph: context.source_graph, revision: 1}
               ],
               ontology_version: "https://jido.run/ontology/release/2.0.0"
             )

    assert {:ok, :invalidated} =
             context.metadata
             |> Map.put(:invalidation_state, :invalidated)
             |> DerivedAuthority.status([%{graph: context.source_graph, revision: 1}])

    assert {:error, %Error{operation: :derived_graph_status}} =
             DerivedAuthority.status(%{family: :derived}, [
               %{graph: context.source_graph, revision: 1}
             ])
  end

  test "derived statements need a governed decision for authoritative operations", context do
    source = %{family: :derived, graph_iri: context.metadata.graph_iri}

    assert {:error, %Error{kind: :unauthorized}} =
             DerivedAuthority.authorize(:accept_claim, source, nil)

    {:ok, decision} = ResourceIdentity.local(:decision, 110, <<2::80>>)
    {:ok, authority} = ResourceIdentity.repository("derived-authority")
    {:ok, policy} = ResourceIdentity.repository("derived-policy")

    assert :ok =
             DerivedAuthority.authorize(:accept_claim, source, %{
               decision_iri: decision,
               authority: authority,
               policy: policy,
               consumes_graph: context.metadata.graph_iri
             })

    assert :ok = DerivedAuthority.authorize(:advisory_read, source, nil)
  end

  test "stale graphs produce a new disposable graph plan while incompatible graphs block",
       context do
    current_sources = [%{graph: context.source_graph, revision: 2}]
    {:ok, activity} = ResourceIdentity.local(:activity, 120, <<3::80>>)

    assert {:ok, plan} =
             DerivedAuthority.rebuild_plan(context.metadata, current_sources,
               revision: 2,
               rule_set_slug: "eligibility",
               activity: activity,
               created_at: ~U[2026-07-31 13:00:00Z]
             )

    assert String.ends_with?(plan.graph_iri, "/derived/eligibility/2")
    assert plan.attributes.source_graph_revisions == current_sources
    assert plan.attributes.invalidation_state == :current

    assert {:error, %Error{kind: :incompatible}} =
             DerivedAuthority.rebuild_plan(context.metadata, current_sources,
               ontology_version: "https://jido.run/ontology/release/2.0.0",
               revision: 2,
               rule_set_slug: "eligibility",
               activity: activity,
               created_at: ~U[2026-07-31 13:00:00Z]
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
end
