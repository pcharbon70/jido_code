defmodule JidoCode.Product.DelegatedAgentPhase05IntegrationTest do
  use JidoCodeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias JidoCode.Product
  alias JidoCode.Product.AgentCLI
  alias JidoCode.Product.AgentCatalogGateway
  alias JidoCode.Product.AgentOffering
  alias JidoCode.Product.CodingSubmissionGateway
  alias JidoCode.Product.ManagedCodingAttempt
  alias JidoCode.Product.WorkflowOutcome

  @credential "test-operator-token"

  setup %{conn: conn} do
    keys = [
      :agent_catalog_gateway,
      :coding_submission_gateway,
      :managed_coding_attempt_provider,
      :managed_coding_control_gateway,
      :managed_coding_adapter,
      :managed_coding_product_fixture,
      :managed_coding_product_test_pid
    ]

    prior = Map.new(keys, &{&1, Application.get_env(:jido_code, &1)})
    test_pid = self()

    Application.put_env(:jido_code, :agent_catalog_gateway, fn authority, identity, params ->
      provider = fn scoped_authority, scoped_identity, scope ->
        send(test_pid, {:phase_05_catalog, scoped_authority, scoped_identity, scope})
        {:ok, offerings()}
      end

      AgentCatalogGateway.list(authority, identity, params,
        provider: provider,
        clock: fn -> ~U[2026-08-27 14:00:00Z] end
      )
    end)

    Application.put_env(:jido_code, :coding_submission_gateway, fn authority, identity, params ->
      provider = fn scoped_authority, scoped_identity, request ->
        send(test_pid, {:phase_05_submission, scoped_authority, scoped_identity, request})
        submission_outcome(request)
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
      JidoCode.Product.ManagedCodingControlGateway
    )

    Application.put_env(
      :jido_code,
      :managed_coding_adapter,
      JidoCode.TestSupport.FakeManagedCoding
    )

    Application.put_env(:jido_code, :managed_coding_product_fixture, attempt)
    Application.put_env(:jido_code, :managed_coding_product_test_pid, self())

    on_exit(fn ->
      Enum.each(prior, fn
        {key, nil} -> Application.delete_env(:jido_code, key)
        {key, value} -> Application.put_env(:jido_code, key, value)
      end)
    end)

    browser_conn =
      conn
      |> init_test_session(%{})
      |> JidoCodeWeb.ProductAuth.establish_session()

    %{attempt: attempt, browser_conn: browser_conn}
  end

  test "browser, API, and CLI discover the same scoped ready and stale offerings", context do
    {:ok, view, _html} = live(context.browser_conn, ~p"/coding-agents")
    assert has_element?(view, "#agent-offerings-empty")
    assert has_element?(view, "#agent-catalog-discover[phx-disable-with]")

    discover(view)

    assert has_element?(view, "#agent-offering-offering_ready_123456")
    assert has_element?(view, "#select-agent-offering_ready_123456:not([disabled])")
    assert has_element?(view, "#select-agent-offering_stale_123456[disabled]")

    api =
      build_conn()
      |> authenticate_api()
      |> get("/api/v1/agent-offerings", catalog_params())

    assert %{"offerings" => api_offerings, "outcome" => "admitted"} = json_response(api, 200)

    assert {:ok, %{offerings: cli_offerings, outcome: "admitted"}} =
             AgentCLI.execute("catalog", catalog_params(), @credential)

    assert Enum.map(api_offerings, & &1["reference"]) ==
             Enum.map(cli_offerings, & &1.reference)

    assert_receive {:phase_05_catalog, authority, identity, scope}
    assert authority.actor_iri == identity.actor_iri
    assert scope.repository_ref == "repository_123456"
    assert scope.rollout_stage == "evaluation"
  end

  test "all surfaces preserve consent and stable admission outcomes", context do
    cases = [
      {"offering_ready_123456", "submission_admitted_123456", :admitted, 202},
      {"offering_ready_123456", "duplicate_request_123456", :duplicate, 200},
      {"offering_stale_123456", "submission_stale_123456", :stale, 409},
      {"offering_incompatible_123456", "submission_incompatible_123456", :incompatible, 422}
    ]

    Enum.each(cases, fn {offering_ref, key, outcome, status} ->
      params = submission_params(offering_ref, key)

      api =
        build_conn()
        |> authenticate_api()
        |> post("/api/v1/coding-attempts", params)

      assert json_response(api, status)["code"] == to_string(outcome)

      assert {:ok, cli_outcome} = AgentCLI.execute("submit", params, @credential)
      assert cli_outcome.code == outcome
    end)

    {:ok, view, _html} = live(context.browser_conn, ~p"/coding-agents")
    discover(view)

    view
    |> element("#select-agent-offering_ready_123456")
    |> render_click()

    assert has_element?(view, "#agent-submit-task[phx-disable-with]")

    view
    |> form("#agent-submission-form",
      submission: %{
        intent: "Implement the bounded delegated coding change",
        acceptance_requirements: "Tests pass\nNo publication occurs",
        foreground_consent: "true",
        billing_acknowledged: "true"
      }
    )
    |> render_submit()

    assert has_element?(view, "#agent-submission-outcome")
    assert has_element?(view, "#agent-submission-attempt-link")
    assert_receive {:phase_05_submission, authority, identity, request}
    assert authority.actor_iri == identity.actor_iri
    assert request.foreground_consent
    assert request.billing_acknowledged
  end

  test "status and valid finite controls have API, CLI, and browser parity", context do
    ref = context.attempt.presentation_ref

    api_show =
      build_conn()
      |> authenticate_api()
      |> get("/api/v1/coding-attempts/#{ref}")

    assert json_response(api_show, 200)["attempt"]["state"] == "awaiting_actor"

    assert {:ok, %{attempt: cli_attempt}} =
             AgentCLI.execute("show", %{"attempt_ref" => ref}, @credential)

    assert cli_attempt.state == :awaiting_actor

    controls = [
      {"steer", %{"message" => "Stay within the accepted boundary"}},
      {"answer", %{"message" => "Use the existing public gateway"}},
      {"cancel", %{"confirmed" => true}},
      {"handoff", %{}}
    ]

    Enum.each(controls, fn {action, fields} ->
      params = Map.put(fields, "idempotency_key", "#{action}_phase05_123456")

      api =
        build_conn()
        |> authenticate_api()
        |> post("/api/v1/coding-attempts/#{ref}/controls/#{action}", params)

      assert json_response(api, 200)["control"] == action

      cli_params = Map.put(params, "attempt_ref", ref)

      assert {:ok, %{control: ^action, outcome: "admitted"}} =
               AgentCLI.execute(action, cli_params, @credential)
    end)

    {:ok, view, _html} = live(context.browser_conn, "/managed-coding/#{ref}")

    Enum.each(~w[steer answer cancel handoff], fn action ->
      assert has_element?(view, "#managed-control-#{action}")
    end)

    refute has_element?(view, "#managed-control-recovery")

    failed = %{
      context.attempt
      | state: :failed,
        wait_reason: nil,
        interaction_state: :none,
        recovery: %{accepted: true}
    }

    Application.put_env(:jido_code, :managed_coding_product_fixture, failed)

    api_recovery =
      build_conn()
      |> authenticate_api()
      |> post("/api/v1/coding-attempts/#{ref}/controls/recovery", %{
        "confirmed" => true,
        "idempotency_key" => "recovery_phase05_123456"
      })

    assert json_response(api_recovery, 200)["control"] == "recovery"

    assert {:ok, %{control: "recovery"}} =
             AgentCLI.execute(
               "recovery",
               %{
                 "attempt_ref" => ref,
                 "confirmed" => true,
                 "idempotency_key" => "recovery_phase05_cli_123456"
               },
               @credential
             )

    {:ok, recovery_view, _html} = live(context.browser_conn, "/managed-coding/#{ref}")
    assert has_element?(recovery_view, "#managed-control-recovery")
    refute has_element?(recovery_view, "#managed-control-steer")
  end

  test "public surfaces reject sensitive, unbounded, and publication authority", context do
    identity = JidoCodeWeb.ProductAuth.product_identity()
    {:ok, authority} = Product.authority(identity)

    huge = %{offering(:ready) | description: String.duplicate("x", 513)}
    provider = fn _authority, _identity, _scope -> {:ok, [huge]} end

    assert {:error, %JidoCode.Factory.AdapterError{kind: :invalid_input}} =
             AgentCatalogGateway.list(authority, identity, catalog_params(), provider: provider)

    assert {:error, %{outcome: "rejected"}} =
             AgentCLI.execute(
               "submit",
               Map.put(submission_params(), "provider_options", %{"model" => "arbitrary"}),
               @credential
             )

    api =
      build_conn()
      |> authenticate_api()
      |> post("/api/v1/coding-attempts/#{context.attempt.presentation_ref}/controls/merge", %{})

    assert json_response(api, 422)["outcome"] == "rejected"
    refute Enum.any?(AgentCLI.commands(), &(&1 in ~w[publish merge protected_branch]))

    refute Enum.any?(JidoCodeWeb.Router.__routes__(), fn route ->
             String.contains?(route.path, ["publish", "merge", "protected"])
           end)

    {:ok, attempt_map} =
      AgentCLI.execute(
        "show",
        %{"attempt_ref" => context.attempt.presentation_ref},
        @credential
      )

    serialized = inspect(attempt_map)
    refute serialized =~ context.attempt.attempt_iri
    refute serialized =~ context.attempt.repository_iri
    refute serialized =~ "workspace_path"
    refute serialized =~ "hidden_reasoning"
    refute serialized =~ "transcript"

    {:ok, view, _html} = live(context.browser_conn, ~p"/coding-agents")
    refute has_element?(view, "[id*='publish']")
    refute has_element?(view, "[id*='merge']")
    refute has_element?(view, "[id*='protected']")
  end

  defp discover(view) do
    view
    |> form("#agent-catalog-form", catalog: catalog_params())
    |> render_submit()
  end

  defp authenticate_api(conn),
    do: put_req_header(conn, "authorization", "Bearer #{@credential}")

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

  defp submission_params(
         offering_ref \\ "offering_ready_123456",
         idempotency_key \\ "submission_phase05_123456"
       ) do
    %{
      "intent" => "Implement the accepted coding task",
      "repository_ref" => "repository_123456",
      "snapshot_ref" => "snapshot_12345678",
      "task_class" => "focused_change",
      "acceptance_requirements" => ["Tests pass", "No publication occurs"],
      "offering_ref" => offering_ref,
      "idempotency_key" => idempotency_key,
      "foreground_consent" => true,
      "billing_acknowledged" => true
    }
  end

  defp submission_outcome(request) do
    attributes =
      cond do
        request.idempotency_key == "duplicate_request_123456" ->
          %{code: :duplicate, retry: :never, attempt_ref: attempt_ref(), state: :admitted}

        request.offering_ref == "offering_stale_123456" ->
          %{code: :stale, retry: :refresh}

        request.offering_ref == "offering_incompatible_123456" ->
          %{code: :incompatible, retry: :never}

        true ->
          %{code: :admitted, retry: :never, attempt_ref: attempt_ref(), state: :admitted}
      end

    WorkflowOutcome.new(attributes)
  end

  defp offerings, do: [offering(:ready), offering(:stale)]

  defp offering(:ready) do
    %AgentOffering{
      reference: "offering_ready_123456",
      display_name: "Codex developer local",
      description: "Protected foreground delegated coding agent.",
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

  defp offering(:stale) do
    %{
      offering(:ready)
      | reference: "offering_stale_123456",
        display_name: "Codex developer local · stale",
        readiness: :stale,
        readiness_age_seconds: 901,
        limitations: [:readiness_expired, :refresh_required],
        selectable: false
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
      fencing_token: 11,
      sequence: 19,
      task_label: "Complete the bounded product workflow",
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
      workspace: %{changed_files: 2, cleanup: "pending"},
      candidate: %{status: "ready"},
      verification_details: %{source: "independent", status: "pending"},
      disposition_details: %{status: "not_requested"},
      recovery: %{},
      updated_at: ~U[2026-08-27 14:00:00Z]
    }
  end

  defp attempt_ref, do: ManagedCodingAttempt.presentation_ref(iri("attempt"))
  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
