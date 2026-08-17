defmodule JidoCode.Knowledge.PhaseH01HarnessContractIntegrationTest do
  @moduledoc """
  Phase H01 Section 1.5 - harness contract integration gates.

  Exercises one complete harness-contract flow against a real store:
  access-profile enrollment, harness-profile adoption, tool definition
  publication, atomic attempt-with-manifest creation, sequenced model
  invocations, proposal-bearing tool effects, and run closure with complete
  reference sets - plus the incomplete-run closure path and closed-graph
  immutability.
  """

  use ExUnit.Case, async: false

  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.Execution.ContextManifest
  alias JidoCode.Knowledge.StoreServer
  alias JidoCode.Knowledge.Writer
  alias JidoCode.TestSupport.Phase04Fixture
  alias JidoCode.TestSupport.Phase07Fixture
  alias JidoCode.TestSupport.Phase08AttemptFixture
  alias JidoCode.TestSupport.Phase08ExecutionFixture

  setup context do
    fixture = Phase08AttemptFixture.started!(context)
    running = Phase08AttemptFixture.transition!(fixture, :running, 970)
    %{fixture: running}
  end

  describe "complete harness contract flow" do
    test "enrolls profiles, dispatches invocations, and closes the run", %{fixture: fixture} do
      # 1. Enroll a model access profile in the factory policy graph.
      assert {:ok, access} =
               Knowledge.model_access_profile(%{
                 owner_iri: fixture.actor,
                 scope_iri: fixture.factory_scope,
                 access_mode: :host_api,
                 credential_reference_iri: Phase04Fixture.local!(:activity, 60),
                 credential_class: :static_reusable,
                 billing_mode: :metered_api,
                 provider: "openai",
                 model: "gpt-test",
                 endpoint: "https://api.example.test/v1",
                 readiness: [:installed, :credential_available, :authenticated],
                 revocation_generation: 1
               })

      assert {:ok, enroll} =
               Knowledge.enroll_model_access_profile(
                 access,
                 policy_attributes(fixture),
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, enroll_receipt} = Writer.execute(fixture.writer, enroll)
      assert enroll_receipt.outcome == :committed

      # 2. Pin a harness profile to the enrolled access profile.
      assert {:ok, harness} =
               Knowledge.harness_profile(%{
                 name: "harness-integration",
                 version: "1.0.0",
                 owner_iri: fixture.actor,
                 scope_iri: fixture.factory_scope,
                 model_access_profile_iri: access.iri,
                 workflow_version: "workflow-1",
                 prompt_template_version: "prompt-1",
                 tool_catalog_version: "catalog-1",
                 policy_revision: "policy-1",
                 budget_profile: "budget-standard"
               })

      assert {:ok, adopt} =
               Knowledge.adopt_harness_profile(harness, policy_attributes(fixture),
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, adopt_receipt} = Writer.execute(fixture.writer, adopt)
      assert adopt_receipt.outcome == :committed

      # 3. Publish a tool definition the run may cite.
      assert {:ok, definition} =
               Knowledge.tool_definition(%{
                 tool_name: "read_file",
                 tool_version: "1.0.0",
                 input_schema_digest: "sha256:" <> String.duplicate("0a", 32),
                 output_schema_digest: "sha256:" <> String.duplicate("0b", 32),
                 effect_class: :read,
                 adapter_digest: "sha256:" <> String.duplicate("0c", 32),
                 approval_required: false,
                 timeout_ms: 30_000
               })

      assert {:ok, publish} =
               Knowledge.publish_tool_definition(definition, policy_attributes(fixture),
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, publish_receipt} = Writer.execute(fixture.writer, publish)
      assert publish_receipt.outcome == :committed

      # 4. The first manifest is atomic with the attempt (created at start).
      {:ok, manifest_iri} = ContextManifest.first_manifest_iri(fixture.attempt.iri)

      # 5. Dispatch one model invocation against the first manifest.
      assert {:ok, invocation} =
               Knowledge.model_invocation(fixture.attempt, %{
                 profile_iri: access.iri,
                 model_version: "gpt-test",
                 sequence: 0,
                 deadline: DateTime.add(fixture.lease.expires_at, 300, :second),
                 context_manifest_iri: manifest_iri
               })

      assert {:ok, start} =
               Knowledge.start_model_invocation(
                 invocation,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 invocation_attributes(fixture, 971, "dispatch integration call"),
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
                 invocation_attributes(fixture, 972, "record integration outcome")
                 |> Map.merge(%{
                   status: :completed,
                   usage: %{input_tokens: 10},
                   model_call_ref: nil,
                   diagnostic: nil
                 }),
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, outcome_receipt} = Writer.execute(fixture.writer, outcome)
      assert outcome_receipt.outcome == :committed

      # 6. Record one proposal-bearing tool invocation with its outcome.
      assert {:ok, tool} =
               Knowledge.tool_invocation(fixture.attempt, %{
                 tool_iri: Phase04Fixture.local!(:activity, 75),
                 capability_iri: fixture.attempt.capability_iri,
                 tool_version: "1.0.0",
                 sequence: 1,
                 deadline: DateTime.add(fixture.lease.expires_at, 300, :second),
                 expected_effect: Phase04Fixture.local!(:activity, 76),
                 input_refs: [],
                 input_digests: %{}
               })

      assert {:ok, proposal} =
               Knowledge.action_proposal(%{
                 invocation_iri: tool.iri,
                 proposed_command: "read_file",
                 proposal_digest: String.duplicate("aa", 32),
                 arguments_digest: String.duplicate("bb", 32)
               })

      assert {:ok, tool_start} =
               Knowledge.start_tool_invocation(
                 tool,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 invocation_attributes(fixture, 973, "proposed read")
                 |> Map.put(:action_proposal, proposal),
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, tool_start_receipt} = Writer.execute(fixture.writer, tool_start)
      assert tool_start_receipt.outcome == :committed

      assert {:ok, tool_outcome} =
               Knowledge.record_tool_outcome(
                 tool,
                 fixture.attempt,
                 fixture.attempt_resolution,
                 fixture.lease,
                 invocation_attributes(fixture, 974, "read outcome")
                 |> Map.merge(%{
                   status: :completed,
                   exit_status: 0,
                   stdout: "file contents",
                   stderr: "",
                   external_output_iris: [],
                   artifact_iris: [],
                   usage: %{},
                   redaction: :none
                 }),
                 clock: fn -> fixture.issued_at end
               )

      assert {:ok, tool_outcome_receipt} = Writer.execute(fixture.writer, tool_outcome)
      assert tool_outcome_receipt.outcome == :committed

      # 7. Close the run with the complete reference sets.
      completed = Phase08AttemptFixture.transition!(fixture, :completed, 975)

      finalization =
        completed
        |> Phase08ExecutionFixture.command_attributes(
          976,
          completed.attempt_resolution.current_transition,
          "close integration run"
        )
        |> Map.merge(%{
          completeness: :complete,
          lease_mode: :current,
          terminal_sequence: completed.attempt_resolution.current_revision,
          tool_invocation_iris: [tool.iri],
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

      assert {:ok, finalize} =
               Knowledge.finalize_execution_run(
                 completed.attempt,
                 completed.attempt_resolution,
                 completed.lease,
                 finalization,
                 clock: fn -> completed.issued_at end
               )

      assert {:ok, finalize_receipt} = Writer.execute(completed.writer, finalize)
      assert finalize_receipt.outcome == :committed

      # 8. A terminal attempt rejects further model dispatches at the builder.
      assert {:ok, late} =
               Knowledge.model_invocation(completed.attempt, %{
                 profile_iri: Phase04Fixture.local!(:activity, 74),
                 model_version: "gpt-test",
                 sequence: 5,
                 deadline: DateTime.add(completed.lease.expires_at, 300, :second),
                 context_manifest_iri: manifest_iri
               })

      assert {:error, _terminal} =
               Knowledge.start_model_invocation(
                 late,
                 completed.attempt,
                 completed.attempt_resolution,
                 completed.lease,
                 invocation_attributes(completed, 977, "late dispatch after closure"),
                 clock: fn -> completed.issued_at end
               )
    end
  end

  describe "incomplete-run closure path" do
    test "an abandoned run closes incomplete with its missing outputs", %{fixture: fixture} do
      abandoned =
        Phase08AttemptFixture.transition!(fixture, :abandoned, 978)

      finalization =
        abandoned
        |> Phase08ExecutionFixture.command_attributes(
          979,
          abandoned.attempt_resolution.current_transition,
          "close abandoned run"
        )
        |> Map.merge(%{
          completeness: :incomplete,
          lease_mode: :current,
          terminal_sequence: abandoned.attempt_resolution.current_revision,
          tool_invocation_iris: [],
          model_invocation_iris: [],
          model_invocation_outcome_iris: [],
          artifact_iris: [],
          required_event_iris: [],
          sandbox_activities: [],
          missing_outputs: ["model outcome"],
          limitations: ["abandoned before dispatch"],
          usage: %{},
          diagnostic: nil,
          cancellation_iri: nil,
          run_metadata: run_metadata!(abandoned)
        })

      assert {:ok, finalize} =
               Knowledge.finalize_execution_run(
                 abandoned.attempt,
                 abandoned.attempt_resolution,
                 abandoned.lease,
                 finalization,
                 clock: fn -> abandoned.issued_at end
               )

      assert {:ok, receipt} = Writer.execute(abandoned.writer, finalize)
      assert receipt.outcome == :committed
    end
  end

  defp policy_attributes(fixture) do
    %{
      policy_graph_iri: fixture.graphs.policy,
      expected_policy_revision:
        Phase04Fixture.current_graph_revision!(fixture, fixture.graphs.policy),
      principal_iri: fixture.actor,
      actor_iri: fixture.actor,
      scope_iri: fixture.factory_scope,
      correlation_iri: Phase04Fixture.local!(:activity, 61),
      causation_iri: fixture.bootstrap_command_iri,
      expected_dataset_revision: StoreServer.summary(fixture.store_server).dataset_revision,
      reason: "phase h01 integration"
    }
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
      recorded_at: DateTime.add(fixture.issued_at, 160, :second)
    })
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
end
