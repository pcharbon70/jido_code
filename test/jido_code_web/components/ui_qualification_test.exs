defmodule JidoCodeWeb.Components.UIQualificationTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias JidoCodeWeb.HypermediaUIPhaseB2Fixture

  test "renders the representative facade with native form and navigation fallbacks" do
    html =
      render_component(&HypermediaUIPhaseB2Fixture.render/1,
        hostile_content: ~s|<script data-hostile>unsafe()</script>|
      )

    document = LazyHTML.from_fragment(html)

    for selector <- [
          "#hui-b2-form",
          "#probe_native_name",
          "#probe_qualified_name",
          "#hui-b2-submit[data-shadcn-ui]",
          "#hui-b2-link[href='/']",
          "#hui-b2-badge[data-shadcn-ui]",
          "#hui-b2-table table",
          "#hui-b2-disclosure details",
          "#hui-b2-dialog dialog",
          "#hui-b2-status[role='status']"
        ] do
      assert document |> LazyHTML.query(selector) |> LazyHTML.to_html() != ""
    end

    assert html =~ ~s(data-on:input="$draft = evt.target.value")
    assert html =~ ~s(data-on:click="$pending = true")
    assert html =~ "&lt;script data-hostile&gt;unsafe()&lt;/script&gt;"
    refute html =~ "<script data-hostile>"
  end

  test "rejects open-ended facade variants" do
    assert_raise ArgumentError, ~r/unsupported variant/, fn ->
      render_component(&JidoCodeWeb.Components.UI.button/1,
        id: "bad-button",
        variant: "caller-selected-class",
        inner_block: [%{inner_block: fn _assigns, _arg -> "Bad" end}]
      )
    end
  end

  test "keeps the exact local stylesheet and synchronized theme contract" do
    root = File.cwd!()
    stylesheet = File.read!(ShadcnUI.stylesheet_path())
    app_css = File.read!(Path.join(root, "assets/css/app.css"))
    theme = File.read!(Path.join(root, "assets/js/theme.js"))

    root_layout =
      File.read!(Path.join(root, "lib/jido_code_web/components/layouts/root.html.heex"))

    assert Base.encode16(:crypto.hash(:sha256, stylesheet), case: :lower) ==
             "ed0768e9582e980f3fd1b3ca0076afc573fc269514f527aef9dc942d1f8e9f41"

    assert app_css =~ ~s(@import "../../deps/shadcn_ui/priv/static/shadcn_ui.css";)
    assert app_css =~ "@media (prefers-reduced-motion: reduce)"
    assert app_css =~ "@media (forced-colors: active)"
    assert app_css =~ "@media print"
    refute app_css =~ "@apply"
    assert theme =~ ~s(root.setAttribute("data-shadcn-theme")

    assert root_layout =~
             ~s|data-appearance={JidoCodeWeb.Layouts.theme_attributes(@conn).appearance}|

    assert root_layout =~ ~s|data-theme={JidoCodeWeb.Layouts.theme_attributes(@conn).theme}|

    assert root_layout =~
             ~s|data-shadcn-theme={JidoCodeWeb.Layouts.theme_attributes(@conn).shadcn_theme}|
  end
end
