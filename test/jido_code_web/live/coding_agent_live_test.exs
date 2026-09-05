defmodule JidoCodeWeb.CodingAgentLiveTest do
  use JidoCodeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias JidoCode.Product.AgentOffering
  alias JidoCode.Product.WorkflowOutcome

  setup %{conn: conn} do
    test_pid = self()
    prior_catalog = Application.get_env(:jido_code, :agent_catalog_gateway)
    prior_submission = Application.get_env(:jido_code, :coding_submission_gateway)

    catalog_gateway = fn authority, identity, params ->
      send(test_pid, {:catalog_discovery, authority, identity, params})
      {:ok, [offering()]}
    end

    submission_gateway = fn authority, identity, params ->
      send(test_pid, {:coding_submission, authority, identity, params})

      WorkflowOutcome.new(%{
        code: :admitted,
        retry: :never,
        attempt_ref: "attempt-reference-001",
        state: :admitted
      })
    end

    Application.put_env(:jido_code, :agent_catalog_gateway, catalog_gateway)
    Application.put_env(:jido_code, :coding_submission_gateway, submission_gateway)

    on_exit(fn ->
      restore_env(:agent_catalog_gateway, prior_catalog)
      restore_env(:coding_submission_gateway, prior_submission)
    end)

    conn =
      conn
      |> init_test_session(%{})
      |> JidoCodeWeb.ConnCase.sign_in_named_human()

    %{conn: conn}
  end

  test "requires the authenticated product live session" do
    public = build_conn() |> init_test_session(%{})

    assert {:error, {:redirect, %{to: "/sign-in?return_to=%2Fcoding-agents"}}} =
             live(public, ~p"/coding-agents")
  end

  test "discovers scope-filtered agent offerings with stable browser controls", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/coding-agents")

    assert has_element?(view, "#coding-agent-workbench")
    assert has_element?(view, "#agent-catalog-form")
    assert has_element?(view, "#agent-offerings-empty")
    refute has_element?(view, "#agent-task-submission")

    discover(view)

    assert_receive {:catalog_discovery, authority, identity, params}
    assert authority.actor_iri == identity.actor_iri
    assert params["repository_ref"] == "repository-reference-001"
    assert has_element?(view, "#agent-offering-agent-profile-reference-001")
    assert has_element?(view, "#select-agent-agent-profile-reference-001")
  end

  test "selects an exact profile and admits a consented semantic task", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/coding-agents")
    discover(view)
    assert_receive {:catalog_discovery, _, _, _}

    view
    |> element("#select-agent-agent-profile-reference-001")
    |> render_click()

    assert has_element?(view, "#agent-task-submission")
    assert has_element?(view, "#agent-submission-form")

    view
    |> form("#agent-submission-form",
      submission: %{
        intent: "Implement the bounded repository change",
        acceptance_requirements: "The focused test passes\nNo publication occurs",
        foreground_consent: "true",
        billing_acknowledged: "true"
      }
    )
    |> render_submit()

    assert_receive {:coding_submission, authority, identity, params}
    assert authority.actor_iri == identity.actor_iri
    assert params["offering_ref"] == "agent-profile-reference-001"
    assert params["foreground_consent"] == "true"
    assert params["billing_acknowledged"] == "true"
    assert has_element?(view, "#agent-submission-outcome")

    assert has_element?(
             view,
             "#agent-submission-attempt-link[href='/managed-coding/attempt-reference-001']"
           )

    refute has_element?(view, "[id*='publish']")
    refute has_element?(view, "[id*='merge']")
  end

  defp discover(view) do
    view
    |> form("#agent-catalog-form",
      catalog: %{
        repository_ref: "repository-reference-001",
        snapshot_ref: "snapshot-reference-001",
        task_class: "focused_change",
        language_class: "elixir_phoenix",
        capability_class: "workspace_write_registered_checks",
        rollout_stage: "evaluation"
      }
    )
    |> render_submit()
  end

  defp offering do
    %AgentOffering{
      reference: "agent-profile-reference-001",
      display_name: "Codex CLI · workspace editor",
      description: "Foreground developer-local coding through the governed runtime.",
      runtime_class: :delegated_cli,
      provider: :openai_codex,
      deployment_class: :developer_local,
      authentication_kind: :existing_cli_session,
      billing_mode: :provider_account,
      capability_class: :workspace_write_registered_checks,
      capability_summary: "Edits one isolated workspace and runs registered checks.",
      task_classes: [:focused_change],
      language_classes: [:elixir_phoenix],
      readiness: :ready,
      readiness_age_seconds: 2,
      rollout_stage: :evaluation,
      profile_revision: 1,
      profile_digest: String.duplicate("a", 64),
      limitations: ["candidate_only", "no_publication_authority"],
      selectable: true
    }
  end

  defp restore_env(key, nil), do: Application.delete_env(:jido_code, key)
  defp restore_env(key, value), do: Application.put_env(:jido_code, key, value)
end
