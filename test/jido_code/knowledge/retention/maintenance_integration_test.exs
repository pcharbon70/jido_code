defmodule JidoCode.Knowledge.Retention.MaintenanceIntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge.Admin
  alias JidoCode.Knowledge.Maintenance
  alias JidoCode.Knowledge.Retention.Planner
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.TestSupport.Phase04Fixture

  setup context do
    fixture =
      context
      |> Phase04Fixture.start!()
      |> Phase04Fixture.bootstrap!()
      |> Phase04Fixture.enroll!()
      |> Phase04Fixture.assert_outcome!()
      |> Phase04Fixture.observe!()

    {:ok, fixture: fixture}
  end

  test "checkpointed maintenance atomically removes exact statements and records audit", %{
    fixture: fixture
  } do
    dataset = Phase04Fixture.export_dataset!(fixture)

    removable =
      dataset
      |> RDF.Dataset.quads()
      |> Enum.filter(fn
        {%RDF.IRI{value: subject}, _, _, %RDF.IRI{value: graph}} ->
          subject == fixture.observation_batch and graph == fixture.observation_graph

        _quad ->
          false
      end)

    assert removable != []

    summary = StoreServer.summary(fixture.store_server)
    audit_graph = fixture.graphs.audit

    snapshot = %{
      resources: [
        %{
          iri: fixture.observation_batch,
          graph_iri: fixture.observation_graph,
          family: :observation_batch,
          age_days: 100,
          links: [],
          quads: removable
        }
      ],
      roots: [],
      legal_holds: [],
      legal_erase: [fixture.observation_batch],
      dataset_revision: summary.dataset_revision,
      graph_revisions: %{
        fixture.observation_graph =>
          Phase04Fixture.current_graph_revision!(fixture, fixture.observation_graph),
        audit_graph => Phase04Fixture.current_graph_revision!(fixture, audit_graph)
      },
      actor_iri: fixture.actor,
      activity_iri: Phase04Fixture.local!(:activity, 990),
      audit_graph_iri: audit_graph,
      rationale: "Erase observation batch under accepted legal request",
      validation_report_iri: Phase04Fixture.local!(:activity, 991)
    }

    assert {:ok, plan} = Planner.plan(snapshot)

    assert {:error, confirmation_error} =
             Admin.execute(:retention,
               plan: plan,
               confirm: "wrong-plan",
               maintenance: fixture.maintenance
             )

    assert confirmation_error.operation == :admin_retention

    assert {:ok, receipt} =
             Admin.execute(:retention,
               plan: plan,
               confirm: plan.id,
               maintenance: fixture.maintenance
             )

    assert receipt.integrity_status == :ok
    assert receipt.removal_count == length(removable)
    assert receipt.archived_resource_count == 0
    assert receipt.removed_resource_count == 0
    assert receipt.erased_resource_count == 1
    assert is_binary(receipt.checkpoint_artifact_id)
    assert StoreServer.summary(fixture.store_server).ready?

    assert {:error, restore_error} =
             Maintenance.restore(
               fixture.maintenance,
               receipt.checkpoint_artifact_id,
               confirm: receipt.checkpoint_artifact_id
             )

    assert restore_error.operation == :restore_retention_floor
    assert StoreServer.summary(fixture.store_server).ready?

    assert {:ok, post_retention} = Maintenance.backup(fixture.maintenance, [])

    assert {:ok, %{integrity_status: :ok}} =
             Maintenance.restore(
               fixture.maintenance,
               post_retention.artifact_id,
               confirm: post_retention.artifact_id
             )

    after_dataset = Phase04Fixture.export_dataset!(fixture)
    after_quads = RDF.Dataset.quads(after_dataset)

    refute Enum.any?(after_quads, fn
             {%RDF.IRI{value: subject}, _, _, _graph} -> subject == fixture.observation_batch
             _quad -> false
           end)

    assert Enum.any?(after_quads, fn
             {%RDF.IRI{value: subject}, _, _, %RDF.IRI{value: graph}} ->
               subject == plan.activity_iri and graph == audit_graph

             _quad ->
               false
           end)
  end
end
