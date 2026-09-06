defmodule JidoCodeWeb.FactoryProjectionPhaseC4Test do
  use JidoCodeWeb.ConnCase, async: false

  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture

  setup do
    prior_provider = Application.get_env(:jido_code, :product_read_projection_provider)
    prior_fixture = Application.get_env(:jido_code, :read_projection_fixture)
    prior_pid = Application.get_env(:jido_code, :read_projection_test_pid)

    Application.put_env(
      :jido_code,
      :product_read_projection_provider,
      JidoCode.TestSupport.FakeReadProjectionProvider
    )

    Application.put_env(:jido_code, :read_projection_test_pid, self())

    on_exit(fn ->
      restore(:product_read_projection_provider, prior_provider)
      restore(:read_projection_fixture, prior_fixture)
      restore(:read_projection_test_pid, prior_pid)
    end)

    :ok
  end

  test "renders attention provenance, family coverage, fleet rows, and honest capabilities", %{
    conn: conn
  } do
    row =
      HypermediaUIPhaseC4Fixture.fleet_row("alpha <script>", "/projects/project_browser_alpha")

    projection =
      HypermediaUIPhaseC4Fixture.projection(:factory, %{
        attention: [
          %{
            severity: :high,
            title: "Blocked work",
            reason: "Current durable transition is blocked.",
            scope_label: "alpha <script>",
            owner: "Project owner",
            age: "Current",
            destination_href: "/projects/project_browser_alpha",
            destination_label: "Review project"
          }
        ],
        attention_families: [
          %{key: :blocked, label: "Blocked", count: 1, state: :ready},
          %{key: :incident, label: "Incident", count: nil, state: :unconfigured}
        ],
        health: [
          %{label: "Authorized projects", value: 1, status: :healthy, detail: "Authorized only"}
        ],
        fleet: [row],
        capabilities: [
          %{key: :read_projection, label: "Reviewed read projections", state: :ready},
          %{key: :semantic_controls, label: "Semantic controls", state: :unconfigured}
        ],
        summaries: %{
          sort_column: "project",
          sort_direction: "ascending",
          sort_hrefs: %{project: "/factory?direction=descending"}
        },
        pagination: %{
          page: 1,
          page_size: 20,
          known_total: 1,
          page_count: 1,
          previous_href: nil,
          next_href: nil,
          summary: "Page 1 of 1; 1 authorized row"
        }
      })

    Application.put_env(:jido_code, :read_projection_fixture, %{factory: projection})

    response = conn |> init_test_session(%{}) |> sign_in_named_human() |> get(~p"/factory")
    document = response |> html_response(200) |> LazyHTML.from_document()

    assert has?(document, "#factory-attention-trust[data-projection-state='ready']")
    assert has?(document, "#factory-attention-card-1[data-attention-item]", "Blocked work")
    assert has?(document, "#factory-fleet-preview-table-row-1", "alpha <script>")
    assert has?(document, "#factory-attention-family-coverage", "Not configured")
    assert has?(document, "#factory-capability-truth", "Semantic controls")
    refute html_response(response, 200) =~ "https://jido.run/"
    refute html_response(response, 200) =~ "<script>"
  end

  test "passes only normalized filter, sort, direction, and page intent to the provider", %{
    conn: conn
  } do
    projection =
      HypermediaUIPhaseC4Fixture.projection(:fleet, %{
        state: :empty,
        source_outcome: :empty
      })

    Application.put_env(:jido_code, :read_projection_fixture, %{fleet: projection})

    response =
      conn
      |> init_test_session(%{})
      |> sign_in_named_human()
      |> get(
        "/factory/fleet?q=%20beta%20&state=blocked&sort=health&direction=descending&page=2&graph=attacker"
      )

    assert html_response(response, 200)

    assert_receive {:read_projection_load,
                    %{page: %{query: query, key: :fleet}, session_ref: session_ref}}

    assert query == %{
             "q" => "beta",
             "state" => "blocked",
             "sort" => "health",
             "direction" => "descending",
             "page" => 2
           }

    assert is_binary(session_ref)
    refute Map.has_key?(query, "graph")
  end

  defp has?(document, selector), do: document |> LazyHTML.query(selector) |> Enum.any?()

  defp has?(document, selector, text) do
    document |> LazyHTML.query(selector) |> LazyHTML.text() |> String.contains?(text)
  end

  defp restore(key, nil), do: Application.delete_env(:jido_code, key)
  defp restore(key, value), do: Application.put_env(:jido_code, key, value)
end
