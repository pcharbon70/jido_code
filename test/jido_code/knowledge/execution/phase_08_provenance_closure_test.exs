defmodule JidoCode.Knowledge.Execution.Phase08ProvenanceClosureTest do
  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase08AttemptFixture

  setup context do
    fixture =
      context
      |> Phase08AttemptFixture.started!()
      |> Phase08AttemptFixture.transition!(:running, 921)
      |> Phase08AttemptFixture.transition!(:completed, 922)

    {:ok, fixture: fixture}
  end

  test "closes complete terminal provenance atomically and rejects later append", %{
    fixture: fixture
  } do
    attributes = finalization_attributes(fixture, :complete, [])

    assert {:ok, command} =
             Knowledge.finalize_execution_run(
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed, inspect(receipt)
    assert {:ok, replay} = Writer.execute(fixture.writer, command)
    assert replay.outcome == :already_committed

    assert {:ok, metadata} =
             StoreServer.request(
               fixture.store_server,
               {:graph_metadata, fixture.attempt.run_graph_iri}
             )

    assert metadata.lifecycle_state == :closed
    assert metadata.completeness_state == :complete
    assert DateTime.compare(metadata.closed_at, attributes.recorded_at) == :eq

    assert {:ok, artifact} =
             Knowledge.execution_artifact(%{
               kind: :patch,
               base_snapshot_iri: fixture.attempt.snapshot_iri,
               generator_iri: fixture.attempt.iri,
               media_type: "text/x-diff",
               content: "+late = true\n",
               content_digest: nil,
               byte_count: nil,
               sensitivity: :internal,
               external_uri: nil,
               affected_paths: ["config/config.exs"],
               affected_symbols: [],
               proposed_commit_iri: nil,
               proposed_tree_iri: nil,
               findings: []
             })

    late_attributes =
      fixture
      |> command_attributes(941, "late artifact")
      |> Map.put(:expected_run_revision, metadata.graph_revision)

    assert {:ok, late_command} =
             Knowledge.record_execution_artifact(
               artifact,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               late_attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, rejected} = Writer.execute(fixture.writer, late_command)
    assert rejected.outcome == :conflicted
  end

  test "requires every declared event and rejects false completeness", %{fixture: fixture} do
    missing = JidoCode.TestSupport.Phase04Fixture.resource!("phase-08-missing-event")

    attributes =
      fixture
      |> finalization_attributes(:complete, [])
      |> Map.put(:required_event_iris, [missing])

    assert {:ok, command} =
             Knowledge.finalize_execution_run(
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, rejected} = Writer.execute(fixture.writer, command)
    assert rejected.outcome == :conflicted

    assert {:error, %{operation: :finalize_execution_run}} =
             Knowledge.finalize_execution_run(
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               %{finalization_attributes(fixture, :complete, []) | missing_outputs: ["patch"]},
               clock: fn -> fixture.issued_at end
             )
  end

  test "captures bounded sandbox activity without exposing private handles", %{fixture: fixture} do
    activity = %{
      sequence: 1,
      operation: :destroy,
      outcome: :success,
      occurred_at: DateTime.add(fixture.issued_at, 140, :second),
      provider_ref: String.duplicate("a", 64),
      details: %{status: :destroyed}
    }

    attributes =
      fixture
      |> finalization_attributes(:complete, [])
      |> Map.put(:sandbox_activities, [activity])

    assert {:ok, command} =
             Knowledge.finalize_execution_run(
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               attributes,
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, receipt} = Writer.execute(fixture.writer, command)
    assert receipt.outcome == :committed, inspect(receipt)
    refute inspect(command) =~ "handle"
    refute inspect(command) =~ "/tmp/"
  end

  defp finalization_attributes(fixture, completeness, missing_outputs) do
    fixture
    |> command_attributes(940, "finalize immutable run provenance")
    |> Map.merge(%{
      completeness: completeness,
      lease_mode: :current,
      terminal_sequence: fixture.attempt_resolution.current_revision,
      tool_invocation_iris: [],
      artifact_iris: [],
      required_event_iris: [],
      sandbox_activities: [],
      missing_outputs: missing_outputs,
      limitations: ["runtime completion is not verification evidence"],
      usage: %{cpu_ms: 10, memory_bytes: 4_096, output_bytes: 0},
      diagnostic: nil,
      cancellation_iri: nil,
      run_metadata: run_metadata!(fixture)
    })
  end

  defp command_attributes(fixture, sequence, reason) do
    fixture
    |> Phase07Fixture.base_attributes(
      sequence,
      fixture.attempt_resolution.current_transition,
      reason
    )
    |> Map.merge(%{
      fencing_token: fixture.attempt.fencing_token,
      expected_run_revision:
        Phase08AttemptFixture.graph_revision!(fixture, fixture.attempt.run_graph_iri),
      control_graph_iri: fixture.control_graph,
      expected_control_revision:
        Phase08AttemptFixture.graph_revision!(fixture, fixture.control_graph),
      recorded_at: DateTime.add(fixture.issued_at, 140, :second)
    })
  end

  defp run_metadata!(fixture) do
    {:ok, metadata} =
      StoreServer.request(
        fixture.store_server,
        {:graph_metadata, fixture.attempt.run_graph_iri}
      )

    metadata
  end
end
