defmodule JidoCode.Knowledge.Phase03SemanticFalsificationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Claims
  alias JidoCode.Knowledge.Commands.Graphs
  alias JidoCode.Knowledge.Commands.Migrations
  alias JidoCode.Knowledge.Config
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.GraphRegistry
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.Ontology.Evolution
  alias JidoCode.Knowledge.Ontology.Release
  alias JidoCode.Knowledge.Readiness
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Transitions
  alias JidoCode.Knowledge.Writer

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @rdf_subject "http://www.w3.org/1999/02/22-rdf-syntax-ns#subject"
  @rdf_predicate "http://www.w3.org/1999/02/22-rdf-syntax-ns#predicate"
  @rdf_object "http://www.w3.org/1999/02/22-rdf-syntax-ns#object"

  setup context do
    root = unique_root(context)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, config} = Config.for_test(Path.join(root, "store"))
    substrate = start_substrate!(config)
    assert {:ok, _loaded} = Release.load(store_server: substrate.server, writer: substrate.writer)
    %{config: config, substrate: substrate}
  end

  test "well-formed but invalid semantic writes never become visible", %{substrate: substrate} do
    repository = repository!("invalid-semantics-repository")
    owner_scope = scope!(:repository, "invalid-semantics-repository")
    activity = local!(:activity, 200, 1)
    claim = local!(:claim, 201, 2)
    {:ok, graph} = GraphRegistry.graph_iri(:evidence, %{repository: repository})
    attributes = attributes(owner_scope, activity)

    assert {:error, %Error{}} =
             ResourceIdentity.repository_locator("github.com", "agentjido", "../secrets")

    assert {:error, %Error{operation: :graph_identity}} =
             GraphRegistry.identify("https://jido.run/graph/unregistered/data")

    assert {:error, %Error{operation: :graph_owner_scope}} =
             Graphs.create(
               :evidence,
               %{repository: repository},
               [],
               Map.delete(attributes, :owner_scope),
               capability: :evidence_writer,
               expected_dataset_revision: 1,
               writer: substrate.writer
             )

    assert {:error, %Error{operation: :semantic_validation}, class_report} =
             Graphs.create(
               :evidence,
               %{repository: repository},
               [triple(claim, @rdf_type, iri("ExecutionAttempt"))],
               attributes,
               capability: :evidence_writer,
               expected_dataset_revision: 1,
               writer: substrate.writer
             )

    assert Enum.any?(class_report.issues, &(&1.issue_code == "class_not_allowed"))

    assert {:error, %Error{operation: :cross_graph_link}} =
             Graphs.create(
               :evidence,
               %{repository: repository},
               [
                 triple(
                   claim,
                   @jf <> "sourceGraph",
                   RDF.iri("https://jido.run/graph/unregistered/data")
                 )
               ],
               attributes,
               capability: :evidence_writer,
               expected_dataset_revision: 1,
               writer: substrate.writer
             )

    malformed_claim = [
      triple(claim, @rdf_type, iri("Claim")),
      triple(claim, @rdf_subject, RDF.iri(repository)),
      triple(claim, @rdf_subject, RDF.iri(activity)),
      triple(claim, @rdf_predicate, RDF.iri(@jf <> "governedBy")),
      triple(claim, @rdf_object, RDF.literal("proposition")),
      triple(claim, @jf <> "sourceActivity", RDF.iri(activity)),
      triple(claim, @jf <> "graphScope", RDF.iri(graph)),
      triple(
        claim,
        @jf <> "epistemicState",
        RDF.iri("https://jido.run/ontology/concept/Unreviewed")
      ),
      triple(claim, @jf <> "recordedAt", RDF.literal("yesterday")),
      triple(claim, @jf <> "confidenceValue", RDF.XSD.Decimal.new("1.5")),
      triple(claim, @jf <> "credentialKey", RDF.literal("token=do-not-persist"))
    ]

    assert {:error, %Error{operation: :semantic_validation}, claim_report} =
             Graphs.create(
               :evidence,
               %{repository: repository},
               malformed_claim,
               attributes,
               capability: :evidence_writer,
               expected_dataset_revision: 1,
               writer: substrate.writer
             )

    issue_codes = MapSet.new(claim_report.issues, & &1.issue_code)

    assert MapSet.subset?(
             MapSet.new(
               ~w[cardinality unknown_epistemic_state datatype invalid_confidence secret_literal]
             ),
             issue_codes
           )

    refute inspect(claim_report) =~ "do-not-persist"

    assert {:error, %Error{operation: :claim_confidence}} =
             Claims.build(%{
               claim_iri: claim,
               graph_iri: graph,
               subject: repository,
               predicate: @jf <> "governedBy",
               object: RDF.literal("policy"),
               source_activity: activity,
               epistemic_state: :proposed,
               recorded_at: ~U[2026-07-31 12:00:00Z],
               confidence_value: 2
             })

    assert {:ok, %{^graph => 0}} =
             StoreServer.request(substrate.server, {:graph_counts, [graph]})

    assert StoreServer.summary(substrate.server).dataset_revision == 1
  end

  test "concurrent transition decisions require one explicit winner without timestamp ordering",
       %{
         substrate: substrate
       } do
    repository = repository!("transition-race-repository")
    actor = repository!("transition-race-actor")
    owner_scope = scope!(:repository, "transition-race-repository")
    cause = local!(:goal, 210, 3)

    genesis =
      proposal!(repository, actor, cause, local!(:transition, 211, 4), 0, nil, nil, :proposed)

    eligible =
      proposal!(
        repository,
        actor,
        cause,
        local!(:transition, 212, 5),
        1,
        genesis.transition_iri,
        :proposed,
        :eligible
      )

    cancelled =
      proposal!(
        repository,
        actor,
        cause,
        local!(:transition, 213, 6),
        1,
        genesis.transition_iri,
        :proposed,
        :cancelled
      )

    [eligible_accepted, cancelled_accepted] =
      [
        {eligible, local!(:decision, 220, 7)},
        {cancelled, local!(:decision, 221, 8)}
      ]
      |> Task.async_stream(
        fn {proposal, decision} -> decide!(proposal, decision, actor, :accepted) end,
        ordered: true,
        timeout: :infinity
      )
      |> Enum.map(fn {:ok, decided} -> decided end)

    genesis_accepted = decide!(genesis, local!(:decision, 222, 9), actor, :accepted)

    assert {:error, %Error{kind: :conflict}} =
             Transitions.validate_chain([
               genesis_accepted.projection,
               eligible_accepted.projection,
               cancelled_accepted.projection
             ])

    cancelled_rejected =
      decide!(cancelled, local!(:decision, 223, 10), actor, :rejected)

    assert {:ok, chain} =
             Transitions.validate_chain([
               cancelled_rejected.projection,
               eligible_accepted.projection,
               genesis_accepted.projection
             ])

    assert chain.current_state == :eligible
    assert chain.current_revision == 1
    assert chain.retained == [cancelled_rejected.projection]

    payload =
      genesis.quads ++
        eligible.quads ++
        cancelled.quads ++
        genesis_accepted.quads ++
        eligible_accepted.quads ++ cancelled_rejected.quads

    assert {:ok, stored} =
             Graphs.create(
               :repository_control,
               %{repository: repository},
               payload,
               attributes(owner_scope, local!(:activity, 224, 11)),
               capability: :control_writer,
               expected_dataset_revision: 1,
               writer: substrate.writer
             )

    assert stored.receipt.dataset_revision == 2
  end

  test "transform migration recovers from a stale interrupted attempt without rewriting source",
       %{
         config: config,
         substrate: substrate
       } do
    repository = repository!("migration-recovery-repository")
    owner_scope = scope!(:repository, "migration-recovery-repository")
    batch = local!(:activity, 230, 12)
    source_artifact = local!(:claim, 231, 13)

    {:ok, source_graph} =
      GraphRegistry.graph_iri(:observation_batch, %{repository: repository, batch: batch})

    assert {:ok, source} =
             Graphs.create(
               :observation_batch,
               %{repository: repository, batch: batch},
               [triple(source_artifact, @rdf_type, iri("SourceArtifact"))],
               attributes(owner_scope, batch, immutable?: true),
               capability: :observation_writer,
               expected_dataset_revision: 1,
               writer: substrate.writer
             )

    assert source.receipt.dataset_revision == 2

    assert {:ok, %{^source_graph => source_count}} =
             StoreServer.request(substrate.server, {:graph_counts, [source_graph]})

    {:ok, target_revision} =
      ResourceIdentity.git_object(:sha1, String.duplicate("e", 40))

    target_scopes = %{repository: repository, revision: target_revision}
    {:ok, target_graph} = GraphRegistry.graph_iri(:source_revision, target_scopes)
    migration_activity = local!(:migration, 232, 14)
    actor = repository!("migration-recovery-actor")

    validation_report =
      ok!(ResourceIdentity.deterministic(:validation_report, "phase-03-migration"))

    migration_attributes = %{
      source_graph: source_graph,
      source_version: "0.9.0",
      target_version: "1.0.0",
      transformer_version: "1.0.0",
      actor: actor,
      activity: migration_activity,
      owner_scope: owner_scope,
      validation_report: validation_report,
      rollback_posture: :retain_source,
      started_at: ~U[2026-07-31 12:00:00Z],
      completed_at: ~U[2026-07-31 12:01:00Z],
      source_count: 1,
      source_revision: target_revision
    }

    transformed = [triple(source_artifact, @rdf_type, iri("SourceArtifact"))]

    assert {:ok, %{migration_required?: false}} =
             Evolution.plan("1.0.0", "1.0.0", :additive_compatible)

    assert {:ok, %{migration_required?: true}} =
             Evolution.plan("0.9.0", "1.0.0", :transform_required, %{
               transformer_version: "1.0.0",
               rollback_posture: :retain_source
             })

    assert {:error, %Error{kind: :stale_precondition}, _current_revisions} =
             Migrations.create(
               :source_revision,
               target_scopes,
               transformed,
               migration_attributes,
               capability: :source_writer,
               expected_dataset_revision: 1,
               writer: substrate.writer
             )

    assert {:ok, interrupted_counts} =
             StoreServer.request(substrate.server, {
               :graph_counts,
               [source_graph, target_graph]
             })

    assert interrupted_counts[source_graph] == source_count
    assert interrupted_counts[target_graph] == 0

    assert {:ok, migrated} =
             Migrations.create(
               :source_revision,
               target_scopes,
               transformed,
               migration_attributes,
               capability: :source_writer,
               expected_dataset_revision: 2,
               writer: substrate.writer
             )

    assert migrated.receipt.dataset_revision == 3

    assert {:ok, final_counts} =
             StoreServer.request(substrate.server, {
               :graph_counts,
               [source_graph, target_graph]
             })

    assert final_counts[source_graph] == interrupted_counts[source_graph]
    assert final_counts[target_graph] > 0

    dataset = export_dataset!(config, substrate.maintenance)

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(
               migration_activity,
               @jf <> "rollbackPosture",
               RDF.literal("retain_source"),
               target_graph
             )
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(
               migration_activity,
               @jf <> "validationReport",
               RDF.iri(validation_report),
               target_graph
             )
           )
  end

  defp proposal!(subject, actor, cause, transition, revision, predecessor, prior, next) do
    assert {:ok, proposal} =
             Transitions.proposal(%{
               transition_iri: transition,
               subject: subject,
               prior_state: prior,
               next_state: next,
               expected_predecessor: predecessor,
               revision: revision,
               actor: actor,
               cause: cause,
               reason: "phase 3 concurrent transition fixture",
               generated_at: ~U[2026-07-31 12:00:00Z],
               recorded_at: ~U[2026-07-31 12:00:00Z]
             })

    proposal
  end

  defp decide!(proposal, decision, actor, disposition) do
    assert {:ok, decided} =
             Transitions.decide(proposal, %{
               decision_iri: decision,
               authority: actor,
               disposition: disposition,
               decided_at: ~U[2026-07-31 12:00:00Z]
             })

    decided
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

  defp start_substrate!(config) do
    readiness = start_child!({Readiness, name: nil})
    writer_name = {:global, {__MODULE__, :writer, make_ref()}}
    maintenance_name = {:global, {__MODULE__, :maintenance, make_ref()}}

    server =
      start_child!(
        {StoreServer,
         name: nil,
         readiness: readiness,
         config: config,
         authorized_callers: %{
           read: [self()],
           write: [writer_name],
           maintenance: [maintenance_name]
         }}
      )

    assert await_health(server, :ready).ready?
    writer = start_child!({Writer, name: writer_name, store_server: server})
    maintenance = start_child!({Maintenance, name: maintenance_name, store_server: server})
    %{server: server, writer: writer, maintenance: maintenance}
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

  defp local!(kind, timestamp, byte),
    do: ok!(ResourceIdentity.local(kind, timestamp, :binary.copy(<<byte>>, 10)))

  defp ok!({:ok, value}), do: value
  defp triple(subject, predicate, object), do: RDF.triple(subject, predicate, object)
  defp iri(local), do: RDF.iri(@jf <> local)

  defp unique_root(context) do
    unique = System.unique_integer([:positive, :monotonic])
    name = context.test |> Atom.to_string() |> :erlang.phash2()
    Path.join(System.tmp_dir!(), "jido-code-phase-03-falsification-#{name}-#{unique}")
  end
end
