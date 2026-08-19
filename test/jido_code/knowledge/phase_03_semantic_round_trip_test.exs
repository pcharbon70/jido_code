defmodule JidoCode.Knowledge.Phase03SemanticRoundTripTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Claims
  alias JidoCode.Knowledge.Commands.Graphs
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.DerivedAuthority
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.QueryRunner
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Vocabulary
  alias JidoCode.Knowledge.Writer

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdf_subject "http://www.w3.org/1999/02/22-rdf-syntax-ns#subject"
  @prov_generated "http://www.w3.org/ns/prov#wasGeneratedBy"
  @ontology_graph "https://jido.run/graph/ontology/1.2.0"

  setup context do
    root = unique_root(context)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    %{config: config, substrate: start_substrate!(config)}
  end

  test "round-trips the ontology and representative semantic slice through restore", %{
    config: config,
    substrate: substrate
  } do
    assert {:ok, ontology_load} =
             Release.load(store_server: substrate.server, writer: substrate.writer)

    assert ontology_load.receipt.dataset_revision == 1
    fixture = load_fixture!(substrate)
    assert StoreServer.summary(substrate.server).dataset_revision == 7

    assert {:ok, checkpoint} = Maintenance.backup(substrate.maintenance, [])
    before_restore = export_dataset!(config, substrate.maintenance)

    assert_ontology_round_trip!(before_restore)
    assert_fixture_links!(before_restore, fixture)
    assert_graph_separation!(before_restore, fixture)
    assert RDF.Graph.empty?(RDF.Dataset.default_graph(before_restore))

    stale_derived = create_stale_derived!(substrate, fixture, 7)
    assert stale_derived.receipt.dataset_revision == 8

    assert {:ok,
            %{
              artifact_id: artifact_id,
              integrity_status: :ok
            }} =
             Maintenance.restore(substrate.maintenance, checkpoint.artifact_id,
               confirm: checkpoint.artifact_id
             )

    assert artifact_id == checkpoint.artifact_id
    restored = export_dataset!(config, substrate.maintenance)
    assert RDF.Dataset.equal?(application_dataset(before_restore), application_dataset(restored))

    assert canonical_dataset(application_dataset(before_restore)) ==
             canonical_dataset(application_dataset(restored))

    assert RDF.Graph.empty?(RDF.Dataset.default_graph(restored))

    assert {:ok, counts} =
             StoreServer.request(substrate.server, {
               :graph_counts,
               [stale_derived.graph_iri, fixture.graphs.observation]
             })

    assert counts[stale_derived.graph_iri] == 0
    assert counts[fixture.graphs.observation] > 0

    dataset_revision = StoreServer.summary(substrate.server).dataset_revision
    rebuilt = rebuild_derived!(substrate, stale_derived.metadata, fixture, dataset_revision)

    assert rebuilt.receipt.dataset_revision == dataset_revision + 1
    assert String.ends_with?(rebuilt.graph_iri, "/derived/eligibility/2")

    assert {:ok, derived_metadata} =
             QueryRunner.graph_metadata(rebuilt.graph_iri, server: substrate.query_runner)

    assert derived_metadata.source_graph_revisions == [
             %{graph: fixture.graphs.observation, revision: 1}
           ]

    assert {:ok, asserted_metadata} =
             QueryRunner.graph_metadata(fixture.graphs.observation,
               server: substrate.query_runner
             )

    assert asserted_metadata.graph_revision == 1

    after_rebuild = export_dataset!(config, substrate.maintenance)

    Enum.each(fixture.asserted_graphs, fn graph ->
      assert canonical_graph(before_restore, graph) == canonical_graph(after_rebuild, graph)
    end)
  end

  defp load_fixture!(substrate) do
    repository = repository!("phase-03-repository")
    factory = repository!("phase-03-factory")
    enrollment = repository!("phase-03-enrollment")
    policy = repository!("phase-03-policy")
    actor = repository!("phase-03-actor")
    owner_scope = scope!(:repository, "phase-03-repository")
    locator = locator!("github.com", "agentjido", "jido_code")
    observation_activity = local!(:activity, 100, 1)
    observation_batch = local!(:activity, 101, 2)
    finding = local!(:claim, 102, 3)
    goal = local!(:goal, 103, 4)
    task = local!(:goal, 104, 5)
    attempt = local!(:attempt, 105, 6)
    verification = local!(:activity, 106, 7)
    evidence = local!(:claim, 107, 8)
    claim = local!(:claim, 108, 9)
    decision = local!(:decision, 109, 10)

    {:ok, catalog_graph} = GraphRegistry.graph_iri(:factory_catalog, %{})
    {:ok, policy_graph} = GraphRegistry.graph_iri(:factory_policy, %{})

    {:ok, observation_graph} =
      GraphRegistry.graph_iri(:observation_batch, %{
        repository: repository,
        batch: observation_batch
      })

    {:ok, control_graph} =
      GraphRegistry.graph_iri(:repository_control, %{repository: repository})

    {:ok, run_graph} = GraphRegistry.graph_iri(:run_attempt, %{attempt: attempt})
    {:ok, evidence_graph} = GraphRegistry.graph_iri(:evidence, %{repository: repository})

    create!(
      substrate,
      :factory_catalog,
      %{},
      1,
      :catalog_writer,
      [
        triple(factory, @rdf_type, iri("RepositoryFactory")),
        triple(enrollment, @rdf_type, iri("ManagementEnrollment")),
        triple(repository, @rdf_type, iri("SoftwareRepository")),
        triple(locator.iri, @rdf_type, iri("RepositoryLocator")),
        triple(locator.iri, @jf <> "canonicalLocator", locator.canonical),
        triple(factory, @jf <> "enrolls", RDF.iri(enrollment)),
        triple(enrollment, @jf <> "manages", RDF.iri(repository)),
        triple(repository, @jf <> "locatedBy", RDF.iri(locator.iri))
      ],
      attributes(owner_scope, local!(:activity, 110, 11))
    )

    create!(
      substrate,
      :factory_policy,
      %{},
      2,
      :policy_writer,
      [
        triple(policy, @rdf_type, iri("Policy")),
        triple(policy, @jf <> "validFor", RDF.iri(owner_scope))
      ],
      attributes(owner_scope, local!(:activity, 111, 12))
    )

    create!(
      substrate,
      :observation_batch,
      %{repository: repository, batch: observation_batch},
      3,
      :observation_writer,
      [
        triple(observation_activity, @rdf_type, iri("ObservationActivity")),
        triple(observation_batch, @rdf_type, iri("ObservationBatch")),
        triple(observation_batch, @prov_generated, RDF.iri(observation_activity)),
        triple(observation_batch, @jf <> "about", RDF.iri(repository)),
        triple(finding, @rdf_type, iri("Finding")),
        triple(finding, @jf <> "about", RDF.iri(repository)),
        triple(finding, @jf <> "derivedFrom", RDF.iri(observation_batch))
      ],
      attributes(owner_scope, observation_activity, immutable?: true)
    )

    create!(
      substrate,
      :repository_control,
      %{repository: repository},
      4,
      :control_writer,
      [
        triple(goal, @rdf_type, iri("Goal")),
        triple(task, @rdf_type, iri("Task")),
        triple(goal, @jf <> "addresses", RDF.iri(finding)),
        triple(goal, @jf <> "governedBy", RDF.iri(policy)),
        triple(task, @jf <> "dependsOn", RDF.iri(goal))
      ],
      attributes(owner_scope, local!(:activity, 112, 13))
    )

    create!(
      substrate,
      :run_attempt,
      %{attempt: attempt},
      5,
      :execution_writer,
      [
        triple(attempt, @rdf_type, iri("ExecutionAttempt")),
        triple(attempt, @jf <> "executes", RDF.iri(task))
      ],
      attributes(owner_scope, local!(:activity, 113, 14))
    )

    {:ok, built_claim} =
      Claims.build(%{
        claim_iri: claim,
        graph_iri: evidence_graph,
        subject: goal,
        predicate: @jf <> "satisfies",
        object: RDF.iri(evidence),
        source_activity: verification,
        epistemic_state: :accepted,
        recorded_at: ~U[2026-07-31 12:00:00Z],
        decision: decision,
        decision_authority: actor,
        decision_at: ~U[2026-07-31 12:00:00Z],
        confidence_value: 0.9,
        confidence_band: :high
      })

    create!(
      substrate,
      :evidence,
      %{repository: repository},
      6,
      :evidence_writer,
      [
        triple(evidence, @rdf_type, iri("EvidenceBundle")),
        triple(evidence, @jf <> "supports", RDF.iri(claim))
        | built_claim.quads
      ],
      attributes(owner_scope, verification)
    )

    graphs = %{
      catalog: catalog_graph,
      policy: policy_graph,
      observation: observation_graph,
      control: control_graph,
      run: run_graph,
      evidence: evidence_graph
    }

    %{
      repository: repository,
      policy: policy,
      finding: finding,
      goal: goal,
      task: task,
      attempt: attempt,
      claim: claim,
      decision: decision,
      graphs: graphs,
      asserted_graphs: graphs |> Map.values() |> Enum.sort(),
      owner_scope: owner_scope
    }
  end

  defp create_stale_derived!(substrate, fixture, expected_dataset_revision) do
    rule_set = repository!("eligibility-rules-v1")
    activity = local!(:activity, 120, 15)
    derived_finding = local!(:claim, 121, 16)

    attributes =
      attributes(fixture.owner_scope, activity, immutable?: true)
      |> Map.merge(%{
        rule_set: rule_set,
        source_graph_revisions: [%{graph: fixture.graphs.observation, revision: 0}],
        invalidation_state: :current
      })

    create!(
      substrate,
      :derived,
      %{rule_set: "eligibility", revision: 1},
      expected_dataset_revision,
      :reasoner,
      [
        triple(derived_finding, @rdf_type, iri("Finding")),
        triple(derived_finding, @jf <> "derivedFrom", RDF.iri(fixture.finding))
      ],
      attributes
    )
  end

  defp rebuild_derived!(substrate, stale_metadata, fixture, expected_dataset_revision) do
    activity = local!(:activity, 122, 17)
    rebuilt_finding = local!(:claim, 123, 18)

    assert {:ok, plan} =
             DerivedAuthority.rebuild_plan(
               stale_metadata,
               [%{graph: fixture.graphs.observation, revision: 1}],
               revision: 2,
               rule_set_slug: "eligibility",
               activity: activity,
               created_at: ~U[2026-07-31 12:30:00Z]
             )

    create!(
      substrate,
      plan.family,
      plan.scopes,
      expected_dataset_revision,
      plan.capability,
      [
        triple(rebuilt_finding, @rdf_type, iri("Finding")),
        triple(rebuilt_finding, @jf <> "derivedFrom", RDF.iri(fixture.finding))
      ],
      plan.attributes
    )
  end

  defp assert_ontology_round_trip!(dataset) do
    assert {:ok, expected} = Release.dataset()
    stored = dataset |> RDF.Dataset.graph(RDF.iri(@ontology_graph)) |> RDF.Dataset.new()
    assert semantically_equal?(stored, expected)

    assert length(RDF.Graph.triples(RDF.Dataset.graph(dataset, RDF.iri(@ontology_graph)))) ==
             1_783
  end

  defp assert_fixture_links!(dataset, fixture) do
    assert_quad(
      dataset,
      fixture.graphs.observation,
      fixture.finding,
      @jf <> "about",
      fixture.repository
    )

    assert_quad(
      dataset,
      fixture.graphs.control,
      fixture.goal,
      @jf <> "addresses",
      fixture.finding
    )

    assert_quad(
      dataset,
      fixture.graphs.control,
      fixture.goal,
      @jf <> "governedBy",
      fixture.policy
    )

    assert_quad(dataset, fixture.graphs.run, fixture.attempt, @jf <> "executes", fixture.task)
    assert_quad(dataset, fixture.graphs.evidence, fixture.claim, @rdf_subject, fixture.goal)

    assert_quad(
      dataset,
      fixture.graphs.evidence,
      fixture.decision,
      @jf <> "accepts",
      fixture.claim
    )
  end

  defp assert_graph_separation!(dataset, fixture) do
    owl_class = RDF.iri("http://www.w3.org/2002/07/owl#Class")

    Enum.each(fixture.asserted_graphs, fn graph ->
      graph_data = RDF.Dataset.graph(dataset, RDF.iri(graph))
      assert RDF.Graph.include?(graph_data, RDF.triple(graph, @rdf_type, iri("NamedGraph")))

      refute Enum.any?(RDF.Graph.triples(graph_data), fn
               {_subject, %RDF.IRI{value: @rdf_type}, ^owl_class} -> true
               _other -> false
             end)
    end)

    ontology = RDF.Dataset.graph(dataset, RDF.iri(@ontology_graph))

    refute Enum.any?(RDF.Graph.triples(ontology), fn {subject, _predicate, _object} ->
             subject == RDF.iri(fixture.repository)
           end)
  end

  defp assert_quad(dataset, graph, subject, predicate, object) do
    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(subject, predicate, RDF.iri(object), graph)
           )
  end

  defp create!(substrate, family, scopes, expected_revision, capability, payload, attributes) do
    assert {:ok, created} =
             Graphs.create(family, scopes, payload, attributes,
               capability: capability,
               expected_dataset_revision: expected_revision,
               writer: substrate.writer
             )

    created
  end

  defp attributes(owner_scope, activity, options \\ []) do
    created_at = ~U[2026-07-31 12:00:00Z]

    %{
      owner_scope: owner_scope,
      ontology_version: "https://jido.run/ontology/release/1.0.0",
      creation_activity: activity,
      created_at: created_at
    }
    |> then(fn attributes ->
      if Keyword.get(options, :immutable?),
        do: Map.put(attributes, :closed_at, created_at),
        else: attributes
    end)
  end

  defp export_dataset!(config, maintenance) do
    assert {:ok, export} = Maintenance.export(maintenance, :nquads, [])
    path = Path.join([config.backup_root, export.artifact_id, "dataset.nq"])
    assert {:ok, dataset} = path |> File.read!() |> RDF.NQuads.read_string()
    dataset
  end

  defp application_dataset(dataset) do
    dataset
    |> RDF.Dataset.named_graphs()
    |> Enum.reject(&(RDF.IRI.to_string(&1.name) == Vocabulary.system_graph()))
    |> Enum.reduce(RDF.Dataset.new(), &RDF.Dataset.add(&2, &1))
  end

  defp canonical_graph(dataset, graph) do
    dataset
    |> RDF.Dataset.graph(RDF.iri(graph))
    |> RDF.Dataset.new()
    |> RDF.NQuads.write_string!(sort: true)
  end

  defp canonical_dataset(dataset), do: RDF.NQuads.write_string!(dataset, sort: true)

  defp semantically_equal?(left, right) do
    left_index = semantic_index(left)
    right_index = semantic_index(right)

    left_index |> Map.keys() |> Enum.sort() ==
      right_index |> Map.keys() |> Enum.sort() and
      Enum.all?(right_index, fn {statement, expected_objects} ->
        actual_objects = Map.fetch!(left_index, statement)

        length(actual_objects) == length(expected_objects) and
          Enum.all?(expected_objects, fn expected ->
            Enum.any?(actual_objects, &(RDF.Term.equal_value?(&1, expected) == true))
          end)
      end)
  end

  defp semantic_index(dataset) do
    Enum.group_by(
      RDF.Dataset.quads(dataset),
      fn {subject, predicate, _object, graph} -> {subject, predicate, graph} end,
      fn {_subject, _predicate, object, _graph} -> object end
    )
  end

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, :writer, make_ref()}}
    query_name = {:global, {__MODULE__, :query, make_ref()}}
    maintenance_name = {:global, {__MODULE__, :maintenance, make_ref()}}

    server =
      start_child!(
        {StoreServer,
         name: nil,
         readiness: readiness,
         config: config,
         authorized_callers: %{
           read: [query_name, self()],
           write: [writer_name],
           maintenance: [maintenance_name]
         }}
      )

    assert await_health(server, :ready).ready?
    writer = start_child!({Writer, name: writer_name, store_server: server})
    query_runner = start_child!({QueryRunner, name: query_name, store_server: server})
    maintenance = start_child!({Maintenance, name: maintenance_name, store_server: server})
    %{server: server, writer: writer, query_runner: query_runner, maintenance: maintenance}
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

  defp repository!(value), do: ok!(ResourceIdentity.repository(value))
  defp scope!(kind, value), do: ok!(ResourceIdentity.scope(kind, value))

  defp locator!(host, owner, repository),
    do: ok!(ResourceIdentity.repository_locator(host, owner, repository))

  defp local!(kind, timestamp, byte),
    do: ok!(ResourceIdentity.local(kind, timestamp, :binary.copy(<<byte>>, 10)))

  defp ok!({:ok, value}), do: value
  defp triple(subject, predicate, object), do: RDF.triple(subject, predicate, object)
  defp iri(local), do: RDF.iri(@jf <> local)

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-phase-03-round-trip-#{name}-#{unique}")
  end
end
