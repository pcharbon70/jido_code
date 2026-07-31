defmodule JidoCode.Knowledge.Phase04CommandIntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.CommandProvenance
  alias JidoCode.Knowledge.CommandStatus
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Vocabulary
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture

  @jf "https://jido.run/ontology/factory#"
  @rdf_type "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
  @prov_associated "http://www.w3.org/ns/prov#wasAssociatedWith"
  @prov_generated "http://www.w3.org/ns/prov#generated"
  @prov_used "http://www.w3.org/ns/prov#used"

  setup context do
    substrate = Phase04Fixture.start!(context)
    %{fixture: Phase04Fixture.bootstrap!(substrate)}
  end

  test "executes catalog, policy, control, audit, and immutable graph commands atomically", %{
    fixture: fixture
  } do
    fixture =
      fixture
      |> Phase04Fixture.enroll!()
      |> Phase04Fixture.assert_outcome!()
      |> Phase04Fixture.observe!()

    assert fixture.enrollment_receipt.outcome == :committed
    assert fixture.outcome_receipt.outcome == :committed
    assert fixture.observation_receipt.outcome == :committed
    assert StoreServer.summary(fixture.store_server).dataset_revision == 5

    assert fixture.graphs.catalog in fixture.enrollment_receipt.affected_graphs
    assert fixture.graphs.policy in fixture.outcome_receipt.affected_graphs
    assert fixture.control_graph in fixture.outcome_receipt.affected_graphs
    assert fixture.observation_graph in fixture.observation_receipt.affected_graphs
    assert fixture.graphs.audit in fixture.observation_receipt.affected_graphs

    assert Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.catalog) == 2
    assert Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.policy) == 2
    assert Phase04Fixture.current_graph_revision!(fixture, fixture.control_graph) == 1
    assert Phase04Fixture.current_graph_revision!(fixture, fixture.observation_graph) == 1
    assert Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.audit) == 4

    dataset = Phase04Fixture.export_dataset!(fixture)

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(
               fixture.repository,
               @rdf_type,
               RDF.iri(@jf <> "SoftwareRepository"),
               fixture.graphs.catalog
             )
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(
               fixture.goal,
               @rdf_type,
               RDF.iri(@jf <> "Goal"),
               fixture.control_graph
             )
           )

    observation_assertion =
      RDF.quad(
        fixture.observation_batch,
        @rdf_type,
        RDF.iri(@jf <> "ObservationBatch"),
        fixture.observation_graph
      )

    assert RDF.Dataset.include?(dataset, observation_assertion)
    assert_assertion_trace!(dataset, fixture, observation_assertion)

    rewrite =
      Phase04Fixture.envelope!(
        fixture,
        "RecordObservationBatch",
        Phase04Fixture.local!(:command, 40),
        fixture.repository_scope,
        "phase-04-immutable-rewrite",
        %{fixture.observation_graph => 1},
        [
          %{
            family: :observation_batch,
            graph_iri: fixture.observation_graph,
            operation: :create,
            metadata: %{lifecycle_state: :closed},
            additions: [
              {Phase04Fixture.local!(:activity, 41), @rdf_type,
               RDF.iri(@jf <> "ObservationBatch")}
            ],
            supersessions: [],
            invalidations: [],
            removals: []
          }
        ]
      )

    assert {:ok, rejected_rewrite} = Writer.execute(fixture.writer, rewrite)
    assert rejected_rewrite.outcome == :conflicted
    assert StoreServer.summary(fixture.store_server).dataset_revision == 5
  end

  test "backup, export, and restore preserve command audit and idempotency outcomes", %{
    fixture: fixture
  } do
    fixture =
      fixture
      |> Phase04Fixture.enroll!()
      |> Phase04Fixture.assert_outcome!()
      |> Phase04Fixture.observe!()

    before_restore = Phase04Fixture.export_dataset!(fixture)
    assert {:ok, backup} = Maintenance.backup(fixture.maintenance, [])

    assert {:ok, restored} =
             Maintenance.restore(fixture.maintenance, backup.artifact_id,
               confirm: backup.artifact_id
             )

    assert restored.dataset_revision == 6
    after_restore = Phase04Fixture.export_dataset!(fixture)

    assert RDF.Dataset.equal?(
             application_dataset(before_restore),
             application_dataset(after_restore)
           )

    assert {:ok, %CommandStatus{outcome: :committed} = status} =
             Writer.command_status(fixture.writer, fixture.observation_envelope)

    assert status.receipt_iri == fixture.observation_receipt.receipt_iri
    assert status.dataset_revision == fixture.observation_receipt.dataset_revision

    assert {:ok, replay} = Writer.execute(fixture.writer, fixture.observation_envelope)
    assert replay.outcome == :already_committed
    assert replay.dataset_revision == fixture.observation_receipt.dataset_revision
    assert StoreServer.summary(fixture.store_server).dataset_revision == 6
  end

  defp assert_assertion_trace!(dataset, fixture, assertion) do
    digest = CommandProvenance.assertion_digest(assertion)
    change_set = fixture.observation_receipt.change_set_iri
    command = fixture.observation_envelope.command_iri
    receipt = fixture.observation_receipt.receipt_iri

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(change_set, @jf <> "assertionDigest", digest, fixture.graphs.audit)
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(command, @prov_generated, RDF.iri(change_set), fixture.graphs.audit)
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(command, @prov_generated, RDF.iri(receipt), fixture.graphs.audit)
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(command, @prov_associated, RDF.iri(fixture.actor), fixture.graphs.audit)
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(
               command,
               @jf <> "cause",
               RDF.iri(fixture.observation_envelope.causation_iri),
               fixture.graphs.audit
             )
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(change_set, @jf <> "shapeVersion", "1.0.0", fixture.graphs.audit)
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(change_set, @jf <> "validatorVersion", "1.0.0", fixture.graphs.audit)
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(
               change_set,
               @jf <> "ontologyVersion",
               RDF.iri("https://jido.run/ontology/release/1.0.0"),
               fixture.graphs.audit
             )
           )

    {:ok, identities} = CommandProvenance.identities(fixture.observation_envelope)

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(command, @prov_used, RDF.iri(identities.request_iri), fixture.graphs.audit)
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(
               receipt,
               @jf <> "commitIdentity",
               RDF.iri(identities.commit_id),
               fixture.graphs.audit
             )
           )

    assert RDF.Dataset.include?(
             dataset,
             RDF.quad(
               identities.commit_id,
               Vocabulary.predicate(:command_iri),
               RDF.iri(command),
               Vocabulary.system_graph()
             )
           )

    assert Enum.any?(RDF.Dataset.quads(dataset), fn
             {%RDF.IRI{value: audit}, %RDF.IRI{value: @jf <> "authorizationGrant"}, %RDF.IRI{},
              %RDF.IRI{value: graph}} ->
               audit == command <> "/audit" and graph == fixture.graphs.audit

             _other ->
               false
           end)
  end

  defp application_dataset(dataset) do
    dataset
    |> RDF.Dataset.named_graphs()
    |> Enum.reject(&(RDF.IRI.to_string(&1.name) == Vocabulary.system_graph()))
    |> Enum.reduce(RDF.Dataset.new(), &RDF.Dataset.add(&2, &1))
  end
end
