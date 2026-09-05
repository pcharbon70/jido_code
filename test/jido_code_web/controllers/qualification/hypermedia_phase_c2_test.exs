defmodule JidoCodeWeb.Qualification.HypermediaPhaseC2Test do
  use JidoCodeWeb.ConnCase, async: false

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias JidoCode.Architecture.HypermediaUIPhaseC2
  alias JidoCodeWeb.Layouts
  alias JidoCodeWeb.Qualification.HypermediaPhaseC2Fixture

  setup do
    prior = Application.get_env(:jido_code, :hypermedia_qualification)

    Application.put_env(:jido_code, :hypermedia_qualification,
      enabled: true,
      allowed_hosts: ["www.example.com"]
    )

    on_exit(fn -> Application.put_env(:jido_code, :hypermedia_qualification, prior) end)
  end

  test "selects only the exact closed C2 discriminator and renders one application main", %{
    conn: conn
  } do
    document = conn |> get(~p"/__qualification/hypermedia?view=c2") |> document(200)

    assert_present(document, "#application-content-frame[data-layout-frame='content']")

    assert_present(
      document,
      "#hui-c2-qualification[data-qualification-only][data-hui-phase='C2']"
    )

    assert_present(document, "#hui-c2-shell[data-application-shell]")
    assert_present(document, "#hui-c2-masthead[data-application-masthead]")
    assert_present(document, "main#hui-c2-main[tabindex='-1']")
    assert_present(document, "#flash-group[aria-live='polite']")
    refute_present(document, "#application-shell")

    assert document |> LazyHTML.query("main") |> LazyHTML.to_html() |> count_elements("main") == 1
    assert document |> LazyHTML.query("h1") |> LazyHTML.to_html() |> count_elements("h1") == 1

    unknown = build_conn() |> get(~p"/__qualification/hypermedia?view=C2") |> document(200)
    assert_present(unknown, "#hui-b3-consumer")
    refute_present(unknown, "#hui-c2-qualification")
  end

  test "composes the shell hierarchy while omitting an inaccessible destination", %{conn: conn} do
    fixture = HypermediaPhaseC2Fixture.composition()
    document = conn |> get(~p"/__qualification/hypermedia?view=c2") |> document(200)

    for selector <- [
          "#hui-c2-primary-navigation[aria-label='Primary navigation']",
          "#hui-c2-project-switcher-form[method='get']",
          "#hui-c2-breadcrumbs[aria-label='Breadcrumbs']",
          "#hui-c2-attempt-context[data-attempt-state='running']",
          "#hui-c2-utility-navigation[aria-label='Utility navigation']",
          "#hui-c2-account-menu",
          "#hui-c2-responsive-navigation details",
          "#hui-c2-current-context[data-readiness-state='limited']",
          "#hui-c2-page-header-title[tabindex='-1']",
          "#hui-c2-filter-search-form[method='get'][role='search']",
          "#hui-c2-application-pagination",
          "#hui-c2-empty-state[data-empty-state='no_results']",
          "#hui-c2-error-summary[role='alert'][tabindex='-1']",
          "#hui-c2-maintenance-banner[data-banner-kind='maintenance']",
          "#hui-c2-degraded-banner[data-banner-kind='degraded']",
          "#hui-c2-footer[data-application-footer]"
        ] do
      assert_present(document, selector)
    end

    refute LazyHTML.text(document) =~ fixture.omitted_destination
    refute_present(document, "a[href='/administration']")
  end

  test "renders every canonical state and clears every protected collection", %{conn: conn} do
    fixture = HypermediaPhaseC2Fixture.composition()
    document = conn |> get(~p"/__qualification/hypermedia?view=c2") |> document(200)

    assert_present(document, "#hui-c2-state-matrix")

    for state <- fixture.states do
      state_name = Atom.to_string(state)

      assert_present(
        document,
        "#hui-c2-state-#{state_name}[data-projection-state='#{state_name}'][role='status']"
      )
    end

    assert document
           |> LazyHTML.query("#hui-c2-state-matrix [data-projection-status]")
           |> LazyHTML.attribute("id")
           |> length() == 10

    refute_present(document, "#hui-c2-state-unauthorized-retry")

    for state <- fixture.protected_states do
      state_name = Atom.to_string(state)
      root = "#hui-c2-protected-#{state_name}"
      assert_present(document, "#{root}[data-projection-state='#{state_name}']")
      refute_present(document, "#{root} [data-fleet-row]")
      refute_present(document, "#{root} [data-fleet-card]")
    end

    refute LazyHTML.text(LazyHTML.query(document, "#hui-c2-protected-clearing")) =~
             fixture.protected_value
  end

  test "composes bounded projection, collection, attempt, and provenance contracts", %{conn: conn} do
    document = conn |> get(~p"/__qualification/hypermedia?view=c2") |> document(200)

    for selector <- [
          "#hui-c2-trust[data-projection-trust][data-projection-state='stale']",
          "#hui-c2-attention[data-attention-list][data-projection-state='truncated']",
          "#hui-c2-attention-bounded-notice[data-bounded-notice]",
          "#hui-c2-health[data-health-summary][data-projection-state='truncated']",
          "#hui-c2-health-bounded-notice[data-bounded-notice]",
          "#hui-c2-fleet[data-fleet-project-collection]",
          "#hui-c2-fleet-wide[data-collection-layout='table']",
          "#hui-c2-fleet-cards[data-collection-layout='cards']",
          "#hui-c2-fleet-project-heading[aria-sort='ascending']",
          "#hui-c2-fleet-pagination-summary",
          "#hui-c2-attempt-summary[data-attempt-summary]",
          "#hui-c2-attempt-summary-lifecycle[data-lifecycle-rail]",
          "#hui-c2-attempt-summary-outcomes[data-outcome-rail]",
          "#hui-c2-attempt-summary-budget[data-budget-meter]",
          "#hui-c2-readiness-badge[data-readiness-badge]",
          "#hui-c2-evidence-link[data-evidence-link][data-evidence-kind='receipt']"
        ] do
      assert_present(document, selector)
    end

    assert document
           |> LazyHTML.query("#hui-c2-attention [data-attention-item]")
           |> LazyHTML.attribute("id")
           |> length() == 24

    assert document
           |> LazyHTML.query("#hui-c2-health [data-health-item]")
           |> LazyHTML.attribute("id")
           |> length() == 12
  end

  test "renders all seventeen facade primitives with native form and overlay semantics", %{
    conn: conn
  } do
    document = conn |> get(~p"/__qualification/hypermedia?view=c2") |> document(200)

    for selector <- [
          "form#hui-c2-primitive-form[method='get']",
          "#hui-c2-core-input[name='catalog_label']",
          "#hui-c2-field-input[data-shadcn-ui-input]",
          "#hui-c2-catalog-select[data-shadcn-ui-select]",
          "#hui-c2-catalog-checkbox[type='checkbox']",
          "#hui-c2-catalog-radio[data-shadcn-ui-radio-group]",
          "#hui-c2-primitive-submit[type='submit']",
          "#hui-c2-catalog-link[data-ui-link]",
          "#hui-c2-catalog-badge[data-shadcn-ui]",
          "#hui-c2-catalog-table table",
          "#hui-c2-disclosure details[open] > summary",
          "#hui-c2-dialog dialog",
          "#hui-c2-menu [data-shadcn-ui-dropdown-action]",
          "#hui-c2-tooltip [role='tooltip']",
          "#hui-c2-toast[role='status']",
          "#hui-c2-status[role='status']",
          "#hui-c2-skeleton[data-shadcn-ui-skeleton][aria-hidden='true']"
        ] do
      assert_present(document, selector)
    end

    assert_present(
      document,
      "#hui-c2-dialog-invoker[command='show-modal'][commandfor='hui-c2-dialog-surface']"
    )

    assert_present(document, "#hui-c2-dialog-close[command='close']")

    assert_present(
      document,
      "#hui-c2-dialog-fallback[data-enhancement-fallback='dialog'] > summary"
    )

    assert_present(
      document,
      "#hui-c2-menu-fallback[data-enhancement-fallback='popover'] #hui-c2-menu-fallback-link[href='#hui-c2-state-matrix']"
    )

    refute_present(document, "#hui-c2-menu [role='menu']")
  end

  test "keeps every qualification form and navigation control useful without JavaScript", %{
    conn: conn
  } do
    document = conn |> get(~p"/__qualification/hypermedia?view=c2") |> document(200)

    for form_id <- ~w[
          hui-c2-project-switcher-form
          hui-c2-filter-search-form
          hui-c2-primitive-form
        ] do
      assert_present(
        document,
        "form##{form_id}[method='get'][action='/__qualification/hypermedia']"
      )
    end

    assert_present(
      document,
      "#hui-c2-project-switcher-select[name='view'] option[value='c2'][selected]"
    )

    assert_present(document, "#hui-c2-filter-search-query[name='q']")

    assert_present(
      document,
      "#hui-c2-filter-search-filter-view[name='view'] option[value='c2'][selected]"
    )

    assert_present(document, "#hui-c2-catalog-view[name='view'] option[value='c2'][selected]")
    assert_present(document, "#hui-c2-shell-skip-link[href='#hui-c2-main']")
    assert_present(document, "#application-theme-toggle[role='group'][aria-label='Appearance']")
    assert_present(document, "#application-theme-controls[hidden]")
    refute_present(document, "#hui-c2-qualification [data-on\\:click]")
    refute_present(document, "#hui-c2-qualification [phx-click]")

    filtered =
      build_conn()
      |> get(
        "/__qualification/hypermedia?" <>
          URI.encode_query(%{
            "q" => "native qualification",
            "state" => "stale",
            "view" => "c2"
          })
      )
      |> document(200)

    assert_present(filtered, "#hui-c2-qualification")
    assert_present(filtered, "#hui-c2-filter-search-query[value='native qualification']")

    assert_present(
      filtered,
      "#hui-c2-filter-search-filter-state option[value='stale'][selected]"
    )

    assert_present(
      filtered,
      "#hui-c2-native-result[data-query='native qualification'][data-selected-state='stale']"
    )

    assert_present(filtered, "#hui-c2-native-projection[data-projection-state='stale']")

    paged_sorted =
      build_conn()
      |> get(
        "/__qualification/hypermedia?" <>
          URI.encode_query(%{
            "direction" => "descending",
            "page" => "1",
            "sort" => "health",
            "view" => "c2"
          })
      )
      |> document(200)

    assert_present(
      paged_sorted,
      "#hui-c2-native-result[data-page='1'][data-sort='health'][data-direction='descending']"
    )

    assert_present(paged_sorted, "#hui-c2-application-pagination-page-1[aria-current='page']")
    refute_present(paged_sorted, "#hui-c2-application-pagination-previous")
    assert_present(paged_sorted, "#hui-c2-fleet-health-heading[aria-sort='descending']")
    assert_text(paged_sorted, "#hui-c2-fleet-pagination-summary", "page 1 of 3")

    primitive =
      build_conn()
      |> get(
        "/__qualification/hypermedia?" <>
          URI.encode_query(%{
            "catalog_label" => "native primitive form",
            "density" => "compact",
            "include_archived" => "false",
            "mode" => "details",
            "qualified_label" => "bounded field",
            "view" => "c2"
          })
      )
      |> document(200)

    assert_present(primitive, "#hui-c2-core-input[value='native primitive form']")
    assert_present(primitive, "#hui-c2-field-input[value='bounded field']")
    assert_present(primitive, "#hui-c2-catalog-select option[value='compact'][selected]")
    assert_present(primitive, "#hui-c2-catalog-radio input[value='details'][checked]")
    refute_present(primitive, "#hui-c2-catalog-checkbox[checked]")

    closed =
      build_conn()
      |> get(
        "/__qualification/hypermedia?" <>
          URI.encode_query(%{
            "direction" => "sideways",
            "page" => "999999999999999999999999999",
            "q" => String.duplicate("q", 120),
            "sort" => "secret",
            "state" => "secret",
            "view" => "c2"
          })
      )
      |> document(200)

    assert_present(
      closed,
      "#hui-c2-native-result[data-selected-state='ready'][data-page='2'][data-sort='project'][data-direction='ascending']"
    )

    assert closed |> LazyHTML.query("#hui-c2-filter-search-query") |> LazyHTML.attribute("value") ==
             [String.duplicate("q", 80)]
  end

  test "renders the server-first appearance and suppresses inert no-script controls", %{
    conn: conn
  } do
    document =
      conn
      |> put_req_cookie("jido_appearance", "dark")
      |> put_req_cookie("jido_resolved_theme", "dark")
      |> get(~p"/__qualification/hypermedia?view=c2")
      |> document(200)

    assert_present(document, "html[data-appearance='dark'][data-theme='dark']")
    assert_present(document, "#application-theme-controls[hidden]")
    assert_present(document, "#application-theme-dark[aria-pressed='true']")
    assert_present(document, "#application-theme-light[aria-pressed='false']")
    assert_text(document, "#application-theme-current", "Current appearance: Dark")
  end

  test "escapes hostile content, bounds long labels, and preserves unique ID relationships", %{
    conn: conn
  } do
    fixture = HypermediaPhaseC2Fixture.composition()
    document = conn |> get(~p"/__qualification/hypermedia?view=c2") |> document(200)
    rendered = LazyHTML.to_html(document)

    assert LazyHTML.attribute(LazyHTML.query(document, "#hui-c2-core-input"), "value") == [
             fixture.hostile_content
           ]

    assert LazyHTML.text(LazyHTML.query(document, "#hui-c2-attention-card-1-title")) ==
             fixture.hostile_content

    assert rendered =~ "&lt;script"
    refute_present(document, "#hui-c2-hostile-script")
    refute_present(document, "#hui-c2-qualification img[src='x']")

    page_summary = LazyHTML.text(LazyHTML.query(document, "#hui-c2-page-header-summary"))
    assert String.trim(page_summary) == String.trim(fixture.long_content)
    assert String.length(page_summary) > 600

    ids = document |> LazyHTML.query("[id]") |> LazyHTML.attribute("id")
    assert ids != []

    duplicates =
      ids
      |> Enum.frequencies()
      |> Enum.filter(fn {_id, count} -> count > 1 end)

    assert duplicates == []

    assert_relationships_resolve(document, ids, "for")
    assert_relationships_resolve(document, ids, "aria-labelledby")
    assert_relationships_resolve(document, ids, "aria-describedby")
    assert_relationships_resolve(document, ids, "aria-controls")
    assert_relationships_resolve(document, ids, "commandfor")
    assert_relationships_resolve(document, ids, "popovertarget")
  end

  test "keeps local assets, CSP, and static presentation source boundaries", %{conn: conn} do
    conn = get(conn, ~p"/__qualification/hypermedia?view=c2")
    document = document(conn, 200)
    [policy] = get_resp_header(conn, "content-security-policy")

    refute policy =~ "unsafe-inline"
    refute policy =~ "unsafe-eval"
    refute policy =~ "https:"
    refute_present(document, "script:not([src])")

    asset_urls =
      LazyHTML.attribute(LazyHTML.query(document, "script[src]"), "src") ++
        LazyHTML.attribute(LazyHTML.query(document, "link[rel='stylesheet'][href]"), "href")

    assert asset_urls != []

    assert Enum.all?(asset_urls, fn url ->
             uri = URI.parse(url)
             is_nil(uri.host) or uri.host == "localhost"
           end)

    root = File.cwd!()

    sources =
      for path <- [
            "lib/jido_code_web/components/layouts.ex",
            "lib/jido_code_web/qualification/hypermedia_phase_c2_fixture.ex",
            "lib/jido_code_web/controllers/qualification/hypermedia_controller.ex",
            "lib/jido_code_web/controllers/qualification/hypermedia_html/phase_c2.html.heex"
          ] do
        {path, File.read!(Path.join(root, path))}
      end

    assert HypermediaUIPhaseC2.validate_product_sources(sources) == []

    presentation_source =
      File.read!(
        Path.join(
          root,
          "lib/jido_code_web/controllers/qualification/hypermedia_html/phase_c2.html.heex"
        )
      )

    for forbidden <- ["<script", "http://", "https://", "data-on:", "phx-click"] do
      refute presentation_source =~ forbidden
    end
  end

  test "rejects an open-ended outer layout frame" do
    assert_raise ArgumentError, ~r/unsupported layout frame/, fn ->
      render_component(&Layouts.app/1,
        flash: %{},
        frame: :caller_selected,
        inner_block: []
      )
    end
  end

  defp assert_relationships_resolve(document, ids, attribute) do
    document
    |> LazyHTML.query("[#{attribute}]")
    |> LazyHTML.attribute(attribute)
    |> Enum.flat_map(&String.split/1)
    |> Enum.each(fn reference ->
      assert reference in ids,
             "#{attribute} reference #{inspect(reference)} does not resolve to a unique page ID"
    end)
  end

  defp document(conn, status), do: conn |> html_response(status) |> LazyHTML.from_document()

  defp count_elements(html, tag), do: length(Regex.scan(~r/<#{tag}(?:\s|>)/, html))

  defp assert_present(document, selector) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.to_html() != "",
           "expected #{selector} to be present"
  end

  defp refute_present(document, selector) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.to_html() == "",
           "expected #{selector} to be absent"
  end

  defp assert_text(document, selector, expected) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.text() =~ expected
  end
end
