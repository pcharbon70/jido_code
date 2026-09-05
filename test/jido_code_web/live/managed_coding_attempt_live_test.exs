defmodule JidoCodeWeb.ManagedCodingAttemptLiveTest do
  use JidoCodeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias JidoCode.Product.ManagedCodingAttempt

  setup %{conn: conn} do
    prior_provider = Application.get_env(:jido_code, :managed_coding_attempt_provider)
    prior_gateway = Application.get_env(:jido_code, :managed_coding_control_gateway)
    prior_fixture = Application.get_env(:jido_code, :managed_coding_product_fixture)
    prior_pid = Application.get_env(:jido_code, :managed_coding_product_test_pid)

    {:ok, attempt} = ManagedCodingAttempt.new(graph())

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
      restore_env(:managed_coding_attempt_provider, prior_provider)
      restore_env(:managed_coding_control_gateway, prior_gateway)
      restore_env(:managed_coding_product_fixture, prior_fixture)
      restore_env(:managed_coding_product_test_pid, prior_pid)
    end)

    conn =
      conn
      |> init_test_session(%{})
      |> JidoCodeWeb.ConnCase.sign_in_named_human()

    %{conn: conn, attempt: attempt}
  end

  test "renders the authenticated graph-derived attempt without semantic identifiers", context do
    {:ok, view, _html} = live(context.conn, path(context.attempt))

    assert has_element?(view, "#managed-coding-attempt")
    assert has_element?(view, "#managed-attempt-status")
    assert has_element?(view, "#managed-interactions > [id]")
    assert has_element?(view, "#managed-tools > [id]")
    assert has_element?(view, "#managed-checks > [id]")
    assert has_element?(view, "#managed-attempt-agent")
    assert has_element?(view, "#managed-attempt-profile")
    assert has_element?(view, "#managed-workspace-evidence")
    assert has_element?(view, "#managed-candidate-evidence")
    assert has_element?(view, "#managed-verification-evidence")
    assert has_element?(view, "#managed-disposition-evidence")
    assert has_element?(view, "#managed-control-form")
    assert has_element?(view, "#managed-control-steer")
    assert has_element?(view, "#managed-control-answer")
    assert has_element?(view, "#managed-control-cancel")
    assert has_element?(view, "#managed-control-handoff")
    refute has_element?(view, "#managed-control-recovery")
    refute has_element?(view, "[id*='publish']")
    refute has_element?(view, "[id*='merge']")

    html = render(view)
    refute html =~ context.attempt.attempt_iri
    refute html =~ context.attempt.repository_iri
    refute html =~ context.attempt.actor_iri

    assert_receive {:managed_attempt_load, authority, identity, reference}
    assert authority.actor_iri == identity.actor_iri
    assert reference == context.attempt.presentation_ref
  end

  test "submits finite controls and reloads the same graph projection", context do
    {:ok, view, _html} = live(context.conn, path(context.attempt))
    assert_receive {:managed_attempt_load, _, _, _}

    view
    |> form("#managed-control-form",
      control: %{message: "Use the accepted API", confirmed: "false"}
    )
    |> render_submit(%{"action" => "steer"})

    assert_receive {:managed_control, authority, identity, attempt, :steer, params, []}
    assert authority.actor_iri == identity.actor_iri
    assert attempt.fencing_token == context.attempt.fencing_token
    assert params["message"] == "Use the accepted API"
    assert is_binary(params["idempotency_key"])
    assert_receive {:managed_attempt_load, _, _, reference}
    assert reference == context.attempt.presentation_ref
    assert has_element?(view, "#managed-control-outcome")
  end

  test "refresh and reconnect reconstruct an identical special-state view", context do
    delayed = %{
      context.attempt
      | state: :delayed,
        wait_reason: :capacity,
        verification: :unavailable
    }

    Application.put_env(:jido_code, :managed_coding_product_fixture, delayed)

    {:ok, first, _html} = live(context.conn, path(delayed))
    assert has_element?(first, "#managed-attempt-status", "delayed")
    assert has_element?(first, "#managed-attempt-status", "unavailable")

    first |> element("#managed-attempt-refresh") |> render_click()
    assert has_element?(first, "#managed-attempt-status", "delayed")

    {:ok, second, _html} = live(context.conn, path(delayed))
    assert has_element?(second, "#managed-attempt-status", "delayed")
    assert has_element?(second, "#managed-interactions > [id]")
  end

  test "requires the existing authenticated live session", context do
    public = build_conn() |> init_test_session(%{})

    assert {:error, {:redirect, %{to: return_to}}} = live(public, path(context.attempt))
    assert return_to =~ "/sign-in?return_to=%2Fmanaged-coding%2F"
  end

  defp graph do
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
      profile_label: "Codex CLI workspace editor",
      provider: :openai_codex,
      deployment_class: :developer_local,
      billing_mode: :subscription,
      readiness: :ready,
      readiness_age_seconds: 2,
      rollout_stage: :evaluation,
      repository_envelope: "isolated_worktree",
      limitations: ["candidate_only", "no_publication_authority"],
      workspace: %{"status" => "changed"},
      candidate: %{"status" => "present"},
      verification_details: %{"status" => "pending"},
      disposition_details: %{"status" => "not_requested"},
      updated_at: ~U[2026-08-25 13:00:00Z]
    }
  end

  defp path(attempt), do: "/managed-coding/#{attempt.presentation_ref}"

  defp restore_env(key, nil), do: Application.delete_env(:jido_code, key)
  defp restore_env(key, value), do: Application.put_env(:jido_code, key, value)
  defp iri(suffix), do: "https://jido.run/id/activity/#{suffix}"
end
