defmodule JidoCode.Knowledge.Phase06SourcePublicationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.Observations.GitSnapshot
  alias JidoCode.Factory.Observations.Worktree
  alias JidoCode.Factory.SourceAnalysis.Command, as: SourceCommand
  alias JidoCode.Factory.SourceAnalysis.Request
  alias JidoCode.Factory.SourceAnalysis.Result
  alias JidoCode.Integrations.ElixirSourceAnalyzer
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Knowledge.GraphMetadata
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Projections.Source
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture

  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov "http://www.w3.org/ns/prov#"
  @jf "https://jido.run/ontology/factory#"
  @tree String.duplicate("d", 40)

  setup context do
    fixture = context |> Phase04Fixture.start!() |> Phase04Fixture.bootstrap!()
    fixture = create_snapshot_observation!(fixture)
    result = analyze_fixture!(fixture)

    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: fixture.actor,
        actor_iri: fixture.actor,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    {:ok, fixture: fixture, result: result, authority: authority}
  end

  test "publishes one closed source graph, replays identically, and projects exact semantics", %{
    fixture: fixture,
    result: result,
    authority: authority
  } do
    assert {:ok, publication} =
             SourceCommand.build(result, publication_context(fixture),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(fixture.writer, publication.command)
    assert receipt.outcome == :committed

    assert {:ok, replay} = Writer.execute(fixture.writer, publication.command)
    assert replay.outcome == :already_committed
    assert replay.receipt_iri == receipt.receipt_iri

    assert {:ok, metadata} =
             QueryRunner.graph_metadata(publication.graph_iri, server: fixture.query_runner)

    assert metadata.family == :source_revision
    assert metadata.lifecycle_state == :closed
    assert metadata.completeness_state == :complete
    assert metadata.source_revision == fixture.snapshot

    assert {:ok, readiness} =
             query(fixture, authority, :snapshot_readiness_freshness, %{
               graph: fixture.observation_graph,
               snapshot: fixture.snapshot
             })

    assert [%{"readiness" => %{value: readiness_state}}] = readiness.data
    assert String.ends_with?(readiness_state, "/Pending")

    assert {:ok, modules} =
             query(fixture, authority, :source_modules, %{
               graph: publication.graph_iri,
               snapshot: fixture.snapshot
             })

    module_row = Enum.find(modules.data, &(get_in(&1, ["name", :value]) == "Fixture.Server"))
    assert module_row
    module_iri = get_in(module_row, ["entity", :value])

    for {query_name, expected_column} <- [
          {:source_functions, "arity"},
          {:source_otp_patterns, "pattern"},
          {:source_dependencies, "dependency"}
        ] do
      assert {:ok, result} =
               query(fixture, authority, query_name, %{
                 graph: publication.graph_iri,
                 snapshot: fixture.snapshot
               })

      assert Enum.any?(result.data, &Map.has_key?(&1, expected_column))
    end

    assert {:ok, projection} =
             Source.build(modules, %{
               graph_iri: publication.graph_iri,
               snapshot_iri: fixture.snapshot,
               repository_iri: fixture.repository
             })

    assert projection.source.snapshot_iri == fixture.snapshot
    assert projection.source.graph_revision == 1
    assert projection.source.analyzer_version == "elixir-ast/1.0.0"
    assert projection.source.input_tree_digest == @tree
    assert projection.source.coverage == "complete"
    refute projection.source.stale?
    refute projection.source.degraded?

    assert {:ok, neighborhood} =
             query(fixture, authority, :source_entity_neighborhood, %{
               graph: publication.graph_iri,
               snapshot: fixture.snapshot,
               resource: module_iri
             })

    assert {:ok, neighborhood_projection} =
             Source.build(neighborhood, %{
               graph_iri: publication.graph_iri,
               snapshot_iri: fixture.snapshot,
               repository_iri: fixture.repository,
               resource_iri: module_iri
             })

    assert Enum.any?(neighborhood_projection.data, fn relationship ->
             relationship.direction == "outgoing" and is_binary(relationship.predicate)
           end)

    assert {:ok, impact} =
             query(fixture, authority, :source_impact, %{
               graph: publication.graph_iri,
               snapshot: fixture.snapshot,
               resource: module_iri
             })

    assert {:ok, impact_projection} =
             Source.build(impact, %{
               graph_iri: publication.graph_iri,
               snapshot_iri: fixture.snapshot,
               repository_iri: fixture.repository,
               resource_iri: module_iri
             })

    assert Enum.any?(impact_projection.data, fn relationship ->
             relationship.direction == "outgoing" and
               relationship.predicate == @jf <> "dependsOn"
           end)

    assert {:error, %{kind: :invalid_input}} =
             QueryRunner.execute(
               :source_modules,
               "1.1.0",
               %{graph: publication.graph_iri},
               authority,
               fixture.repository_scope,
               server: fixture.query_runner,
               evaluated_at: fixture.issued_at
             )

    assert {:error, %{kind: :unauthorized}} =
             query(
               fixture,
               authority,
               :source_modules,
               %{graph: publication.graph_iri, snapshot: fixture.snapshot},
               Phase04Fixture.scope!(:repository, "unauthorized-history")
             )
  end

  test "divergent output for one analyzer identity conflicts", %{
    fixture: fixture,
    result: result
  } do
    context = publication_context(fixture)

    assert {:ok, initial} =
             SourceCommand.build(result, context, clock: fn -> fixture.issued_at end)

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, initial.command)

    divergent = add_valid_divergence!(result, initial.graph_iri)

    next_context = %{
      context
      | expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision
    }

    assert {:ok, changed} =
             SourceCommand.build(divergent, next_context, clock: fn -> fixture.issued_at end)

    assert changed.activity_iri == initial.activity_iri
    assert changed.graph_iri == initial.graph_iri
    refute changed.dataset_digest == initial.dataset_digest
    assert {:ok, conflict} = Writer.execute(fixture.writer, changed.command)
    assert conflict.outcome == :conflicted
  end

  test "publication rejects schema mixing, wrong graph placement, and tree mismatch", %{
    fixture: fixture,
    result: result
  } do
    context = publication_context(fixture)
    [quad | _rest] = RDF.Dataset.quads(result.dataset)
    {subject, _predicate, _object, graph} = quad

    schema_mixed =
      replace_dataset!(result, [
        RDF.quad(
          subject,
          "http://www.w3.org/2000/01/rdf-schema#subClassOf",
          RDF.iri(@jf <> "CodeSymbol"),
          graph
        )
        | RDF.Dataset.quads(result.dataset)
      ])

    assert {:error, %{kind: :invalid_input, operation: :source_analysis_dataset}} =
             SourceCommand.build(schema_mixed, context, clock: fn -> fixture.issued_at end)

    {:ok, wrong_graph} =
      GraphRegistry.graph_iri(:source_revision, %{
        repository: fixture.repository,
        revision: resource!("wrong-source-revision")
      })

    wrong_placement =
      replace_dataset!(result, [
        RDF.quad(subject, @jf <> "otpPattern", RDF.XSD.String.new("Supervisor"), wrong_graph)
        | RDF.Dataset.quads(result.dataset)
      ])

    assert {:error, %{kind: :invalid_input, operation: :source_analysis_dataset}} =
             SourceCommand.build(wrong_placement, context, clock: fn -> fixture.issued_at end)

    assert {:error, %{kind: :invalid_input}} =
             SourceCommand.build(result, %{context | tree_digest: String.duplicate("e", 40)},
               clock: fn -> fixture.issued_at end
             )
  end

  defp create_snapshot_observation!(fixture) do
    repository = resource!("phase-06-source-repository")
    repository_scope = Phase04Fixture.scope!(:repository, "phase-06-source-repository")
    {:ok, snapshot} = ResourceIdentity.repository_snapshot(repository, :sha1, @tree)
    {:ok, tree_iri} = ResourceIdentity.git_object(:sha1, @tree)
    batch = Phase04Fixture.local!(:activity, 640)

    {:ok, graph} =
      GraphRegistry.graph_iri(:observation_batch, %{repository: repository, batch: batch})

    command_iri = Phase04Fixture.local!(:command, 640)

    {:ok, metadata} =
      GraphMetadata.new(graph, %{
        owner_scope: repository_scope,
        ontology_version: "https://jido.run/ontology/release/1.0.0",
        creation_activity: command_iri,
        created_at: fixture.issued_at,
        lifecycle_state: :closed,
        completeness_state: :complete,
        graph_revision: 1,
        closed_at: fixture.issued_at
      })

    {:ok, metadata_quads} = GraphMetadata.quads(metadata)

    command =
      Phase04Fixture.envelope!(
        fixture,
        "RecordObservationBatch",
        command_iri,
        repository_scope,
        "phase-06-source-snapshot",
        %{graph => 0},
        [
          %{
            family: :observation_batch,
            graph_iri: graph,
            operation: :create,
            metadata: metadata,
            additions:
              metadata_quads ++
                [
                  {batch, @rdf_type, iri("ObservationBatch"), graph},
                  {batch, @prov <> "generated", RDF.iri(snapshot), graph},
                  {batch, @jf <> "recordedAt", RDF.XSD.DateTime.new(fixture.issued_at), graph},
                  {snapshot, @rdf_type, iri("RepositorySnapshot"), graph},
                  {snapshot, @jf <> "about", RDF.iri(repository), graph},
                  {snapshot, @jf <> "treeIdentity", RDF.iri(tree_iri), graph},
                  {snapshot, @jf <> "sourceObservedAt", RDF.XSD.DateTime.new(fixture.issued_at),
                   graph},
                  {snapshot, @jf <> "analyzerReadiness",
                   RDF.iri("https://jido.run/ontology/concept/Pending"), graph}
                ],
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ]
      )

    assert {:ok, %{outcome: :committed}} = Writer.execute(fixture.writer, command)

    Map.merge(fixture, %{
      repository: repository,
      repository_scope: repository_scope,
      snapshot: snapshot,
      observation_graph: graph,
      observation_command: command
    })
  end

  defp analyze_fixture!(fixture) do
    path = Path.join(fixture.root, "source-worktree")
    File.mkdir_p!(Path.join(path, "lib"))

    File.write!(
      Path.join(path, "lib/server.ex"),
      """
      defmodule Fixture.Server do
        use GenServer
        alias Fixture.Dependency

        def start_link(argument), do: GenServer.start_link(__MODULE__, argument)
        def call(server), do: GenServer.call(server, :value)
        def dependency, do: Dependency.value()
      end
      """
    )

    {:ok, source_graph} =
      GraphRegistry.graph_iri(:source_revision, %{
        repository: fixture.repository,
        revision: fixture.snapshot
      })

    {:ok, request} =
      Request.new(%{
        repository_iri: fixture.repository,
        snapshot_iri: fixture.snapshot,
        worktree: %Worktree{
          operation_id: "phase-06-publication",
          remote_digest: String.duplicate("f", 64),
          ref: "refs/heads/main",
          created_at: fixture.issued_at,
          path: path
        },
        git_snapshot: git_snapshot!(),
        profile: :elixir,
        include_paths: ["lib"],
        exclude_paths: ["deps", "_build"],
        limits: %{
          max_files: 20,
          max_total_bytes: 100_000,
          max_file_bytes: 20_000,
          max_symbols: 50,
          max_expressions: 10_000,
          max_statements: 400,
          timeout_ms: 5_000
        },
        ontology_version: "1.0.0",
        output_graph_iri: source_graph,
        input_tree_digest: @tree
      })

    {:ok, analyzer} = ElixirSourceAnalyzer.new()
    {:ok, result} = ElixirSourceAnalyzer.analyze(analyzer, request)
    result
  end

  defp publication_context(fixture) do
    %{
      repository_iri: fixture.repository,
      repository_scope_iri: fixture.repository_scope,
      snapshot_iri: fixture.snapshot,
      observation_graph_iri: fixture.observation_graph,
      observation_graph_revision:
        Phase04Fixture.current_graph_revision!(fixture, fixture.observation_graph),
      tree_digest: @tree,
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      correlation_iri: Phase04Fixture.local!(:activity, 641),
      causation_iri: fixture.observation_command.command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      analyzed_at: fixture.issued_at,
      reason: "publish exact Phase 6 source semantics"
    }
  end

  defp add_valid_divergence!(result, graph) do
    quads = RDF.Dataset.quads(result.dataset)

    module =
      Enum.find_value(quads, fn
        {%RDF.IRI{value: subject}, %RDF.IRI{value: @rdf_type},
         %RDF.IRI{value: @jf <> "CodeSymbol"}, _graph} ->
          subject

        _other ->
          nil
      end)

    replace_dataset!(result, [
      RDF.quad(module, @jf <> "otpPattern", RDF.XSD.String.new("Supervisor"), graph) | quads
    ])
  end

  defp replace_dataset!(result, quads) do
    dataset = RDF.Dataset.new(quads)
    count = length(RDF.Dataset.quads(dataset))

    {:ok, changed} =
      Result.new(%{
        Map.from_struct(result)
        | dataset: dataset,
          resource_counts: %{result.resource_counts | triples: count}
      })

    changed
  end

  defp query(fixture, authority, name, parameters, scope \\ nil) do
    QueryRunner.execute(
      name,
      "1.1.0",
      parameters,
      authority,
      scope || fixture.repository_scope,
      server: fixture.query_runner,
      evaluated_at: fixture.issued_at
    )
  end

  defp iri(local), do: RDF.iri(@jf <> local)

  defp resource!(seed) do
    {:ok, iri} = ResourceIdentity.repository(seed)
    iri
  end

  defp git_snapshot! do
    {:ok, snapshot} =
      GitSnapshot.new(%{
        commit_sha: String.duplicate("c", 40),
        tree_sha: @tree,
        parents: [],
        ref: "refs/heads/main",
        object_format: :sha1,
        submodules?: false,
        lfs?: false,
        clean?: true,
        observed_at: ~U[2026-08-01 15:00:00Z],
        limitations: []
      })

    snapshot
  end
end
