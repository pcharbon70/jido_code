defmodule JidoCodeWeb.Components.UIPhaseC2Test do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias JidoCodeWeb.Components.UI
  alias JidoCodeWeb.HypermediaUIPhaseC2PrimitivesFixture
  alias JidoCodeWeb.Layouts

  @hostile ~s|<script data-hostile>window.unsafe()</script><b>& "quoted"</b>|

  test "renders every supported primitive behind the application facade" do
    document = fixture_document()

    for selector <- [
          "#hui-c2-form[action='/qualification-only'][method='post']",
          "#hui-c2-native-input[name='primitive[native_name]']",
          "#hui-c2-field-input[data-shadcn-ui-input]",
          "#hui-c2-select[data-shadcn-ui-select]",
          "#hui-c2-checkbox[type='checkbox']",
          "#hui-c2-radio-group[data-shadcn-ui-radio-group]",
          "#hui-c2-submit[type='submit'][data-shadcn-ui]",
          "#hui-c2-link[href='/qualification-only?view=primitives']",
          "#hui-c2-badge[data-shadcn-ui]",
          "#hui-c2-table table",
          "#hui-c2-disclosure details",
          "#hui-c2-dialog dialog",
          "#hui-c2-menu [data-shadcn-ui-dropdown-action]",
          "#hui-c2-tooltip [role='tooltip']",
          "#hui-c2-toast[role='status']",
          "#hui-c2-status[role='status']",
          "#hui-c2-skeleton[data-shadcn-ui-skeleton]"
        ] do
      assert_present(document, selector)
    end
  end

  test "preserves native form, navigation, disclosure, dialog, menu, and fallback semantics" do
    document = fixture_document()

    assert_present(document, "#hui-c2-form input[name='_csrf_token']")
    assert_present(document, "#hui-c2-native-input[required]")
    assert_present(document, "#hui-c2-select option[value='project-alpha'][selected]")
    assert_present(document, "#hui-c2-checkbox + label[for='hui-c2-checkbox']")
    assert_present(document, "fieldset#hui-c2-radio-group")
    assert_present(document, "#hui-c2-radio-group input[type='radio'][value='review'][checked]")
    assert_present(document, "#hui-c2-native-navigation[aria-label='Primitive examples'] a[href]")
    assert_present(document, "#hui-c2-disclosure details[open] > summary")

    assert_present(
      document,
      "#hui-c2-dialog-invoker[command='show-modal'][commandfor='hui-c2-dialog-surface']"
    )

    assert_present(
      document,
      "#hui-c2-dialog-surface[aria-labelledby='hui-c2-dialog-title'][aria-describedby='hui-c2-dialog-description']"
    )

    assert_present(document, "#hui-c2-dialog-close[command='close']")
    assert_present(document, "#hui-c2-dialog-fallback[href='#hui-c2-dialog-copy']")

    assert_present(
      document,
      "#hui-c2-menu-action-details[href='/qualification-only?view=details']"
    )

    assert_present(document, "#hui-c2-menu-action-reset[type='reset'][form='hui-c2-form']")
    assert_present(document, "#hui-c2-menu-fallback[href='/qualification-only?view=details']")
    refute_present(document, "#hui-c2-menu [role='menu']")

    assert_present(
      document,
      "#hui-c2-tooltip-invoker[aria-describedby='hui-c2-tooltip-description']"
    )
  end

  test "keeps deterministic unique IDs and complete field associations" do
    document = fixture_document()
    ids = document |> LazyHTML.query("[id]") |> LazyHTML.attribute("id")

    assert ids != []
    assert length(ids) == length(Enum.uniq(ids))

    assert_present(document, "label[for='hui-c2-field-input']#hui-c2-field-input-label")

    assert_described_by(
      document,
      "#hui-c2-field-input",
      ~w[hui-c2-field-input-help hui-c2-field-input-error-1]
    )

    assert_present(document, "label[for='hui-c2-select']#hui-c2-select-label")

    assert_described_by(
      document,
      "#hui-c2-select",
      ~w[hui-c2-select-help hui-c2-select-error-1]
    )

    assert_present(document, "label[for='hui-c2-checkbox']#hui-c2-checkbox-label")

    assert_described_by(
      document,
      "#hui-c2-checkbox",
      ~w[hui-c2-checkbox-help hui-c2-checkbox-error-1]
    )

    assert_present(document, "#hui-c2-radio-group > legend#hui-c2-radio-group-label")

    assert_described_by(
      document,
      "#hui-c2-radio-group",
      ~w[hui-c2-radio-group-help hui-c2-radio-group-error-1]
    )

    assert_present(document, "#hui-c2-radio-group-option-c3RyaW5nOm9ic2VydmU")
    assert_present(document, "#hui-c2-radio-group-option-c3RyaW5nOnJldmlldw")
    assert_present(document, "#hui-c2-table caption")
    assert_present(document, "#hui-c2-table th[scope='col']")
    assert_present(document, "#hui-c2-table-row th[scope='row']")
    assert_present(document, "#hui-c2-loading-region[role='status'][aria-label]")
    assert_present(document, "#hui-c2-skeleton[aria-hidden='true']")
  end

  test "escapes hostile content in text and attribute-bearing primitives" do
    document = fixture_document()
    rendered = LazyHTML.to_html(document)

    assert LazyHTML.text(LazyHTML.query(document, "#hui-c2-hostile-content")) == @hostile
    assert LazyHTML.attribute(LazyHTML.query(document, "#hui-c2-link"), "title") == [@hostile]
    assert rendered =~ "&lt;script data-hostile&gt;"
    assert rendered =~ "&quot;quoted&quot;"
    refute rendered =~ "<script data-hostile>"
    refute_present(document, "#hui-c2-primitives script")
  end

  test "rejects open-ended button and badge variants" do
    assert_raise ArgumentError, ~r/unsupported variant/, fn ->
      render_component(&UI.button/1,
        id: "hui-c2-invalid-button",
        variant: "caller-status-color",
        inner_block: slot("Invalid button")
      )
    end

    assert_raise ArgumentError, ~r/unsupported variant/, fn ->
      render_component(&UI.badge/1,
        id: "hui-c2-invalid-badge",
        variant: "caller-status-color",
        inner_block: slot("Invalid badge")
      )
    end

    assert_raise ArgumentError, ~r/unsupported size/, fn ->
      render_component(&UI.button/1,
        id: "hui-c2-invalid-size",
        size: "unbounded",
        inner_block: slot("Invalid size")
      )
    end
  end

  test "resolves presentation-only theme cookies through a closed server-first contract" do
    assert Layouts.theme_attributes(conn_with_cookies(%{})) == %{
             appearance: "system",
             theme: nil,
             shadcn_theme: nil
           }

    assert Layouts.theme_attributes(
             conn_with_cookies(%{
               "jido_appearance" => "system",
               "jido_resolved_theme" => "dark"
             })
           ) == %{appearance: "system", theme: "dark", shadcn_theme: "dark"}

    assert Layouts.theme_attributes(
             conn_with_cookies(%{
               "jido_appearance" => "dark",
               "jido_resolved_theme" => "light"
             })
           ) == %{appearance: "dark", theme: "dark", shadcn_theme: "dark"}

    assert Layouts.theme_attributes(
             conn_with_cookies(%{
               "jido_appearance" => "admin",
               "jido_resolved_theme" => "ultraviolet"
             })
           ) == %{appearance: "system", theme: nil, shadcn_theme: nil}
  end

  test "pins theme persistence, synchronized root attributes, tokens, and accessibility modes" do
    root = File.cwd!()
    css = File.read!(Path.join(root, "assets/css/app.css"))
    theme = File.read!(Path.join(root, "assets/js/theme.js"))

    root_layout =
      File.read!(Path.join(root, "lib/jido_code_web/components/layouts/root.html.heex"))

    for token <- ~w[
          --font-sans --font-mono --text-caption --text-body --text-title
          --space-control --space-panel --space-section --layout-content
          --density-row --density-row-compact --elevation-panel --elevation-overlay
          --frame-border --frame-focus --status-healthy --status-attention --status-failure
          --chart-series-1 --chart-series-2 --chart-series-3 --chart-grid
          --code-surface --diff-added --diff-removed --diff-changed --touch-target
        ] do
      assert css =~ token
    end

    for mode <- [
          "@media (prefers-reduced-motion: reduce)",
          "@media (forced-colors: active)",
          "@media (pointer: coarse)",
          "@media (max-width: 40rem)",
          "@media print",
          ~s([dir="rtl"])
        ] do
      assert css =~ mode
    end

    refute css =~ "@apply"
    refute css =~ ~r/@import\s+(?:url\()?['\"]?https?:\/\//i
    assert theme =~ ~s(export const THEME_COOKIE = "jido_appearance")
    assert theme =~ ~s(export const RESOLVED_THEME_COOKIE = "jido_resolved_theme")
    assert theme =~ "SameSite=Lax"
    assert theme =~ ~s|root.setAttribute("data-theme", resolved)|
    assert theme =~ ~s|root.setAttribute("data-shadcn-theme", resolved)|

    assert root_layout =~
             ~s|data-appearance={JidoCodeWeb.Layouts.theme_attributes(@conn).appearance}|

    assert root_layout =~ ~s|data-theme={JidoCodeWeb.Layouts.theme_attributes(@conn).theme}|

    assert root_layout =~
             ~s|data-shadcn-theme={JidoCodeWeb.Layouts.theme_attributes(@conn).shadcn_theme}|

    refute root_layout =~ ~r/<script(?:\s|>)/i
  end

  test "theme controls expose explicit accessible names and pressed state" do
    document =
      render_component(&Layouts.theme_toggle/1, %{})
      |> LazyHTML.from_fragment()

    assert_present(document, "#application-theme-toggle[role='group'][aria-label='Appearance']")

    for {id, value, label} <- [
          {"application-theme-system", "system", "Use system theme"},
          {"application-theme-light", "light", "Use light theme"},
          {"application-theme-dark", "dark", "Use dark theme"}
        ] do
      assert_present(
        document,
        "##{id}[type='button'][data-theme-choice][data-phx-theme='#{value}'][aria-label='#{label}'][aria-pressed='false']"
      )
    end
  end

  defp fixture_document do
    render_component(&HypermediaUIPhaseC2PrimitivesFixture.render/1, %{
      hostile_content: @hostile
    })
    |> LazyHTML.from_fragment()
  end

  defp assert_present(document, selector) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.to_html() != "",
           "expected selector to be present: #{selector}"
  end

  defp refute_present(document, selector) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.to_html() == "",
           "expected selector to be absent: #{selector}"
  end

  defp assert_described_by(document, selector, expected_ids) do
    described_by =
      document
      |> LazyHTML.query(selector)
      |> LazyHTML.attribute("aria-describedby")
      |> List.first()
      |> String.split()

    assert MapSet.new(described_by) == MapSet.new(expected_ids)
  end

  defp slot(text), do: [%{inner_block: fn _assigns, _argument -> text end}]

  defp conn_with_cookies(cookies) do
    cookie_header = Enum.map_join(cookies, "; ", fn {key, value} -> "#{key}=#{value}" end)

    Plug.Test.conn(:get, "/")
    |> Plug.Conn.put_req_header("cookie", cookie_header)
  end
end
