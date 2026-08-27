defmodule JidoCode.Factory.DelegatedAgentPhase02TurnsTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.DelegatedTurnController
  alias JidoCode.Runtime.JidoHarness.CodexProcessRunner
  alias JidoCode.Runtime.JidoHarness.CodexRelease
  alias JidoCode.TestSupport.FakeJidoHarnessProcessAPI
  alias JidoCode.TestSupport.Phase04Fixture

  test "reconstructs exactly one follow-up under the same fenced authority and budget" do
    controller = controller!()
    initial = manifest(controller, digest("initial"))

    assert {:ok, running, first} = DelegatedTurnController.begin(controller, initial)
    assert running.state == :running
    assert running.turn == 1
    assert first.turn == 1
    assert first.total_budget == running.total_budget

    assert {:error, %{kind: :conflict}} =
             DelegatedTurnController.respond(running, :steer, response(running, "too early"))

    assert {:ok, awaiting} =
             DelegatedTurnController.complete(running, result(running, :clarification))

    assert awaiting.state == :awaiting_actor
    assert awaiting.pending_kind == :clarification

    assert {:ok, second_running, delegated_input, second} =
             DelegatedTurnController.respond(
               awaiting,
               :answer,
               response(awaiting, "Use the existing public API")
             )

    assert second_running.state == :running
    assert second_running.turn == 2
    assert delegated_input.turn == 2
    assert delegated_input.operation == :answer
    assert delegated_input.predecessor_digest == initial.digest
    assert delegated_input.content == "Use the existing public API"
    assert second.turn == 2
    assert second.iri != first.iri
    assert second.attempt_iri == first.attempt_iri
    assert second.lease_iri == first.lease_iri
    assert second.fencing_token == first.fencing_token
    assert second.profile_digest == first.profile_digest
    assert second.workspace_identity == first.workspace_identity
    assert second.total_budget == first.total_budget
    assert Enum.map(second_running.invocations, & &1.turn) == [1, 2]

    assert {:ok, exhausted} =
             DelegatedTurnController.complete(
               second_running,
               result(second_running, :checkpoint)
             )

    assert exhausted.state == :failed
    assert exhausted.terminal_reason == :turn_exhausted

    assert {:error, %{kind: :conflict}} =
             DelegatedTurnController.respond(
               exhausted,
               :answer,
               response(exhausted, "third turn")
             )
  end

  test "accepts candidate and failure only from the current exact invocation" do
    running = begin!()

    stale = result(running, :candidate) |> Map.put(:fencing_token, 99)

    assert {:error, %{operation: :delegated_turn_result}} =
             DelegatedTurnController.complete(running, stale)

    wrong_invocation = result(running, :candidate) |> Map.put(:invocation_iri, resource("wrong"))

    assert {:error, %{operation: :delegated_turn_result}} =
             DelegatedTurnController.complete(running, wrong_invocation)

    assert {:ok, candidate} =
             DelegatedTurnController.complete(running, result(running, :candidate))

    assert candidate.state == :candidate_ready
    assert candidate.terminal_reason == :candidate

    running = begin!()
    assert {:ok, failed} = DelegatedTurnController.complete(running, result(running, :failure))
    assert failed.state == :failed
    assert failed.terminal_reason == :provider_failure
  end

  test "rejects widened, stale, and authority-bearing actor responses" do
    running = begin!()
    {:ok, awaiting} = DelegatedTurnController.complete(running, result(running, :clarification))

    for mutation <- [
          &Map.put(&1, :attempt_iri, resource("other")),
          &Map.put(&1, :fencing_token, 2),
          &Map.put(&1, :actor_iri, resource("other-actor")),
          &Map.put(&1, :profile_digest, digest("other-profile")),
          &Map.put(&1, :workspace_identity, digest("other-workspace")),
          &Map.put(&1, :content, "authorize a sandbox bypass")
        ] do
      assert {:error, %{operation: :delegated_turn_response}} =
               awaiting
               |> response("bounded answer")
               |> mutation.()
               |> then(&DelegatedTurnController.respond(awaiting, :answer, &1))
    end
  end

  test "commits cancellation before runtime and namespace termination and rejects late results" do
    running = begin!()
    owner = self()
    cancellation = cancellation(running)

    options = [
      commit: fn value ->
        send(owner, {:order, :commit, value})
        {:ok, %{outcome: :committed}}
      end,
      runtime_cancel: fn value ->
        send(owner, {:order, :runtime_cancel, value})
        {:ok, %{state: :cancelled}}
      end,
      namespace_terminate: fn value ->
        send(owner, {:order, :namespace_terminate, value})
        {:ok, %{namespace: :terminated, descendants: :absent, within_bound: true}}
      end
    ]

    assert {:ok, cancelled, receipt} =
             DelegatedTurnController.cancel(running, cancellation, options)

    assert_receive {:order, :commit, ^cancellation}
    assert_receive {:order, :runtime_cancel, ^cancellation}
    assert_receive {:order, :namespace_terminate, ^cancellation}
    assert cancelled.state == :cancelled
    assert receipt.late_results == :rejected

    assert {:error, %{kind: :conflict}} =
             DelegatedTurnController.complete(cancelled, result(running, :candidate))
  end

  test "does not start runtime cancellation when the semantic commit fails" do
    running = begin!()
    owner = self()

    options = [
      commit: fn _value -> {:error, :store_unavailable} end,
      runtime_cancel: fn _value ->
        send(owner, :runtime_cancel)
        {:ok, %{}}
      end,
      namespace_terminate: fn _value ->
        send(owner, :namespace_terminate)
        {:ok, %{}}
      end
    ]

    assert {:error, _error} =
             DelegatedTurnController.cancel(running, cancellation(running), options)

    refute_received :runtime_cancel
    refute_received :namespace_terminate
  end

  test "requires the hard two-run and two-turn budget" do
    attributes = controller_attributes()

    for budget <- [
          %{attributes.total_budget | run_count: 1},
          %{attributes.total_budget | session_turns: 3},
          %{attributes.total_budget | wall_ms: 0}
        ] do
      assert {:error, %{operation: :delegated_turn_controller}} =
               attributes |> Map.put(:total_budget, budget) |> DelegatedTurnController.new()
    end
  end

  test "launches the follow-up as a fresh Codex process in the same workspace", context do
    root =
      Path.join(
        System.tmp_dir!(),
        "jido-code-codex-turns-#{context.test}-#{System.unique_integer([:positive])}"
      )

    workspace = Path.join(root, "workspace")
    retention = Path.join(root, "retention")
    File.mkdir_p!(workspace)
    File.mkdir_p!(retention)
    on_exit(fn -> File.rm_rf!(root) end)
    {:ok, profile} = CodexRelease.runtime_profile()

    controller = controller!()
    initial = manifest(controller, digest("initial"))
    {:ok, first_running, _first} = DelegatedTurnController.begin(controller, initial)

    first_options = runner_options(retention, "proc_turn_1")

    assert {:ok, first_receipt} =
             CodexProcessRunner.start(
               profile,
               launch(workspace, "run_turn_1", "initial bounded task"),
               first_options
             )

    assert first_receipt.runtime_ref == "proc_turn_1"
    assert first_receipt.provider_session_ref == nil

    {:ok, awaiting} =
      DelegatedTurnController.complete(first_running, result(first_running, :clarification))

    {:ok, second_running, delegated_input, _second} =
      DelegatedTurnController.respond(awaiting, :answer, response(awaiting, "bounded answer"))

    second_options = runner_options(retention, "proc_turn_2")

    assert {:ok, second_receipt} =
             CodexProcessRunner.start(
               profile,
               launch(workspace, "run_turn_2", delegated_input.content),
               second_options
             )

    assert second_receipt.runtime_ref == "proc_turn_2"
    assert second_receipt.provider_session_ref == nil
    assert second_running.workspace_identity == first_running.workspace_identity
    assert second_running.fencing_token == first_running.fencing_token

    assert_received {:jido_harness_process_api, :start, first_spec}
    assert_received {:jido_harness_process_api, :start, second_spec}
    assert first_spec.cwd == workspace
    assert second_spec.cwd == workspace
    assert first_spec.metadata.run_id == "run_turn_1"
    assert second_spec.metadata.run_id == "run_turn_2"
    refute first_spec.metadata.run_id == second_spec.metadata.run_id
  end

  defp begin! do
    controller = controller!()

    {:ok, running, _invocation} =
      DelegatedTurnController.begin(controller, manifest(controller, digest("initial")))

    running
  end

  defp controller! do
    {:ok, controller} = DelegatedTurnController.new(controller_attributes())
    controller
  end

  defp controller_attributes do
    %{
      attempt_iri: resource("attempt"),
      lease_iri: resource("lease"),
      actor_iri: resource("actor"),
      fencing_token: 1,
      profile_digest: CodexRelease.profile_digest(),
      workspace_identity: digest("workspace"),
      total_budget: %{
        run_count: 2,
        session_turns: 2,
        wall_ms: 120_000,
        idle_ms: 30_000,
        output_bytes: 1_048_576
      }
    }
  end

  defp manifest(controller, digest) do
    %{
      attempt_iri: controller.attempt_iri,
      lease_iri: controller.lease_iri,
      fencing_token: controller.fencing_token,
      profile_digest: controller.profile_digest,
      workspace_identity: controller.workspace_identity,
      digest: digest
    }
  end

  defp result(controller, classification) do
    %{
      attempt_iri: controller.attempt_iri,
      lease_iri: controller.lease_iri,
      fencing_token: controller.fencing_token,
      profile_digest: controller.profile_digest,
      workspace_identity: controller.workspace_identity,
      turn: controller.turn,
      invocation_iri: List.last(controller.invocations).iri,
      classification: classification
    }
  end

  defp response(controller, content) do
    %{
      attempt_iri: controller.attempt_iri,
      lease_iri: controller.lease_iri,
      fencing_token: controller.fencing_token,
      actor_iri: controller.actor_iri,
      profile_digest: controller.profile_digest,
      workspace_identity: controller.workspace_identity,
      content: content
    }
  end

  defp cancellation(controller) do
    %{
      attempt_iri: controller.attempt_iri,
      lease_iri: controller.lease_iri,
      fencing_token: controller.fencing_token,
      actor_iri: controller.actor_iri,
      reason: :cancelled
    }
  end

  defp launch(workspace, run_id, prompt) do
    %{
      deployment_class: :developer_local,
      explicit_opt_in: true,
      managed_eligible: false,
      prompt: prompt,
      run_id: run_id,
      workspace_path: workspace,
      executable: "/opt/jido-code/codex/0.144.6/bin/codex",
      executable_digest: "sha256:" <> CodexRelease.executable_sha256(),
      environment: %{
        "PATH" => "/usr/bin",
        "HOME" => "/runtime/home",
        "TMPDIR" => "/runtime/tmp"
      },
      limits: %{wall_ms: 60_000, idle_ms: 30_000},
      cli_version: CodexRelease.cli_version(),
      provider_version: CodexRelease.model(),
      context_digest: digest("context-#{run_id}"),
      occurred_at: ~U[2026-08-26 14:30:00Z],
      credential_attachment_digest: String.duplicate("b", 64)
    }
  end

  defp runner_options(retention, process_id) do
    [
      retention_base: retention,
      process_api: FakeJidoHarnessProcessAPI,
      process_api_options: [owner: self(), start_result: {:ok, process_id}]
    ]
  end

  defp resource(seed), do: Phase04Fixture.resource!("dca-phase-02-#{seed}")
  defp digest(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
