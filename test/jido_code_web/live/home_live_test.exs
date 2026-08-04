defmodule JidoCodeWeb.HomeLiveTest do
  use JidoCodeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias JidoCode.Product.CommandOutcome
  alias JidoCode.Product.Projection
  alias JidoCode.Product.SurfaceContract

  setup %{conn: conn} do
    prior_provider = Application.get_env(:jido_code, :product_projection_provider)
    prior_fixture = Application.get_env(:jido_code, :product_projection_fixture)
    prior_pid = Application.get_env(:jido_code, :product_projection_test_pid)
    prior_gateway = Application.get_env(:jido_code, :product_command_gateway)
    prior_command = Application.get_env(:jido_code, :product_command_fixture)

    Application.put_env(
      :jido_code,
      :product_projection_provider,
      JidoCode.TestSupport.FakeProductProjectionProvider
    )

    Application.put_env(:jido_code, :product_projection_fixture, projection())
    Application.put_env(:jido_code, :product_projection_test_pid, self())

    Application.put_env(
      :jido_code,
      :product_command_gateway,
      JidoCode.TestSupport.FakeProductCommandGateway
    )

    Application.put_env(:jido_code, :product_command_fixture, {:ok, command_receipt()})

    on_exit(fn ->
      restore_env(:product_projection_provider, prior_provider)
      restore_env(:product_projection_fixture, prior_fixture)
      restore_env(:product_projection_test_pid, prior_pid)
      restore_env(:product_command_gateway, prior_gateway)
      restore_env(:product_command_fixture, prior_command)
    end)

    conn =
      conn
      |> init_test_session(%{})
      |> JidoCodeWeb.ProductAuth.establish_session()

    {:ok, conn: conn}
  end

  test "renders graph-backed factory posture and bounded island props", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#application-shell")
    assert has_element?(view, "#application-sign-out[href='/sign-out']")
    assert has_element?(view, "#factory-workbench")
    assert has_element?(view, "#factory-posture")
    assert has_element?(view, "#factory-flow-island")
    assert has_element?(view, "#factory-metric-repositories", "2")
    assert has_element?(view, "#factory-sidebar-revision", "41")

    assert_receive {:product_projection_load, authority, identity, options}
    assert authority.actor_iri == identity.actor_iri
    assert options[:repository] == nil
  end

  test "navigates, filters, and selects a repository through verified presentation refs", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/?surface=repositories")
    assert_receive {:product_projection_load, _authority, _identity, initial_options}
    assert initial_options[:repository] == nil

    assert has_element?(view, "#repository-catalog")
    assert has_element?(view, "#repositories > [id]")

    view
    |> form("#repository-filter-form", filter: %{query: "alpha"})
    |> render_change()

    assert has_element?(view, "#repositories > [id]", "alpha")
    refute has_element?(view, "#repositories > [id]", "beta")

    {:ok, ref} = SurfaceContract.encode_resource("https://jido.run/id/repository/alpha")

    view
    |> element("#repositories button[phx-value-repository='#{ref}']")
    |> render_click()

    assert_patch(view, ~p"/?#{%{repository: ref, surface: "repositories"}}")

    assert_receive {:product_projection_load, _authority, _identity,
                    [repository: "https://jido.run/id/repository/alpha"]}
  end

  test "accepts only finite semantic events from the LiveVue island", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_hook(view, "product/semantic-event", %{
      "action" => "select-surface",
      "surface" => "execution"
    })

    assert_patch(view, ~p"/?surface=execution")
    assert has_element?(view, "#execution-activity")

    render_hook(view, "product/semantic-event", %{"action" => "raw-query"})
    assert has_element?(view, "#flash-group")
  end

  test "renders a fail-closed unavailable state without stale collection data", %{conn: conn} do
    Application.put_env(
      :jido_code,
      :product_projection_fixture,
      Projection.unavailable(:maintenance)
    )

    {:ok, view, _html} = live(conn, ~p"/?surface=repositories")

    assert has_element?(view, "#projection-notice")
    assert has_element?(view, "#repositories-empty")
    refute has_element?(view, "#repositories button")
  end

  test "validates and submits repository enrollment as a finite semantic command", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?surface=repositories")

    params = %{
      conceptual_key: "repo-alpha",
      provider: "https://github.com",
      external_id: "R_alpha",
      owner: "agentjido",
      name: "alpha",
      reason: "Managed factory enrollment",
      confirmed: "true"
    }

    view
    |> form("#repository-enrollment-form", enrollment: params)
    |> render_change()

    assert has_element?(view, "#repository-enrollment-preview")

    view
    |> form("#repository-enrollment-form", enrollment: params)
    |> render_submit()

    assert_receive {:enroll_repository, authority, identity, submitted}
    assert authority.actor_iri == identity.actor_iri
    assert submitted["conceptual_key"] == "repo-alpha"
    assert is_binary(submitted["idempotency_key"])
    assert has_element?(view, "#product-command-receipt", "committed")
  end

  test "does not present a failed semantic outcome as committed", %{conn: conn} do
    Application.put_env(
      :jido_code,
      :product_command_fixture,
      {:ok, %CommandOutcome{outcome: :unavailable, retry: :retry, dataset_revision: nil}}
    )

    {:ok, view, _html} = live(conn, ~p"/?surface=repositories")

    params = %{
      conceptual_key: "repo-unavailable",
      provider: "https://github.com",
      external_id: "R_unavailable",
      owner: "agentjido",
      name: "unavailable",
      reason: "Exercise failed command outcome",
      confirmed: "true"
    }

    view
    |> form("#repository-enrollment-form", enrollment: params)
    |> render_submit()

    assert has_element?(view, "#product-command-receipt", "unavailable")
    assert has_element?(view, "#flash-group")
    refute render(view) =~ "Repository enrollment committed"
  end

  defp projection do
    %Projection{
      state: :ready,
      dataset_revision: 41,
      generated_at: ~U[2026-08-04 10:00:00Z],
      freshness: "current",
      complete?: true,
      truncated?: false,
      repositories: repositories(),
      work: %{
        eligible: [%{"id" => "work-1", "task" => "https://jido.run/id/task/1", "revision" => 2}],
        blocked: [],
        executing: [],
        awaiting_decision: []
      },
      attempts: [%{"id" => "attempt-1", "attempt" => "attempt-1", "state" => "running"}],
      outcomes: Projection.empty_outcomes(),
      knowledge: [%{"id" => "knowledge-1", "assertion" => "knowledge-1", "state" => "adopted"}],
      warnings: []
    }
  end

  defp repositories do
    [
      %{
        id: "alpha",
        iri: "https://jido.run/id/repository/alpha",
        enrollment_iri: "https://jido.run/id/enrollment/alpha",
        label: "alpha",
        state: "enrolled"
      },
      %{
        id: "beta",
        iri: "https://jido.run/id/repository/beta",
        enrollment_iri: "https://jido.run/id/enrollment/beta",
        label: "beta",
        state: "enrolled"
      }
    ]
  end

  defp restore_env(key, nil), do: Application.delete_env(:jido_code, key)
  defp restore_env(key, value), do: Application.put_env(:jido_code, key, value)

  defp command_receipt do
    %CommandOutcome{
      outcome: :committed,
      retry: :never,
      dataset_revision: 42
    }
  end
end
