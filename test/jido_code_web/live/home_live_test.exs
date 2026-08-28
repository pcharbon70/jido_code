defmodule JidoCodeWeb.HomeLiveTest do
  use JidoCodeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias JidoCode.Product.CommandOutcome
  alias JidoCode.Product.Projection
  alias JidoCode.Product.RepositoryWikiOperationsProjection
  alias JidoCode.Product.RepositoryWikiProjection
  alias JidoCode.Product.SurfaceContract

  setup %{conn: conn} do
    prior_provider = Application.get_env(:jido_code, :product_projection_provider)
    prior_fixture = Application.get_env(:jido_code, :product_projection_fixture)
    prior_pid = Application.get_env(:jido_code, :product_projection_test_pid)
    prior_gateway = Application.get_env(:jido_code, :product_command_gateway)
    prior_command = Application.get_env(:jido_code, :product_command_fixture)
    prior_wiki_provider = Application.get_env(:jido_code, :repository_wiki_projection_provider)
    prior_wiki_fixture = Application.get_env(:jido_code, :repository_wiki_projection_fixture)

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

    Application.put_env(
      :jido_code,
      :repository_wiki_projection_provider,
      JidoCode.TestSupport.FakeRepositoryWikiProjectionProvider
    )

    Application.put_env(:jido_code, :repository_wiki_projection_fixture, wiki_projection())

    on_exit(fn ->
      restore_env(:product_projection_provider, prior_provider)
      restore_env(:product_projection_fixture, prior_fixture)
      restore_env(:product_projection_test_pid, prior_pid)
      restore_env(:product_command_gateway, prior_gateway)
      restore_env(:product_command_fixture, prior_command)
      restore_env(:repository_wiki_projection_provider, prior_wiki_provider)
      restore_env(:repository_wiki_projection_fixture, prior_wiki_fixture)
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

  test "shows an authorized repository wiki with current status, navigation, sources, and backlinks",
       %{conn: conn} do
    {:ok, ref} = SurfaceContract.encode_resource("https://jido.run/id/repository/alpha")

    {:ok, view, _html} =
      live(
        conn,
        ~p"/?#{%{repository: ref, surface: "wiki", wiki_page: "overview", wiki_view: "overview"}}"
      )

    assert has_element?(view, "#factory-nav-wiki[aria-current='page']")
    assert has_element?(view, "#repository-wiki")
    assert has_element?(view, "#wiki-state", "current")
    assert has_element?(view, "#wiki-stat-source", "source-fence-41")
    assert has_element?(view, "#wiki-stat-tokens", "0 tokens · 0 cost")
    assert has_element?(view, "#wiki-view-guides")
    assert has_element?(view, "#wiki-navigation-pages > [id]")
    assert has_element?(view, "#wiki-page-title", "Overview")
    assert has_element?(view, "#wiki-page-sources > [id]", "README.md")
    assert has_element?(view, "#wiki-page-backlinks > [id]", "Getting Started")

    assert_receive {:repository_wiki_projection_load, authority, identity, options}
    assert authority.actor_iri == identity.actor_iri
    assert options[:repository] == "https://jido.run/id/repository/alpha"
    assert options[:repository_authorized?]
    assert options[:page_slug] == "overview"
  end

  test "uses bounded semantic events for wiki views, search, settings, and regeneration", %{
    conn: conn
  } do
    {:ok, ref} = SurfaceContract.encode_resource("https://jido.run/id/repository/alpha")
    {:ok, view, _html} = live(conn, ~p"/?#{%{repository: ref, surface: "wiki"}}")

    view |> element("#wiki-view-search") |> render_click()

    assert_patch(
      view,
      ~p"/?#{%{repository: ref, surface: "wiki", wiki_view: "search"}}"
    )

    assert has_element?(view, "#wiki-search-form")

    view
    |> form("#wiki-search-form", wiki_search: %{query: "getting started"})
    |> render_submit()

    assert_patch(
      view,
      ~p"/?#{%{repository: ref, surface: "wiki", wiki_query: "getting started", wiki_view: "search"}}"
    )

    assert has_element?(view, "#wiki-search-results > [id]", "Getting Started")

    view |> element("#wiki-view-settings") |> render_click()
    assert has_element?(view, "#wiki-settings-form")
    assert has_element?(view, "#wiki-cost-posture", "Zero model tokens")

    params = %{
      mode: "automatic",
      read_visibility: "retained",
      retention: "standard",
      confirmed: "true"
    }

    view
    |> form("#wiki-settings-form", wiki_settings: params)
    |> render_submit()

    assert_receive {:configure_repository_wiki, authority, identity, repository, submitted}
    assert authority.actor_iri == identity.actor_iri
    assert repository == "https://jido.run/id/repository/alpha"
    assert submitted["mode"] == "automatic"
    assert has_element?(view, "#wiki-command-receipt", "committed")

    view |> element("#wiki-regenerate") |> render_click()

    assert_receive {:regenerate_repository_wiki, _authority, _identity,
                    "https://jido.run/id/repository/alpha"}
  end

  test "renders disabled, stale, failed, and rebuilding wiki posture without leaking cached pages",
       %{conn: conn} do
    {:ok, ref} = SurfaceContract.encode_resource("https://jido.run/id/repository/alpha")

    for state <- [:disabled, :hidden, :unauthorized, :unavailable] do
      Application.put_env(
        :jido_code,
        :repository_wiki_projection_fixture,
        RepositoryWikiProjection.unavailable(state, "https://jido.run/id/repository/alpha")
      )

      {:ok, view, _html} = live(conn, ~p"/?#{%{repository: ref, surface: "wiki"}}")
      assert has_element?(view, "#wiki-state-#{state}")
      refute has_element?(view, "#wiki-navigation-pages > [id]")
    end
  end

  test "renders accessible wiki usage, budgets, fleet health, and alerts", %{conn: conn} do
    {:ok, ref} = SurfaceContract.encode_resource("https://jido.run/id/repository/alpha")
    {:ok, view, _html} = live(conn, ~p"/?#{%{repository: ref, surface: "wiki"}}")

    view |> element("#wiki-view-usage") |> render_click()
    assert has_element?(view, "#wiki-usage")
    assert has_element?(view, "#wiki-usage-state", "ready")
    assert has_element?(view, "#wiki-stat-usage-attempts", "2")
    assert has_element?(view, "#wiki-stat-usage-tokens", "0")
    assert has_element?(view, "#wiki-budget-state", "available")
    assert has_element?(view, "#wiki-budget-remaining", "CAD")
    assert has_element?(view, "#wiki-synthesis-availability", "unavailable")
    assert has_element?(view, "#wiki-currency-totals > [id]", "CAD")
    assert has_element?(view, "#wiki-usage-breakdowns > [id]", "manual")
    assert has_element?(view, "#wiki-live-reservations > [id]", "reserved")

    view |> element("#wiki-view-operations") |> render_click()
    assert has_element?(view, "#wiki-operations")
    assert has_element?(view, "#wiki-stat-fleet-repositories", "2")
    assert has_element?(view, "#wiki-stat-fleet-alerts", "1")
    assert has_element?(view, "#wiki-fleet-repositories > [id]", "automatic")
    assert has_element?(view, "#wiki-operations-alerts > [id]", "usage_unknown")
    assert has_element?(view, "#wiki-runbook-note", "existing store backup")
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

  defp wiki_projection do
    %RepositoryWikiProjection{
      state: :current,
      visible?: true,
      repository_iri: "https://jido.run/id/repository/alpha",
      dataset_revision: 41,
      enrollment: %{
        state: :automatic,
        read_visibility: :retained,
        revision: 3
      },
      edition: %{
        edition_iri: "https://jido.run/id/repo/alpha/wiki/edition/current",
        source_fence: "source-fence-41",
        compiler_profile: "wiki-deterministic-elixir/1.0.0",
        compiler_digest: String.duplicate("a", 64),
        freshness: "fresh",
        generation_mode: :deterministic_only,
        model_tokens: 0,
        usage_cost_microunits: 0
      },
      navigation: [
        %{
          page_iri: "https://jido.run/id/repo/alpha/wiki/edition/current/page/overview",
          slug: "overview",
          title: "Overview",
          kind: "project_overview",
          audience: "user",
          order: 0,
          parent_slug: nil,
          freshness: "fresh",
          completeness: "complete",
          content_digest: String.duplicate("b", 64)
        },
        %{
          page_iri: "https://jido.run/id/repo/alpha/wiki/edition/current/page/getting-started",
          slug: "getting-started",
          title: "Getting Started",
          kind: "user_guide",
          audience: "user",
          order: 1,
          parent_slug: "user-guides",
          freshness: "fresh",
          completeness: "complete",
          content_digest: String.duplicate("c", 64)
        }
      ],
      selected_page: %{
        page_iri: "https://jido.run/id/repo/alpha/wiki/edition/current/page/overview",
        slug: "overview",
        title: "Overview",
        kind: "project_overview",
        audience: "user",
        order: 0,
        freshness: "fresh",
        completeness: "complete",
        content_digest: String.duplicate("b", 64)
      },
      backlinks: [
        %{
          "id" => "backlink-1",
          "sourceSlug" => "getting-started",
          "sourceTitle" => "Getting Started"
        }
      ],
      sources: [
        %{
          "id" => "source-1",
          "source" => "source-1",
          "sourceLocator" => "README.md",
          "sourceAuthority" => "exact_git_snapshot",
          "freshness" => "fresh"
        }
      ],
      gaps: [
        %{
          "id" => "gap-1",
          "sourceLocator" => "docs/missing.md",
          "omissionCode" => "absent"
        }
      ],
      history: [
        %{
          "id" => "history-1",
          "revision" => 3,
          "state" => "automatic",
          "currentEdition" => "current"
        }
      ],
      search_results: [
        %{
          slug: "getting-started",
          title: "Getting Started",
          audience: "user",
          kind: "user_guide",
          score: 16,
          snippet: "Getting Started · user · user_guide"
        }
      ],
      usage: %RepositoryWikiOperationsProjection{
        state: :ready,
        repository_iri: "https://jido.run/id/repository/alpha",
        tenant_iri: "https://jido.run/id/tenant/alpha",
        evaluated_at: ~U[2026-08-28 16:00:00Z],
        period: %{start_at: ~U[2026-08-01 00:00:00Z], end_at: ~U[2026-08-28 16:00:00Z]},
        totals: %{
          attempts: 2,
          deterministic_attempts: 2,
          local_elapsed_ms: 40,
          local_input_bytes: 8_192,
          input_tokens: 0,
          output_tokens: 0,
          cached_tokens: 0,
          reasoning_tokens: 0,
          measured_cost_microunits: 0,
          reserved_liability_microunits: 10,
          unknown_liability_microunits: 0
        },
        currency_totals: [
          %{id: "cad", currency: "CAD", measured: 0, reserved: 10, unknown: 0}
        ],
        breakdowns: [
          %{
            id: "trigger-manual",
            dimension: :trigger,
            value: "manual",
            attempts: 2,
            tokens: 0,
            measured_cost_microunits: 0,
            unknown_liability_microunits: 0
          }
        ],
        budget: %{
          state: :available,
          limit: 100,
          remaining: 90,
          currency: "CAD",
          live: 1,
          window_start: ~U[2026-08-01 00:00:00Z],
          window_end: ~U[2026-09-01 00:00:00Z]
        },
        profile: %{
          deterministic_available?: true,
          synthesis_available?: false,
          unavailable_reason: :hosted_synthesis_disabled_in_v1
        },
        reservations: [
          %{
            id: "reservation-one",
            state: :reserved,
            cost_microunits: 10,
            currency: "CAD",
            expires_at: ~U[2026-08-28 17:00:00Z]
          }
        ],
        warnings: []
      },
      operations: %{
        state: :ready,
        repository_count: 2,
        current_count: 1,
        stale_count: 1,
        queue_pending: 2,
        queue_active: 1,
        reservations_live: 1,
        usage_pending: 0,
        usage_unknown: 1,
        retained_bytes: 12_000,
        alert_count: 1,
        repositories: [
          %{
            id: "repository-alpha-health",
            repository_iri: "https://jido.run/id/repository/alpha",
            tenant_iri: "https://jido.run/id/tenant/alpha",
            enrollment: :automatic,
            current_state: :current,
            current_age_seconds: 60,
            maintainer: :running,
            lease: %{state: :active, expires_at: ~U[2026-08-28 17:00:00Z]},
            queue: %{pending: 0, active: 1},
            compilation: %{success: 2, failed: 0, abandoned: 0},
            coverage: %{pages: 10, dependencies: 20, guides: 4, gaps: 0},
            accounting: %{live_reservations: 1, usage_pending: 0, usage_unknown: 0},
            storage: %{edition_count: 2, retained_bytes: 12_000},
            restore: :verified,
            alerts: []
          }
        ],
        alerts: [
          %{
            id: "alert-usage-unknown",
            repository_iri: "https://jido.run/id/repository/beta",
            tenant_iri: "https://jido.run/id/tenant/alpha",
            type: :usage_unknown,
            severity: :critical
          }
        ]
      },
      settings: %{
        mode: :automatic,
        read_visibility: :retained,
        retention: :standard,
        generation_mode: :deterministic_only,
        token_posture: :zero_model_tokens,
        regeneration_available?: true
      },
      warnings: []
    }
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
