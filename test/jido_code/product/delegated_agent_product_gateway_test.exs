defmodule JidoCode.Product.DelegatedAgentProductGatewayTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge.AuthorityContext
  alias JidoCode.Product.AgentCatalogGateway
  alias JidoCode.Product.AgentOffering
  alias JidoCode.Product.CodingSubmissionGateway
  alias JidoCode.Product.ManagedCodingAttempt
  alias JidoCode.Product.ManagedCodingControlGateway
  alias JidoCode.Product.WorkflowOutcome

  test "catalog binds trusted actor and tenant while returning only safe offerings" do
    test_pid = self()

    provider = fn authority, identity, scope ->
      send(test_pid, {:catalog_scope, authority, identity, scope})
      {:ok, [offering()]}
    end

    assert {:ok, [%AgentOffering{reference: "offering_1234567890"}]} =
             AgentCatalogGateway.list(authority(), identity(), catalog_params(),
               provider: provider,
               clock: fn -> ~U[2026-08-27 12:00:00Z] end
             )

    assert_receive {:catalog_scope, authority, identity, scope}
    assert scope.actor_iri == authority.actor_iri
    assert scope.tenant_iri == identity.factory_scope_iri
    assert scope.repository_ref == "repository_123456"
    refute Map.has_key?(scope, :graph)
  end

  test "catalog and submission reject implementation authority and sensitive values" do
    assert {:error, %AdapterError{kind: :invalid_input}} =
             AgentCatalogGateway.list(
               authority(),
               identity(),
               Map.put(catalog_params(), "adapter_module", "Unsafe.Module")
             )

    assert {:error, %AdapterError{kind: :invalid_input}} =
             CodingSubmissionGateway.submit(
               authority(),
               identity(),
               Map.put(submission_params(), "credential", "Bearer secret-value")
             )
  end

  test "submission produces one normalized semantic request with explicit consent" do
    test_pid = self()

    provider = fn authority, identity, request ->
      send(test_pid, {:submission, authority, identity, request})

      WorkflowOutcome.new(%{
        code: :admitted,
        retry: :never,
        attempt_ref: "attempt_123456789",
        state: :admitted
      })
    end

    assert {:ok, %WorkflowOutcome{code: :admitted}} =
             CodingSubmissionGateway.submit(authority(), identity(), submission_params(),
               provider: provider
             )

    assert_receive {:submission, authority, identity, request}
    assert request.actor_iri == authority.actor_iri
    assert request.tenant_iri == identity.factory_scope_iri
    assert request.foreground_consent
    assert request.billing_acknowledged
    refute Map.has_key?(request, :credential)
    refute Map.has_key?(request, :command)
  end

  test "attempt projection exposes delegated trust fields but no semantic IRIs" do
    assert {:ok, attempt} = ManagedCodingAttempt.new(attempt_graph())
    view = ManagedCodingAttempt.view(attempt)

    assert view.runtime_class == :delegated_cli
    assert view.provider == "codex"
    assert view.deployment_class == :developer_local
    assert view.readiness == :ready
    assert view.interaction_state == :awaiting_actor
    assert view.workspace == %{changed_files: 2, source: "controller"}
    assert view.verification_details == %{source: "independent", status: "pending"}

    serialized = inspect(view)
    refute serialized =~ attempt.attempt_iri
    refute serialized =~ attempt.repository_iri
    refute serialized =~ "/tmp/"
  end

  test "controls are state-aware and recovery requires an accepted classification" do
    assert {:ok, awaiting} = ManagedCodingAttempt.new(attempt_graph())
    assert ManagedCodingAttempt.control_available?(awaiting, :answer)
    assert ManagedCodingAttempt.control_available?(awaiting, :handoff)
    refute ManagedCodingAttempt.control_available?(awaiting, :recovery)

    failed = %{awaiting | state: :failed, wait_reason: nil, recovery: %{accepted: true}}
    assert ManagedCodingAttempt.control_available?(failed, :recovery)
    refute ManagedCodingAttempt.control_available?(failed, :steer)

    adapter = JidoCode.TestSupport.FakeManagedCodingAdapter

    assert {:error, %AdapterError{kind: :unauthorized}} =
             ManagedCodingControlGateway.submit(
               authority(),
               identity(),
               awaiting,
               :recovery,
               %{"confirmed" => "true", "idempotency_key" => "recovery_123456789"},
               adapter: adapter
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
      "acceptance_requirements" => ["Tests pass", "No secret exposure"],
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
      actor_iri: identity().actor_iri,
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
      workspace: %{changed_files: 2, source: "controller"},
      candidate: %{status: "assembling"},
      verification_details: %{source: "independent", status: "pending"},
      disposition_details: %{},
      recovery: %{},
      updated_at: ~U[2026-08-27 12:00:00Z]
    }
  end

  defp authority do
    {:ok, authority} =
      AuthorityContext.new(%{
        principal_iri: identity().principal_iri,
        actor_iri: identity().actor_iri,
        delegated_agent_iri: nil,
        delegation_iri: nil
      })

    authority
  end

  defp identity do
    %{
      factory_iri: "https://jido.run/id/repository-factory/default",
      factory_scope_iri: "https://jido.run/id/scope/factory/default",
      principal_iri: "https://jido.run/id/actor/local-operator",
      actor_iri: "https://jido.run/id/actor/local-operator",
      policy_boundary_iri: "https://jido.run/id/policy-boundary/default",
      policy_iris: ["https://jido.run/id/policy/default"]
    }
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
