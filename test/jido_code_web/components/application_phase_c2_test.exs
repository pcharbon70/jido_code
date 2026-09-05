defmodule JidoCodeWeb.Components.ApplicationPhaseC2Test do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias JidoCode.Architecture.HypermediaUIPhaseC2
  alias JidoCodeWeb.Components.Application, as: AppComponents
  alias JidoCodeWeb.HypermediaUIPhaseC2ShellFixture

  @source_path "lib/jido_code_web/components/application.ex"
  @hostile ~s|<script data-shell-hostile>window.escape = false</script><b>& "quoted"</b>|

  test "renders every Section 2.2 shell, navigation, context, and page composite" do
    document = fixture_document()

    for selector <- [
          "#hui-c2-shell[data-application-shell]",
          "#hui-c2-masthead[data-application-masthead]",
          "#hui-c2-primary-navigation[data-application-primary-navigation]",
          "#hui-c2-project-switcher[data-application-project-switcher]",
          "#hui-c2-utility-navigation[data-application-utility-navigation]",
          "#hui-c2-account-menu-region[data-application-account-session]",
          "#hui-c2-responsive-navigation[data-application-responsive-navigation]",
          "#hui-c2-breadcrumbs[data-application-breadcrumbs]",
          "#hui-c2-current-context[data-application-context-explanation]",
          "#hui-c2-attempt-context[data-application-attempt-context]",
          "#hui-c2-page-header[data-application-page-header]",
          "#hui-c2-filter[data-application-filter-search]",
          "#hui-c2-pagination[data-application-pagination]",
          "#hui-c2-empty-state[data-application-empty-state]",
          "#hui-c2-error-summary[data-application-error-summary]",
          "#hui-c2-maintenance-banner[data-application-service-banner]",
          "#hui-c2-degraded-banner[data-application-service-banner]",
          "#hui-c2-footer[data-application-footer]"
        ] do
      assert_present(document, selector)
    end
  end

  test "preserves skip, navigation, breadcrumb, disclosure, and page landmark semantics" do
    document = fixture_document()

    assert_present(document, "#hui-c2-shell > #hui-c2-shell-skip-link[href='#hui-c2-main']")
    assert LazyHTML.attribute(LazyHTML.query(document, "main"), "id") == ["hui-c2-main"]
    assert_present(document, "main#hui-c2-main[tabindex='-1']")

    assert LazyHTML.attribute(LazyHTML.query(document, "h1"), "id") == [
             "hui-c2-page-header-title"
           ]

    assert_present(document, "#hui-c2-page-header-title[tabindex='-1']")

    assert_present(
      document,
      "#hui-c2-primary-navigation-item-fleet[href='/factory'][aria-current='page']"
    )

    assert_present(document, "#hui-c2-utility-navigation[aria-label='Utility navigation']")
    assert_present(document, "#hui-c2-breadcrumbs[aria-label='Breadcrumbs']")

    assert_present(
      document,
      "#hui-c2-breadcrumbs-item-attempt[aria-current='page']"
    )

    refute_present(document, "a#hui-c2-breadcrumbs-item-attempt")

    assert_present(
      document,
      "#hui-c2-responsive-navigation-item-navigation > summary#hui-c2-responsive-navigation-item-navigation-summary"
    )

    assert_present(
      document,
      "#hui-c2-responsive-navigation-links[aria-label='Compact navigation']"
    )

    refute_present(document, "#hui-c2-account-menu [role='menu']")
    refute_present(document, "a[href='/administration']")
    refute LazyHTML.to_html(document) =~ "Hidden administration"
  end

  test "uses ordinary GET forms, associated controls, and native submit buttons" do
    document = fixture_document()

    assert_present(
      document,
      "#hui-c2-project-switcher-form[action='/factory/projects/switch'][method='get']"
    )

    assert_present(
      document,
      "#hui-c2-project-switcher-select[name='project_switcher[project]']"
    )

    assert_present(
      document,
      "#hui-c2-project-switcher-select option[value='project-alpha'][selected]"
    )

    assert_present(document, "#hui-c2-project-switcher-submit[type='submit']")
    refute_present(document, "#hui-c2-project-switcher-form input[name='_csrf_token']")

    assert_present(
      document,
      "#hui-c2-filter-form[action='/factory/attempts'][method='get'][role='search']"
    )

    assert_present(document, "#hui-c2-filter-query[name='factory_filter[query]'][type='search']")
    assert_present(document, "#hui-c2-filter-form label #hui-c2-filter-query")

    assert_present(
      document,
      "#hui-c2-filter-filter-state[name='factory_filter[state]'] option[value='running'][selected]"
    )

    assert_present(document, "#hui-c2-filter-submit[type='submit']")
    assert_present(document, "#hui-c2-filter-reset[href='/factory/attempts']")
    refute_present(document, "#hui-c2-filter-form input[name='_csrf_token']")
  end

  test "renders explicit route, scope, role, assurance, readiness, attempt, and service states" do
    document = fixture_document()

    assert_text(document, "#hui-c2-current-context-route", "Attempt detail")

    assert_text(
      document,
      "#hui-c2-current-context-scope",
      "Tenant North / Project Alpha / Graph Factory"
    )

    assert_text(document, "#hui-c2-current-context-role", "Reviewer")
    assert_text(document, "#hui-c2-current-context-assurance", "Password plus security key")

    assert_present(
      document,
      "#hui-c2-current-context[data-readiness-state='limited'] #hui-c2-current-context-readiness[role='status']"
    )

    assert_text(
      document,
      "#hui-c2-current-context-readiness",
      "Readiness: Read-only while one dependency is degraded"
    )

    assert_present(document, "#hui-c2-attempt-context[data-attempt-state='running']")
    assert_text(document, "#hui-c2-attempt-context-reference", "A-1042")
    assert_text(document, "#hui-c2-attempt-context-state", "Running")

    assert_present(
      document,
      "#hui-c2-maintenance-banner[role='status'][data-banner-kind='maintenance']"
    )

    assert_present(document, "#hui-c2-degraded-banner[role='alert'][data-banner-kind='degraded']")
    assert_text(document, "#hui-c2-maintenance-banner-title", "Planned maintenance")
    assert_text(document, "#hui-c2-degraded-banner-title", "Evidence service degraded")
  end

  test "provides native pagination, empty, error, action, account fallback, and footer contracts" do
    document = fixture_document()

    assert_present(document, "#hui-c2-page-header-actions[aria-label='Page actions']")
    assert_present(document, "#hui-c2-page-header-action-receipt[href$='/receipt']")
    assert_present(document, "#hui-c2-pagination-previous[rel='prev']")
    assert_present(document, "#hui-c2-pagination-page-2[aria-current='page']")
    refute_present(document, "a#hui-c2-pagination-page-2")
    assert_present(document, "#hui-c2-pagination-next[rel='next']")
    assert_present(document, "#hui-c2-pagination-summary[role='status']")

    assert_present(document, "#hui-c2-empty-state[data-empty-state='no_results']")
    assert_present(document, "#hui-c2-empty-state-action[href='/factory/attempts']")
    assert_present(document, "#hui-c2-error-summary[role='alert'][tabindex='-1']")
    assert_present(document, "#hui-c2-error-summary-error-query[href='#hui-c2-filter-query']")

    assert_present(
      document,
      "#hui-c2-error-summary-error-state[href='#hui-c2-filter-filter-state']"
    )

    assert_present(document, "#hui-c2-account-menu-invoker[type='button']")
    assert_present(document, "#hui-c2-account-menu-action-profile[href='/account']")

    assert_present(
      document,
      "#hui-c2-account-menu-fallback[aria-label='Account and session fallback']"
    )

    assert_present(document, "#hui-c2-footer-metadata-release")
    assert_present(document, "#hui-c2-footer-support[aria-label='Support']")
    assert_present(document, "#hui-c2-footer-support-accessibility[href='/accessibility']")
  end

  test "keeps IDs unique, relationships resolvable, and hostile text escaped" do
    document = fixture_document()
    ids = document |> LazyHTML.query("[id]") |> LazyHTML.attribute("id")
    rendered = LazyHTML.to_html(document)

    assert ids != []
    assert length(ids) == length(Enum.uniq(ids))

    for {selector, attribute, fragment?} <- [
          {"[aria-labelledby]", "aria-labelledby", false},
          {"[aria-describedby]", "aria-describedby", false},
          {"[aria-controls]", "aria-controls", false},
          {"label[for]", "for", false},
          {"a[href^='#']", "href", true}
        ],
        reference <- references(document, selector, attribute, fragment?) do
      assert_present(document, "##{reference}")
    end

    assert_text(document, "#hui-c2-page-header-summary", @hostile)
    assert rendered =~ "&lt;script data-shell-hostile&gt;"
    assert rendered =~ "&quot;quoted&quot;"
    refute rendered =~ "<script data-shell-hostile>"
    refute_present(document, "#hui-c2-shell script")
    refute_present(document, "#hui-c2-shell [src^='http']")
  end

  test "rejects unbounded collections, open states, unsafe destinations, and unshaped maps" do
    oversized =
      for ordinal <- 1..13 do
        %{key: "item-#{ordinal}", label: "Item #{ordinal}", href: "/items/#{ordinal}"}
      end

    assert_raise ArgumentError, ~r/exceeds the maximum of 12/, fn ->
      render_component(&AppComponents.primary_navigation/1,
        id: "bounded-navigation",
        items: oversized
      )
    end

    assert_raise ArgumentError, ~r/unsupported attempt_state/, fn ->
      render_component(&AppComponents.attempt_context/1,
        id: "invalid-attempt",
        attempt: %{
          label: "Attempt",
          reference: "A-1",
          scope_label: "Project Alpha",
          state: :invented,
          state_label: "Invented"
        }
      )
    end

    assert_raise ArgumentError, ~r/unsupported empty_state/, fn ->
      render_component(&AppComponents.empty_state/1,
        id: "invalid-empty",
        state: :invented,
        title: "Invalid",
        message: "Invalid state"
      )
    end

    assert_raise ArgumentError, ~r/supported native destination/, fn ->
      render_component(&AppComponents.primary_navigation/1,
        id: "unsafe-navigation",
        items: [%{key: "unsafe", label: "Unsafe", href: "javascript:alert(1)"}]
      )
    end

    for destination <- ["/\\outside.example/path", "/\t/outside.example/path"] do
      assert_raise ArgumentError, ~r/supported native destination/, fn ->
        render_component(&AppComponents.primary_navigation/1,
          id: "normalized-cross-origin-navigation",
          items: [%{key: "unsafe", label: "Unsafe", href: destination}]
        )
      end
    end

    assert_raise ArgumentError, ~r/application-relative form action/, fn ->
      render_component(&AppComponents.project_switcher/1,
        id: "normalized-cross-origin-form",
        form: Phoenix.Component.to_form(%{"project" => "project-alpha"}, as: :project_switcher),
        field:
          Phoenix.Component.to_form(%{"project" => "project-alpha"}, as: :project_switcher)[
            :project
          ],
        action: "/\\outside.example/switch",
        projects: [%{key: "project-alpha", value: "project-alpha", label: "Project Alpha"}]
      )
    end

    assert_raise ArgumentError, ~r/closed presentation map/, fn ->
      render_component(&AppComponents.primary_navigation/1,
        id: "authority-shaped-navigation",
        items: [
          %{
            key: "admin",
            label: "Administration",
            href: "/administration",
            permission: "admin"
          }
        ]
      )
    end
  end

  test "stays inside the qualified presentation and local-asset boundary" do
    source = File.read!(Path.join(File.cwd!(), @source_path))

    assert HypermediaUIPhaseC2.validate_product_sources([{@source_path, source}]) == []
    assert source =~ "use Phoenix.Component"
    assert source =~ "import JidoCodeWeb.CoreComponents, only: [icon: 1]"
    assert source =~ "alias JidoCodeWeb.Components.UI"
    assert source =~ "<UI."
    assert source =~ "<.icon"
    refute source =~ "~p\""
    refute source =~ "phx-"
    refute source =~ ~r/<script\b/i
    refute source =~ ~r/\son[a-z]+\s*=/i
  end

  defp fixture_document do
    render_component(&HypermediaUIPhaseC2ShellFixture.render/1, hostile_content: @hostile)
    |> LazyHTML.from_fragment()
  end

  defp references(document, selector, attribute, fragment?) do
    references =
      document
      |> LazyHTML.query(selector)
      |> LazyHTML.attribute(attribute)
      |> Enum.flat_map(&String.split/1)

    if fragment? do
      references
      |> Enum.filter(&String.starts_with?(&1, "#"))
      |> Enum.map(&String.trim_leading(&1, "#"))
    else
      references
    end
  end

  defp assert_present(document, selector) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.to_html() != "",
           "expected selector to be present: #{selector}"
  end

  defp refute_present(document, selector) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.to_html() == "",
           "expected selector to be absent: #{selector}"
  end

  defp assert_text(document, selector, expected) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim() == expected
  end
end
