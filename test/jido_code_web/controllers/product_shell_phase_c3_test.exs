defmodule JidoCodeWeb.ProductShellPhaseC3Test do
  use JidoCodeWeb.ConnCase, async: false

  alias JidoCode.Identity.Administration
  alias JidoCode.Identity.Store

  @admin %{
    source: :governed_identity_admin,
    actor_ref: "human_phase_c3_shell_administrator",
    assurance: :action_bound_step_up
  }

  setup_all do
    now = DateTime.utc_now()
    {:ok, factory} = Store.resolve_resource(:factory)

    project =
      register_resource!(%{
        resource_ref: "project_phase_c3_shell",
        kind: :project,
        iri: "https://jido.run/id/project/phase-c3-shell",
        tenant_ref: factory.tenant_ref,
        project_ref: "phase_c3_shell",
        parent_ref: factory.resource_ref,
        graph_scope_iri: "https://jido.run/graph/project/phase-c3-shell",
        classification: :internal,
        environment: :test,
        lifecycle: :active
      })

    {:ok, _membership} =
      Administration.put_membership(
        @admin,
        %{
          membership_ref: "membership_phase_c3_shell",
          subject_ref: "human_test_operator",
          tenant_ref: project.tenant_ref,
          project_ref: project.project_ref,
          roles: [:project_developer, :knowledge_steward],
          route_groups: [:developer, :knowledge],
          clearance: :internal,
          valid_from: DateTime.add(now, -60),
          valid_to: DateTime.add(now, 86_400)
        },
        now: now
      )

    %{project: project}
  end

  test "composes one scope-aware application shell from the server-owned view model", %{
    conn: conn
  } do
    response = conn |> init_test_session(%{}) |> sign_in_named_human() |> get(~p"/factory")
    document = response |> html_response(200) |> LazyHTML.from_document()

    assert count(document, "h1") == 1
    assert has?(document, "#product-shell[data-application-shell]")
    assert has?(document, "#product-shell-skip-link[href='#product-main']")
    assert has?(document, "#product-main[tabindex='-1']")
    assert has?(document, "#product-primary-navigation-item-factory[aria-current='page']")
    assert has?(document, "#product-utility-navigation")
    assert has?(document, "#product-responsive-navigation")
    assert has?(document, "#product-account-menu-region")
    assert has?(document, "#product-context[data-readiness-state='limited']")
    assert has?(document, "#product-breadcrumbs [aria-current='page']")
    assert has?(document, "#product-page-header-title[tabindex='-1']")
    assert has?(document, "#product-footer")
    assert has?(document, "#product-sign-out-form[method='post']")
    assert has?(document, "input[name='_method'][value='delete']")
    assert has?(document, "input[name='_csrf_token']")
    assert has?(document, "link[rel='canonical'][href='http://localhost:4002/factory']")
    refute has?(document, "input[name*='authority']")
    refute has?(document, "input[name*='scope']")
  end

  test "renders a native authorized project switch with scope-reset navigation", %{
    conn: conn,
    project: project
  } do
    response = conn |> init_test_session(%{}) |> sign_in_named_human() |> get(~p"/factory")
    document = response |> html_response(200) |> LazyHTML.from_document()

    assert has?(
             document,
             "#product-project-switcher-form[action='/projects/switch'][method='get']"
           )

    assert has?(
             document,
             "#product-project-switcher-select option[value='#{project.resource_ref}']"
           )

    switched =
      response
      |> recycle()
      |> get(~p"/projects/switch?#{%{project_switch: %{project_ref: project.resource_ref}}}")

    assert redirected_to(switched) == ~p"/projects/#{project.resource_ref}"
  end

  test "keeps bounded filter and pagination intent in durable GET URLs", %{conn: conn} do
    response =
      conn
      |> init_test_session(%{})
      |> sign_in_named_human()
      |> get("/factory/fleet?q=%20waiting%20&state=blocked&page=2&authority=attacker")

    document = response |> html_response(200) |> LazyHTML.from_document()

    assert has?(document, "#product-filter-search-form[action='/factory/fleet'][method='get']")
    assert has?(document, "#product-filter-search-query[name='q'][value='waiting']")
    assert has?(document, "#product-filter-search-filter-state[name='state']")
    assert has?(document, "#product-pagination-page-2[aria-current='page']")

    assert html_response(response, 200) =~
             ~s(href="http://localhost:4002/factory/fleet?page=2&amp;q=waiting&amp;state=blocked")

    refute has?(document, "input[name='authority']")
  end

  test "marks project context and current navigation without deriving authority from the URL", %{
    conn: conn,
    project: project
  } do
    response =
      conn
      |> init_test_session(%{})
      |> sign_in_named_human()
      |> get(~p"/projects/#{project.resource_ref}/attempts")

    document = response |> html_response(200) |> LazyHTML.from_document()

    assert has?(
             document,
             "#product-primary-navigation-item-project-attempts[aria-current='page']"
           )

    assert has?(document, "#product-context-scope", "Project phase_c3_shell")
    assert has?(document, "#product-breadcrumbs-item-current[aria-current='page']", "Attempts")
    refute html_response(response, 200) =~ project.iri
    refute html_response(response, 200) =~ project.graph_scope_iri
  end

  test "renders a focusable error summary for invalid bounded GET intent", %{conn: conn} do
    response =
      conn
      |> init_test_session(%{})
      |> sign_in_named_human()
      |> get("/factory/fleet?state=invented&page=1000")

    document = response |> html_response(200) |> LazyHTML.from_document()

    assert has?(document, "#product-error-summary[role='alert'][tabindex='-1']")

    assert has?(
             document,
             "#product-error-summary-error-state[href='#product-filter-search-filter-state']"
           )

    assert has?(document, "#product-error-summary-error-page[href='#product-pagination']")
    assert has?(document, "#product-pagination-page-1[aria-current='page']")
  end

  defp register_resource!(attributes) do
    {:ok, resource} = Administration.register_resource(@admin, attributes)
    resource
  end

  defp has?(document, selector), do: count(document, selector) > 0

  defp has?(document, selector, text) do
    document
    |> LazyHTML.query(selector)
    |> LazyHTML.text()
    |> String.contains?(text)
  end

  defp count(document, selector), do: document |> LazyHTML.query(selector) |> Enum.count()
end
