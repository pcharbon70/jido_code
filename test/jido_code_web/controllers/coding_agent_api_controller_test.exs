defmodule JidoCodeWeb.CodingAgentApiControllerTest do
  use JidoCodeWeb.ConnCase, async: false

  alias JidoCode.Product.AgentCatalogGateway
  alias JidoCode.Product.AgentOffering
  alias JidoCode.Product.CodingSubmissionGateway
  alias JidoCode.Product.ManagedCodingAttempt
  alias JidoCode.Product.WorkflowOutcome

  setup do
    keys = [
      :agent_catalog_gateway,
      :coding_submission_gateway,
      :managed_coding_attempt_provider,
      :managed_coding_control_gateway,
      :managed_coding_product_fixture,
      :managed_coding_product_test_pid
    ]

    prior = Map.new(keys, &{&1, Application.get_env(:jido_code, &1)})
    test_pid = self()

    Application.put_env(:jido_code, :agent_catalog_gateway, fn authority, identity, params ->
      provider = fn scoped_authority, scoped_identity, scope ->
        send(test_pid, {:api_catalog, scoped_authority, scoped_identity, scope})
        {:ok, [offering()]}
      end

      AgentCatalogGateway.list(authority, identity, params, provider: provider)
    end)

    Application.put_env(:jido_code, :coding_submission_gateway, fn authority, identity, params ->
      provider = fn scoped_authority, scoped_identity, request ->
        send(test_pid, {:api_submission, scoped_authority, scoped_identity, request})

        WorkflowOutcome.new(%{
          code: :admitted,
          retry: :never,
          attempt_ref: attempt_ref(),
          state: :admitted
        })
      end

      CodingSubmissionGateway.submit(authority, identity, params, provider: provider)
    end)

    {:ok, attempt} = ManagedCodingAttempt.new(attempt_graph())

    Application.put_env(
      :jido_code,
      :managed_coding_attempt_provider,
      JidoCode.TestSupport.FakeManagedCodingAttemptProvider
    )

    Application.put_env(
      :jido_code,
      :managed_coding_control_gateway,
      JidoCode.TestSupport.FakeManagedCodingControlGateway
    )

    Application.put_env(:jido_code, :managed_coding_product_fixture, attempt)
    Application.put_env(:jido_code, :managed_coding_product_test_pid, self())

    on_exit(fn ->
      Enum.each(prior, fn
        {key, nil} -> Application.delete_env(:jido_code, key)
        {key, value} -> Application.put_env(:jido_code, key, value)
      end)
    end)

    :ok
  end

  test "requires one valid bounded bearer credential", %{conn: conn} do
    conn = get(conn, "/api/v1/agent-offerings")
    assert conn.status == 401
    assert json_response(conn, 401)["outcome"] == "unauthorized"

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer wrong-token")
      |> get("/api/v1/agent-offerings")

    assert conn.status == 401
    refute inspect(conn.assigns) =~ "wrong-token"
  end

  test "catalog and submission share the trusted product identity", %{conn: conn} do
    conn =
      conn
      |> authenticate()
      |> get("/api/v1/agent-offerings", catalog_params())

    assert %{"outcome" => "admitted", "offerings" => [offering]} = json_response(conn, 200)
    assert offering["runtime_class"] == "delegated_cli"
    assert_receive {:api_catalog, authority, identity, params}
    assert authority.actor_iri == identity.actor_iri
    assert params.actor_iri == authority.actor_iri

    conn =
      build_conn()
      |> authenticate()
      |> post("/api/v1/coding-attempts", submission_params())

    assert %{"code" => "admitted", "attempt_ref" => ref} = json_response(conn, 202)
    assert ref == attempt_ref()
    assert_receive {:api_submission, authority, identity, params}
    assert authority.actor_iri == identity.actor_iri
    refute Map.has_key?(params, :credential)
  end

  test "detail, refresh, and state-bound control return one redacted representation", %{
    conn: conn
  } do
    conn =
      conn
      |> authenticate()
      |> get("/api/v1/coding-attempts/#{attempt_ref()}")

    body = json_response(conn, 200)
    assert body["attempt"]["provider"] == "codex"
    assert body["attempt"]["runtime_class"] == "delegated_cli"
    refute inspect(body) =~ iri("attempt")
    assert_receive {:managed_attempt_load, _, _, _}

    conn =
      build_conn()
      |> authenticate()
      |> post("/api/v1/coding-attempts/#{attempt_ref()}/refresh")

    assert json_response(conn, 200)["outcome"] == "admitted"
    assert_receive {:managed_attempt_load, _, _, _}

    conn =
      build_conn()
      |> authenticate()
      |> post("/api/v1/coding-attempts/#{attempt_ref()}/controls/handoff", %{
        "idempotency_key" => "handoff_123456789"
      })

    assert %{"outcome" => "admitted", "control" => "handoff"} = json_response(conn, 200)
    assert_receive {:managed_attempt_load, _, _, _}
    assert_receive {:managed_control, _, _, _, :handoff, params, []}
    assert params["idempotency_key"] == "handoff_123456789"
  end

  test "unknown controls and forbidden submission fields fail with stable codes", %{conn: conn} do
    conn =
      conn
      |> authenticate()
      |> post("/api/v1/coding-attempts/#{attempt_ref()}/controls/merge", %{})

    assert json_response(conn, 422)["outcome"] == "rejected"

    conn =
      build_conn()
      |> authenticate()
      |> post(
        "/api/v1/coding-attempts",
        Map.put(submission_params(), "executable", "/usr/local/bin/codex")
      )

    assert json_response(conn, 422)["outcome"] == "rejected"
    refute_receive {:api_submission, _, _, _}
  end

  defp authenticate(conn),
    do: put_req_header(conn, "authorization", "Bearer test-operator-token")

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

  defp attempt_ref do
    JidoCode.Product.ManagedCodingAttempt.presentation_ref(iri("attempt"))
  end

  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
