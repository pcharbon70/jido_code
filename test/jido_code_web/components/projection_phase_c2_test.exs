defmodule JidoCodeWeb.Components.ProjectionPhaseC2Test do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias JidoCodeWeb.Components.Projection
  alias JidoCodeWeb.HypermediaUIPhaseC2ProjectionFixture, as: Fixture

  @canonical_states [
    :ready,
    :empty,
    :stale,
    :incomplete,
    :contradicted,
    :truncated,
    :unauthorized,
    :unavailable,
    :maintenance,
    :recovery
  ]
  @hostile ~s|<script data-c2-projection-hostile>window.unsafe()</script><b>& "quoted"</b>|

  test "pins ten canonical states and normalizes only the documented aliases" do
    assert Projection.canonical_states() == @canonical_states

    for state <- @canonical_states do
      assert Projection.normalize_state(state) == {:ok, state}
      assert Projection.normalize_state(Atom.to_string(state)) == {:ok, state}
    end

    for {alias_name, canonical} <- [
          partial: :incomplete,
          contradiction: :contradicted,
          concealed: :unauthorized,
          denied: :unauthorized,
          unconfigured: :unavailable
        ] do
      assert Projection.normalize_state(alias_name) == {:ok, canonical}
      assert Projection.normalize_state(Atom.to_string(alias_name)) == {:ok, canonical}

      document =
        render_component(&Projection.projection_status/1,
          id: "alias-#{alias_name}",
          state: alias_name
        )
        |> LazyHTML.from_fragment()

      assert LazyHTML.attribute(
               LazyHTML.query(document, "#alias-#{alias_name}"),
               "data-projection-state"
             ) == [Atom.to_string(canonical)]

      refute_present(document, "[data-projection-state='#{alias_name}']")
    end

    assert Projection.normalize_state(:loading) == {:error, :unsupported_projection_state}
    assert Projection.normalize_state(:error) == {:error, :unsupported_projection_state}
    assert Projection.normalize_state("caller-state") == {:error, :unsupported_projection_state}

    assert_raise ArgumentError, ~r/unsupported projection state/, fn ->
      render_component(&Projection.projection_status/1,
        id: "unsupported-state",
        state: :loading
      )
    end
  end

  test "renders the complete stateless projection and factory composite catalog" do
    document = fixture_document(:ready)

    for selector <- [
          "#hui-c2-trust[data-projection-trust][data-projection-state='ready']",
          "#hui-c2-trust-metadata",
          "#hui-c2-attention[data-attention-list]",
          "#hui-c2-attention-card-1[data-attention-item]",
          "#hui-c2-health[data-health-summary]",
          "#hui-c2-health-item-1[data-health-item]",
          "#hui-c2-fleet[data-fleet-project-collection]",
          "#hui-c2-fleet-table table",
          "#hui-c2-fleet-table-row-1[data-fleet-row]",
          "#hui-c2-fleet-card-1[data-fleet-card]",
          "#hui-c2-attempt[data-attempt-summary]",
          "#hui-c2-attempt-lifecycle[data-lifecycle-rail]",
          "#hui-c2-attempt-outcomes[data-outcome-rail]",
          "#hui-c2-attempt-budget[data-budget-meter]",
          "meter#hui-c2-attempt-budget-meter",
          "#hui-c2-evidence-link[data-evidence-link]",
          "#hui-c2-receipt-link[data-evidence-kind='receipt']",
          "#hui-c2-readiness[data-readiness-badge]",
          "#hui-c2-fleet-pagination[data-pagination]"
        ] do
      assert_present(document, selector)
    end
  end

  test "protected projection states clear every protected row and field" do
    for state <- [:unauthorized, :unavailable, :maintenance, :recovery] do
      secret = "secret-#{state}-row-label"

      html =
        render_component(&Fixture.protected/1,
          state: state,
          secret: secret
        )

      document = LazyHTML.from_fragment(html)

      refute html =~ secret
      refute_present(document, "[data-attention-item]")
      refute_present(document, "[data-health-item]")
      refute_present(document, "[data-fleet-row]")
      refute_present(document, "[data-fleet-card]")
      refute_present(document, "[data-attempt-details]")
      refute_present(document, "[data-rail-item]")
      refute_present(document, "[data-outcome-item]")
      refute_present(document, "#hui-c2-protected-budget meter")
      refute_present(document, "#hui-c2-protected-evidence[href]")
      refute_present(document, "#hui-c2-protected-trust-metadata")

      assert LazyHTML.text(LazyHTML.query(document, "#hui-c2-protected-evidence")) =~
               "Evidence unavailable"

      refute LazyHTML.text(LazyHTML.query(document, "#hui-c2-protected-evidence")) =~
               "Receipt unavailable"

      assert_present(
        document,
        "#hui-c2-protected-attention[data-projection-state='#{state}']"
      )

      assert_present(
        document,
        "#hui-c2-protected-fleet-status[data-projection-state='#{state}']"
      )
    end
  end

  test "concealed and denied aliases share the canonical unauthorized exterior" do
    concealed = render_component(&Fixture.protected/1, state: :concealed, secret: "concealed-a")
    denied = render_component(&Fixture.protected/1, state: :denied, secret: "concealed-b")

    concealed_document = LazyHTML.from_fragment(concealed)
    denied_document = LazyHTML.from_fragment(denied)

    assert LazyHTML.text(LazyHTML.query(concealed_document, "#hui-c2-protected-attention-status")) ==
             LazyHTML.text(LazyHTML.query(denied_document, "#hui-c2-protected-attention-status"))

    assert_present(concealed_document, "[data-projection-state='unauthorized']")
    assert_present(denied_document, "[data-projection-state='unauthorized']")
    refute concealed =~ "concealed-a"
    refute denied =~ "concealed-b"
  end

  test "hostile and long labels remain escaped and bounded" do
    document = fixture_document(:hostile)
    html = LazyHTML.to_html(document)

    assert html =~ "&lt;script data-c2-projection-hostile&gt;"
    assert html =~ "&quot;quoted&quot;"
    refute html =~ "<script data-c2-projection-hostile>"
    refute_present(document, "script")

    trust_title = document |> LazyHTML.query("#hui-c2-trust-title") |> LazyHTML.text()
    assert String.contains?(trust_title, "<script data-c2-projection-hostile>")
    assert String.ends_with?(trust_title, "…")
    assert String.length(trust_title) <= Projection.limits().label_graphemes

    attention_title =
      document
      |> LazyHTML.query("#hui-c2-attention-card-1-title")
      |> LazyHTML.text()

    assert String.contains?(attention_title, "<script data-c2-projection-hostile>")
    assert String.length(attention_title) <= Projection.limits().label_graphemes
  end

  test "the public attention card boundary normalizes hostile, missing, and unsafe fields" do
    hostile_document =
      render_component(&Projection.attention_card/1,
        id: "direct-attention-card",
        item: %{
          severity: :high,
          title: @hostile <> String.duplicate(" long", 80),
          reason: @hostile,
          scope_label: @hostile,
          destination_href: "javascript:alert(1)",
          evidence_href: "/\\outside.example/evidence"
        }
      )
      |> LazyHTML.from_fragment()

    hostile_html = LazyHTML.to_html(hostile_document)
    refute hostile_html =~ "<script data-c2-projection-hostile>"
    refute_present(hostile_document, "a")

    title =
      hostile_document
      |> LazyHTML.query("#direct-attention-card-title")
      |> LazyHTML.text()

    assert String.ends_with?(title, "…")
    assert String.length(title) <= Projection.limits().label_graphemes

    missing_document =
      render_component(&Projection.attention_card/1,
        id: "direct-missing-attention-card",
        item: %{}
      )
      |> LazyHTML.from_fragment()

    assert LazyHTML.text(missing_document) =~ "Attention item"
    assert LazyHTML.text(missing_document) =~ "No additional detail is available."
  end

  test "missing shaped fields render safe explicit fallback text" do
    document = fixture_document(:missing)
    text = LazyHTML.text(document)

    assert text =~ "Projection trust"
    assert text =~ "Attention item"
    assert text =~ "No additional detail is available."
    assert text =~ "Health metric"
    assert text =~ "Project not provided"
    assert text =~ "Attempt details unavailable"
  end

  test "stale projections retain bounded rows while unavailable errors clear them" do
    stale = fixture_document(:stale)
    unavailable = fixture_document(:error)

    assert_present(stale, "#hui-c2-attention[data-projection-state='stale']")
    assert_present(stale, "[data-attention-item]")
    assert_present(stale, "[data-fleet-row]")
    assert_present(stale, "#hui-c2-attention-status-retry[href='?retry=attention']")

    assert_present(unavailable, "#hui-c2-attention[data-projection-state='unavailable']")
    refute_present(unavailable, "[data-attention-item]")
    refute_present(unavailable, "[data-fleet-row]")
    refute_present(unavailable, "[data-attempt-details]")
  end

  test "high-count input is capped without exposing an unbounded total" do
    document = fixture_document(:high_count)
    limits = Projection.limits()

    assert count(document, "[data-attention-item]") == limits.attention_items
    assert count(document, "[data-health-item]") == limits.health_items
    assert count(document, "[data-fleet-row]") == limits.fleet_rows
    assert count(document, "[data-fleet-card]") == limits.fleet_rows
    assert count(document, "[data-rail-item]") == limits.rail_items
    assert count(document, "[data-outcome-item]") == limits.rail_items

    assert count(document, "[data-bounded-notice]") >= 5
    refute LazyHTML.text(document) =~ "90 authorized rows"
    refute LazyHTML.text(document) =~ "80 authorized attention"
  end

  test "composition IDs are unique and accessibility relationships are explicit" do
    document = fixture_document(:ready)
    ids = document |> LazyHTML.query("[id]") |> LazyHTML.attribute("id")

    assert ids != []
    assert length(ids) == length(Enum.uniq(ids))
    assert_present(document, "main[aria-labelledby='hui-c2-projection-fixture-title']")
    assert_present(document, "#hui-c2-trust[aria-labelledby='hui-c2-trust-title']")
    assert_present(document, "#hui-c2-attention-items[aria-label='Needs attention']")
    assert_present(document, "#hui-c2-fleet-table caption")
    assert count(document, "#hui-c2-fleet-table th[scope='col']") == 6
    assert_present(document, "#hui-c2-fleet-project-heading[aria-sort='ascending']")
    assert_present(document, "#hui-c2-fleet-project-heading-sort .sr-only")
    assert_present(document, "#hui-c2-fleet-table-row-1 th[scope='row']")
    assert_present(document, "#hui-c2-fleet-cards[aria-label]")
    assert_present(document, "#hui-c2-attempt-lifecycle [aria-current='step']")

    assert LazyHTML.attribute(
             LazyHTML.query(document, "#hui-c2-attempt-budget"),
             "aria-describedby"
           ) == ["hui-c2-attempt-budget-description"]

    assert LazyHTML.attribute(
             LazyHTML.query(document, "#hui-c2-attempt-budget-meter"),
             "aria-labelledby"
           ) == ["hui-c2-attempt-budget-label"]

    assert LazyHTML.attribute(
             LazyHTML.query(document, "#hui-c2-attempt-budget-meter"),
             "aria-describedby"
           ) == ["hui-c2-attempt-budget-description"]

    assert_present(document, "#hui-c2-fleet-pagination[aria-label='Pagination']")
    assert_present(document, "#hui-c2-fleet-pagination-previous[aria-disabled='true']")
    assert_present(document, "#hui-c2-fleet-pagination-next[href='?page=2']")
  end

  test "status, readiness, health, rails, and budget never rely on color alone" do
    document = fixture_document(:ready)

    for selector <- [
          "#hui-c2-readiness",
          "#hui-c2-health-item-1",
          "#hui-c2-attempt-lifecycle-step-1",
          "#hui-c2-attempt-outcomes-item-1",
          "#hui-c2-attempt-budget"
        ] do
      node = LazyHTML.query(document, selector)
      assert LazyHTML.text(node) |> String.trim() |> String.length() > 0
      assert_present(node, "[class*='hero-']")
    end

    assert LazyHTML.text(LazyHTML.query(document, "#hui-c2-attempt-budget-description")) =~
             "82.00 of 100.00 percent used"
  end

  test "native retry and evidence destinations reject unsafe or concealed links" do
    unsafe_hrefs = [
      "javascript:alert(1)",
      "//outside.example/evidence",
      "/\\outside.example/evidence",
      "/\t/outside.example/evidence",
      "/\n/outside.example/evidence",
      "/" <> String.duplicate("a", Projection.limits().href_bytes)
    ]

    for {href, index} <- Enum.with_index(unsafe_hrefs, 1) do
      unsafe_status =
        render_component(&Projection.projection_status/1,
          id: "unsafe-status-#{index}",
          state: :stale,
          retry_href: href
        )
        |> LazyHTML.from_fragment()

      refute_present(unsafe_status, "a")
    end

    unauthorized_status =
      render_component(&Projection.projection_status/1,
        id: "unauthorized-status",
        state: :unauthorized,
        retry_href: "/would-reveal-target"
      )
      |> LazyHTML.from_fragment()

    unsafe_evidence =
      render_component(&Projection.evidence_link/1,
        id: "unsafe-evidence",
        href: "//outside.example/evidence"
      )
      |> LazyHTML.from_fragment()

    refute_present(unauthorized_status, "a")
    refute_present(unsafe_evidence, "a")
    assert_present(unsafe_evidence, "#unsafe-evidence[data-evidence-unavailable]")
  end

  test "evidence links runtime-close their semantic kind" do
    assert_raise ArgumentError, ~r/evidence kind must be/, fn ->
      render_component(&Projection.evidence_link/1,
        id: "open-evidence-kind",
        kind: :authority,
        href: "/reviews/evidence"
      )
    end
  end

  test "component source has no authority, graph, runtime, LiveView, or Datastar dependency" do
    source = File.read!(Path.join(File.cwd!(), "lib/jido_code_web/components/projection.ex"))

    for forbidden <- [
          "use JidoCodeWeb, :live_view",
          "Phoenix.LiveView",
          "AuthorityBuilder",
          "TripleStore",
          "JidoCode.Knowledge",
          "Dstar",
          "Datastar",
          "data-on:",
          "data-signals:"
        ] do
      refute source =~ forbidden
    end
  end

  test "budget meters reject unbounded or invalid numeric contracts" do
    numeric_ceiling = Projection.limits().budget_numeric_max

    for {value, maximum} <- [
          {-1, 100},
          {1, 0},
          {"many", 100},
          {1, :infinity},
          {numeric_ceiling + 1, 100},
          {1, numeric_ceiling + 1}
        ] do
      assert_raise ArgumentError, ~r/budget meter requires/, fn ->
        render_component(&Projection.budget_meter/1,
          id: "invalid-budget",
          label: "Budget",
          value: value,
          max: maximum
        )
      end
    end
  end

  defp fixture_document(scenario) do
    render_component(&Fixture.render/1,
      scenario: scenario,
      hostile_content: @hostile
    )
    |> LazyHTML.from_fragment()
  end

  defp count(document, selector) do
    document
    |> LazyHTML.query(selector)
    |> LazyHTML.attribute("id")
    |> length()
  end

  defp assert_present(document, selector) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.to_html() != "",
           "expected #{selector} to be present"
  end

  defp refute_present(document, selector) do
    assert document |> LazyHTML.query(selector) |> LazyHTML.to_html() == "",
           "expected #{selector} to be absent"
  end
end
