defmodule JidoCode.Knowledge.Migrations.WorkflowTest do
  use ExUnit.Case, async: true

  alias JidoCode.Knowledge.BackupReceipt
  alias JidoCode.Knowledge.IntegrityReport
  alias JidoCode.Knowledge.Migrations.Workflow
  alias JidoCode.ReleaseContract

  test "orders changed contracts and requires rollback, integrity, space, and maintenance" do
    target = ReleaseContract.manifest()

    current =
      target
      |> Map.put(:application, "0.0.9")
      |> Map.put(:ontology, "0.9.0")
      |> Map.put(:shapes, "0.9.0")
      |> Map.put(:reasoning_digest, String.duplicate("a", 64))
      |> Map.put(:backend_schema, 1)

    assert {:ok, plan} = Workflow.plan(current, target, estimated_bytes: 1_000)

    assert plan.steps == [
             :application,
             :ontology,
             :shapes,
             :reasoning,
             :backend_schema,
             :graphs,
             :derived_rebuild,
             :acceptance
           ]

    assert plan.destructive?
    assert plan.execution_mode == :maintenance

    evidence = %{
      integrity: integrity(),
      backup: backup(),
      free_bytes: 2_000,
      maintenance_available?: true
    }

    assert {:ok, preflight} = Workflow.preflight(plan, evidence)
    assert preflight.rollback_artifact == backup().artifact_id

    assert {:error, _error} = Workflow.preflight(plan, %{evidence | backup: nil})
    assert {:error, _error} = Workflow.preflight(plan, %{evidence | free_bytes: 1_999})

    assert {:error, _error} =
             Workflow.preflight(plan, %{evidence | maintenance_available?: false})
  end

  test "executes sequentially and stops at the first failed graph-owned step" do
    target = ReleaseContract.manifest()
    current = Map.put(target, :query_catalog, "1.6.0")
    {:ok, plan} = Workflow.plan(current, target)
    parent = self()

    runner = fn step ->
      send(parent, {:step, step})
      {:ok, %{graph_receipt: step}}
    end

    assert {:ok, receipt} = Workflow.execute(plan, runner)
    assert receipt.state == :complete
    assert receipt.completed_steps == [:query_catalog, :acceptance]
    assert_receive {:step, :query_catalog}
    assert_receive {:step, :acceptance}

    failed = fn
      :query_catalog -> {:error, JidoCode.Knowledge.Error.new(:conflict, :migration)}
      _step -> flunk("later migration step must not execute")
    end

    assert {:error, error} = Workflow.execute(plan, failed)
    assert error.kind == :conflict
  end

  defp integrity do
    %IntegrityReport{
      status: :ok,
      dataset_revision: 10,
      graph_count: 4,
      quad_count: 100,
      issues: []
    }
  end

  defp backup do
    %BackupReceipt{
      artifact_id: "backup-20260804T120000Z-abcdef123456",
      artifact_kind: :checkpoint,
      created_at: "2026-08-04T12:00:00Z",
      dataset_revision: 10,
      graph_count: 4,
      quad_count: 100,
      payload_sha256: String.duplicate("a", 64),
      payload_bytes: 1_000,
      consistency: "exclusive_store_owner"
    }
  end
end
