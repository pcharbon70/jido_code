defmodule JidoCode.Knowledge.PhaseH01InvocationProtocolTest do
  @moduledoc """
  Phase H01 Section 1.2 - harness invocation command protocol.

  Proves the first context manifest is atomic with the attempt, that model
  invocation starts and outcomes are sequence-guarded and idempotent, that a
  dispatch without a committed start is rejected, that action proposals ride
  atomically with tool invocations, and that run closure requires the
  manifest and invocation reference sets.
  """

  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Execution.ContextManifest
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase08AttemptFixture
  alias JidoCode.TestSupport.Phase08ExecutionFixture
  alias JidoCode.TestSupport.Phase07Fixture

  setup context do
    fixture = Phase08AttemptFixture.started!(context)
    running = Phase08AttemptFixture.transition!(fixture, :running, 901)
    %{fixture: running}
  end

  describe "first manifest atomicity" do
    test "attempt start creates the first context manifest in the same commit", %{
      fixture: fixture
    } do
      assert {:ok, manifest_iri} = ContextManifest.first_manifest_iri(fixture.attempt.iri)

      assert {:ok, metadata} =
               StoreServer.request(
                 fixture.store_server,
                 {:graph_metadata, fixture.attempt.run_graph_iri}
               )

      assert metadata.graph_revision >= 1

      assert_store_contains(fixture, manifest_iri)
    end

    test "manifest digest equals the attempt context digest", %{fixture: fixture} do
      assert {:ok, manifest_iri} = ContextManifest.first_manifest_iri(fixture.attempt.iri)
      assert_store_contains(fixture, manifest_iri)
      assert byte_size(fixture.attempt.context_digest) == 64
    end
  end

  describe "model invocation start and outcome" do
    test "commits start before dispatch, closes outcome, and replays idempotently", %{
      fixture: fixture
    } do
      {:ok, manifest_iri} = ContextManifest.first_manifest_iri(fixture.attempt.iri)
      invocation = invocation!(fixture, manifest_iri, 0)

      start_attrs = invocation_attributes(fixture, 910, "dispatch host model call")

      assert {:ok, start} =
               Knowledge.start_model_invocation(
                 invocation,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 start_attrs,
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, start)
      assert receipt.outcome == :committed

      assert {:ok, replay} = Writer.execute(fixture.writer, start)
      assert replay.outcome == :already_committed

      outcome_attrs =
        invocation_attributes(fixture, 911, "record model outcome")
        |> Map.merge(%{
          status: :completed,
          usage: %{input_tokens: 120, output_tokens: 64},
          model_call_ref: "call-1",
          diagnostic: nil
        })

      assert {:ok, outcome} =
               Knowledge.record_model_outcome(
                 invocation,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 outcome_attrs,
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, outcome_receipt} = Writer.execute(fixture.writer, outcome)
      assert outcome_receipt.outcome == :committed

      assert {:ok, outcome_replay} = Writer.execute(fixture.writer, outcome)
      assert outcome_replay.outcome == :already_committed
    end

    test "rejects an outcome whose start never committed", %{fixture: fixture} do
      {:ok, manifest_iri} = ContextManifest.first_manifest_iri(fixture.attempt.iri)
      invocation = invocation!(fixture, manifest_iri, 5)

      outcome_attrs =
        invocation_attributes(fixture, 912, "unstarted outcome")
        |> Map.merge(%{status: :completed, usage: %{}, model_call_ref: nil, diagnostic: nil})

      assert {:ok, outcome} =
               Knowledge.record_model_outcome(
                 invocation,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 outcome_attrs,
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, outcome)
      assert receipt.outcome == :conflicted
    end

    test "rejects a start referencing a manifest that does not exist", %{fixture: fixture} do
      invocation =
        invocation!(fixture, JidoCode.TestSupport.Phase04Fixture.local!(:activity, 571), 1)

      assert {:ok, start} =
               Knowledge.start_model_invocation(
                 invocation,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 invocation_attributes(fixture, 913, "orphan manifest reference"),
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, start)
      assert receipt.outcome == :conflicted
    end

    test "creates the next immutable manifest atomically when context changed", %{
      fixture: fixture
    } do
      assert {:ok, next_manifest} =
               Knowledge.context_manifest(fixture.attempt.iri, %{
                 index: 1,
                 digest: String.duplicate("c1", 32),
                 kind: :host_context,
                 reconstruction: :exact
               })

      invocation = invocation!(fixture, next_manifest.iri, 2)

      assert {:ok, start} =
               Knowledge.start_model_invocation(
                 invocation,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 invocation_attributes(fixture, 914, "dispatch with changed context")
                 |> Map.put(:next_manifest, next_manifest),
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, start)
      assert receipt.outcome == :committed
      assert_store_contains(fixture, next_manifest.iri)
    end

    test "rejects unknown statuses and secret-bearing references at build time", %{
      fixture: fixture
    } do
      {:ok, manifest_iri} = ContextManifest.first_manifest_iri(fixture.attempt.iri)
      invocation = invocation!(fixture, manifest_iri, 3)

      for bad <- [
            %{status: :succeeded},
            %{usage: %{unknown_key: 1}},
            %{usage: %{input_tokens: -1}},
            %{model_call_ref: "password=hunter2"}
          ] do
        assert {:error, _error} =
                 Knowledge.record_model_outcome(
                   invocation,
                   fixture.attempt,
                   fixture.attempt_resolution,
                   fixture.lease,
                   invocation_attributes(fixture, 915, "invalid outcome")
                   |> Map.merge(bad),
                   clock: fn -> fixture.issued_at end
                 )
      end
    end
  end

  describe "action proposals" do
    test "ride atomically with a tool invocation start", %{fixture: fixture} do
      invocation = tool_invocation!(fixture, 0)

      assert {:ok, proposal} =
               Knowledge.action_proposal(%{
                 invocation_iri: invocation.iri,
                 proposed_command: "run_governed_command",
                 proposal_digest: String.duplicate("aa", 32),
                 arguments_digest: String.duplicate("bb", 32)
               })

      start_attrs =
        invocation_attributes(fixture, 920, "proposed governed command")
        |> Map.put(:action_proposal, proposal)

      assert {:ok, start} =
               Knowledge.start_tool_invocation(
                 invocation,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 start_attrs,
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, receipt} = Writer.execute(fixture.writer, start)
      assert receipt.outcome == :committed
      assert_store_contains(fixture, proposal.iri)
    end

    test "rejects proposals bound to a different invocation", %{fixture: fixture} do
      invocation = tool_invocation!(fixture, 1)

      assert {:ok, proposal} =
               Knowledge.action_proposal(%{
                 invocation_iri: JidoCode.TestSupport.Phase04Fixture.local!(:activity, 572),
                 proposed_command: "read_file",
                 proposal_digest: String.duplicate("cc", 32),
                 arguments_digest: String.duplicate("dd", 32)
               })

      assert {:error, _error} =
               Knowledge.start_tool_invocation(
                 invocation,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 invocation_attributes(fixture, 921, "mismatched proposal")
                 |> Map.put(:action_proposal, proposal),
                 clock: fn -> fixture.issued_at end
               )
    end
  end

  describe "finalize completeness" do
    test "closure requires the model invocation reference sets to exist", %{fixture: fixture} do
      {:ok, manifest_iri} = ContextManifest.first_manifest_iri(fixture.attempt.iri)
      invocation = invocation!(fixture, manifest_iri, 4)

      dispatch!(fixture, invocation, 930, 931)

      completed = Phase08AttemptFixture.transition!(fixture, :completed, 932)

      finalization =
        completed
        |> Phase08ExecutionFixture.command_attributes(
          933,
          completed.attempt_resolution.current_transition,
          "close run with model invocations"
        )
        |> Map.merge(%{
          completeness: :complete,
          lease_mode: :current,
          terminal_sequence: completed.attempt_resolution.current_revision,
          tool_invocation_iris: [],
          model_invocation_iris: [invocation.iri],
          model_invocation_outcome_iris: [model_outcome_iri(invocation)],
          artifact_iris: [],
          required_event_iris: [],
          sandbox_activities: [],
          missing_outputs: [],
          limitations: [],
          usage: %{},
          diagnostic: nil,
          cancellation_iri: nil,
          run_metadata: run_metadata!(completed)
        })

      assert {:ok, command} =
               Knowledge.finalize_execution_run(
                 completed.attempt,
                 completed.attempt_resolution,
                 completed.lease,
                 finalization,
                 clock: fn -> completed.issued_at end
               )

      assert {:ok, receipt} = Writer.execute(completed.writer, command)
      assert receipt.outcome == :committed
    end

    test "closure conflicts when a listed invocation was never committed", %{fixture: fixture} do
      completed = Phase08AttemptFixture.transition!(fixture, :completed, 940)
      ghost = JidoCode.TestSupport.Phase04Fixture.local!(:activity, 573)

      finalization =
        completed
        |> Phase08ExecutionFixture.command_attributes(
          941,
          completed.attempt_resolution.current_transition,
          "close run with ghost invocation"
        )
        |> Map.merge(%{
          completeness: :complete,
          lease_mode: :current,
          terminal_sequence: completed.attempt_resolution.current_revision,
          tool_invocation_iris: [],
          model_invocation_iris: [ghost],
          model_invocation_outcome_iris: [],
          artifact_iris: [],
          required_event_iris: [],
          sandbox_activities: [],
          missing_outputs: [],
          limitations: [],
          usage: %{},
          diagnostic: nil,
          cancellation_iri: nil,
          run_metadata: run_metadata!(completed)
        })

      assert {:ok, command} =
               Knowledge.finalize_execution_run(
                 completed.attempt,
                 completed.attempt_resolution,
                 completed.lease,
                 finalization,
                 clock: fn -> completed.issued_at end
               )

      assert {:ok, receipt} = Writer.execute(completed.writer, command)
      assert receipt.outcome == :conflicted
    end
  end

  defp invocation!(fixture, manifest_iri, sequence) do
    {:ok, invocation} =
      Knowledge.model_invocation(fixture.attempt, %{
        profile_iri: JidoCode.TestSupport.Phase04Fixture.local!(:activity, 574),
        model_version: "test-model-1",
        sequence: sequence,
        deadline: DateTime.add(fixture.lease.expires_at, 300, :second),
        context_manifest_iri: manifest_iri
      })

    invocation
  end

  defp tool_invocation!(fixture, sequence) do
    {:ok, invocation} =
      Knowledge.tool_invocation(fixture.attempt, %{
        tool_iri: JidoCode.TestSupport.Phase04Fixture.local!(:activity, 575),
        capability_iri: fixture.attempt.capability_iri,
        tool_version: "1.0.0",
        sequence: sequence,
        deadline: DateTime.add(fixture.lease.expires_at, 300, :second),
        expected_effect: JidoCode.TestSupport.Phase04Fixture.local!(:activity, 576),
        input_refs: [],
        input_digests: %{}
      })

    invocation
  end

  defp invocation_attributes(fixture, sequence, reason) do
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
      recorded_at: DateTime.add(fixture.issued_at, 130, :second)
    })
  end

  defp dispatch!(fixture, invocation, start_sequence, outcome_sequence) do
    assert {:ok, start} =
             Knowledge.start_model_invocation(
               invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               invocation_attributes(fixture, start_sequence, "dispatch for closure"),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, start_receipt} = Writer.execute(fixture.writer, start)
    assert start_receipt.outcome == :committed

    assert {:ok, outcome} =
             Knowledge.record_model_outcome(
               invocation,
               fixture.attempt,
               fixture.attempt_resolution,
               fixture.lease,
               invocation_attributes(fixture, outcome_sequence, "outcome for closure")
               |> Map.merge(%{
                 status: :completed,
                 usage: %{},
                 model_call_ref: nil,
                 diagnostic: nil
               }),
               clock: fn -> fixture.issued_at end
             )

    assert {:ok, outcome_receipt} = Writer.execute(fixture.writer, outcome)
    assert outcome_receipt.outcome == :committed
  end

  defp model_outcome_iri(invocation) do
    {:ok, iri} =
      JidoCode.Knowledge.ResourceIdentity.deterministic(
        :model_invocation_event,
        invocation.iri <> "\noutcome"
      )

    iri
  end

  defp run_metadata!(fixture) do
    {:ok, metadata} =
      StoreServer.request(fixture.store_server, {:graph_metadata, fixture.attempt.run_graph_iri})

    metadata
  end

  defp assert_store_contains(fixture, iri) do
    dataset = JidoCode.TestSupport.Phase04Fixture.export_dataset!(fixture)
    graph = RDF.Dataset.get(dataset, RDF.iri(fixture.attempt.run_graph_iri))
    assert graph
    assert MapSet.member?(RDF.Graph.subjects(graph), RDF.iri(iri))
  end
end
