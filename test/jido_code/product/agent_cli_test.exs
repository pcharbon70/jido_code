defmodule JidoCode.Product.AgentCLITest do
  use ExUnit.Case, async: false

  alias JidoCode.Product.AgentCLI
  alias JidoCode.Product.AgentOffering
  alias JidoCode.Product.ManagedCodingAttempt
  alias JidoCode.Product.WorkflowOutcome

  setup do
    prior_fixture = Application.get_env(:jido_code, :managed_coding_product_fixture)
    prior_pid = Application.get_env(:jido_code, :managed_coding_product_test_pid)
    {:ok, attempt} = ManagedCodingAttempt.new(attempt_graph())

    Application.put_env(:jido_code, :managed_coding_product_fixture, attempt)
    Application.put_env(:jido_code, :managed_coding_product_test_pid, self())

    on_exit(fn ->
      restore_env(:managed_coding_product_fixture, prior_fixture)
      restore_env(:managed_coding_product_test_pid, prior_pid)
    end)

    %{attempt: attempt}
  end

  test "catalog and submission reuse authenticated product authority" do
    test_pid = self()

    catalog = fn authority, identity, request ->
      send(test_pid, {:cli_catalog, authority, identity, request})
      {:ok, [offering()]}
    end

    assert {:ok, %{outcome: "admitted", offerings: [result]}} =
             AgentCLI.execute("catalog", catalog_params(), credential(), catalog_gateway: catalog)

    assert result.reference == offering().reference
    assert_receive {:cli_catalog, authority, identity, request}
    assert authority.actor_iri == identity.actor_iri
    assert request["repository_ref"] == "repository_123456"

    submission = fn authority, identity, request ->
      send(test_pid, {:cli_submission, authority, identity, request})

      WorkflowOutcome.new(%{
        code: :admitted,
        retry: :never,
        attempt_ref: "attempt_123456789",
        state: :admitted
      })
    end

    assert {:ok, %{code: :admitted, attempt_ref: "attempt_123456789"}} =
             AgentCLI.execute("submit", submission_params(), credential(),
               submission_gateway: submission
             )

    assert_receive {:cli_submission, authority, identity, request}
    assert authority.actor_iri == identity.actor_iri
    assert request["intent"] == "Implement the accepted coding task"
  end

  test "show and finite controls use the same safe attempt projection", %{attempt: attempt} do
    options = [
      attempt_provider: JidoCode.TestSupport.FakeManagedCodingAttemptProvider,
      control_gateway: JidoCode.TestSupport.FakeManagedCodingControlGateway
    ]

    assert {:ok, %{outcome: "admitted", attempt: view}} =
             AgentCLI.execute(
               "show",
               %{"attempt_ref" => attempt.presentation_ref},
               credential(),
               options
             )

    assert view.provider == "codex"
    refute inspect(view) =~ attempt.attempt_iri
    assert_receive {:managed_attempt_load, _, _, reference}
    assert reference == attempt.presentation_ref

    assert {:ok, %{outcome: "admitted", control: "handoff"}} =
             AgentCLI.execute(
               "handoff",
               %{
                 "attempt_ref" => attempt.presentation_ref,
                 "idempotency_key" => "handoff_123456789"
               },
               credential(),
               options
             )

    assert_receive {:managed_attempt_load, _, _, _}
    assert_receive {:managed_control, _, _, _, :handoff, params, []}
    assert params == %{"idempotency_key" => "handoff_123456789"}
  end

  test "rejects unauthenticated, unknown, and implementation-authority input" do
    rejecting_gateway = fn _authority, _identity, _request ->
      flunk("rejected input reached the product gateway")
    end

    assert {:error, %{outcome: "unauthorized"}} =
             AgentCLI.execute("catalog", catalog_params(), "wrong-token",
               catalog_gateway: rejecting_gateway
             )

    assert {:error, %{outcome: "rejected"}} =
             AgentCLI.execute(
               "submit",
               Map.put(submission_params(), "executable", "/usr/local/bin/codex"),
               credential(),
               submission_gateway: rejecting_gateway
             )

    assert {:error, %{outcome: "rejected"}} =
             AgentCLI.execute(
               "show",
               %{"attempt_ref" => "attempt_123456789", "credential" => "secret"},
               credential()
             )
  end

  defp catalog_params do
    %{
      "repository_ref" => "repository_123456",
      "snapshot_ref" => "snapshot_12345678",
      "task_class" => "focused_change",
      "language_class" => "elixir_phoenix",
      "capability_class" => "workspace_write_registered_checks",
      "rollout_stage" => "evaluation"
    }
  end

  defp submission_params do
    %{
      "intent" => "Implement the accepted coding task",
      "repository_ref" => "repository_123456",
      "snapshot_ref" => "snapshot_12345678",
      "task_class" => "focused_change",
      "acceptance_requirements" => ["Tests pass"],
      "offering_ref" => "offering_1234567890",
      "idempotency_key" => "submission_123456789",
      "foreground_consent" => true,
      "billing_acknowledged" => true
    }
  end

  defp offering do
    %AgentOffering{
      reference: "offering_1234567890",
      display_name: "Codex developer local",
      description: "Protected delegated coding agent",
      runtime_class: :delegated_cli,
      provider: :codex,
      deployment_class: :developer_local,
      authentication_kind: :existing_cli_session,
      billing_mode: :subscription,
      capability_class: :workspace_write_registered_checks,
      capability_summary: "Workspace writes and registered checks",
      task_classes: ["focused_change"],
      language_classes: ["elixir_phoenix"],
      readiness: :ready,
      readiness_age_seconds: 30,
      rollout_stage: :evaluation,
      profile_revision: 1,
      profile_digest: String.duplicate("a", 64),
      limitations: [:no_publication, :no_merge],
      selectable: true
    }
  end

  defp attempt_graph do
    %{
      attempt_iri: iri("attempt"),
      repository_iri: iri("repository"),
      task_iri: iri("task"),
      profile_iri: iri("profile"),
      capability_iri: iri("capability"),
      actor_iri: "https://jido.run/id/actor/local-operator",
      fencing_token: 7,
      sequence: 9,
      task_label: "Harden candidate closure",
      state: :awaiting_actor,
      wait_reason: :actor,
      budgets: %{turns: %{used: 3, limit: 10}},
      interactions: [%{kind: :clarification, label: "Clarification requested", status: :waiting}],
      tools: [%{kind: :mutation, label: "Edit source", status: :completed}],
      checks: [%{kind: :compilation, label: "Compile", status: :passed}],
      candidate_iri: iri("candidate"),
      verification: :pending,
      disposition: nil,
      evidence_iris: [iri("evidence")],
      runtime_class: :delegated_cli,
      profile_label: "Codex developer local",
      provider: :codex,
      deployment_class: :developer_local,
      billing_mode: :subscription,
      readiness: :ready,
      readiness_age_seconds: 30,
      rollout_stage: :evaluation,
      repository_envelope: "jido_code only",
      limitations: [:no_publication, :no_merge],
      interaction_state: :awaiting_actor,
      workspace: %{changed_files: 2},
      candidate: %{status: "ready"},
      verification_details: %{source: "independent"},
      disposition_details: %{},
      recovery: %{},
      updated_at: ~U[2026-08-27 12:00:00Z]
    }
  end

  defp credential, do: "test-operator-token"
  defp restore_env(key, nil), do: Application.delete_env(:jido_code, key)
  defp restore_env(key, value), do: Application.put_env(:jido_code, key, value)
  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
