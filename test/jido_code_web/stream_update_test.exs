defmodule JidoCodeWeb.StreamUpdateTest do
  use JidoCodeWeb.ConnCase, async: false
  alias JidoCode.TestSupport.HypermediaUIPhaseC4Fixture, as: Fixture
  alias JidoCodeWeb.{ProductRequest, StreamUpdate}

  setup %{conn: conn} do
    keys = [:product_read_projection_provider, :read_projection_fixture]
    old = Map.new(keys, &{&1, Application.get_env(:jido_code, &1)})

    Application.put_env(
      :jido_code,
      :product_read_projection_provider,
      JidoCode.TestSupport.FakeReadProjectionProvider
    )

    fixture("original", 4)

    on_exit(fn ->
      Enum.each(old, fn {key, value} ->
        if value == nil,
          do: Application.delete_env(:jido_code, key),
          else: Application.put_env(:jido_code, key, value)
      end)
    end)

    conn = conn |> init_test_session(%{}) |> sign_in_named_human() |> get("/factory/fleet")
    {spec, params, _} = conn.private.read_authorization
    spec = Map.put(spec, :action, :stream)
    {:ok, page} = ProductRequest.evaluate(conn, spec, params)

    conn =
      conn
      |> assign(:enhanced_read, :fleet)
      |> put_private(:read_authorization, {spec, params, page.authorization})
      |> put_private(:stream_render, {JidoCodeWeb.FactoryHTML, :fleet})

    %{page: conn}
  end

  test "re-query renders one coherent escaped fragment at the evaluated revision", %{page: page} do
    fixture("<script>new truth</script>", 9)
    assert {:ok, frame, 9} = StreamUpdate.render(page)
    assert frame =~ "data: nudge fleet\ndata: delivery visual\n"
    document = frame |> html() |> LazyHTML.from_fragment()
    assert length(Enum.to_list(LazyHTML.query(document, "#product-owned-content"))) == 1
    assert LazyHTML.text(document) =~ "<script>new truth</script>"
    assert LazyHTML.text(document) =~ "9"
    refute Enum.any?(LazyHTML.query(document, "script, #product-shell"))
    refute LazyHTML.text(document) =~ "original"
  end

  test "unavailable refresh clears rows and cannot be suppressed as visual-only", %{page: page} do
    Application.put_env(:jido_code, :read_projection_fixture, fn _ ->
      JidoCode.Product.ReadProjection.unavailable(:fleet)
    end)

    assert {:ok, frame, nil} = StreamUpdate.render(page)
    assert frame =~ "data: delivery required\n"
    document = frame |> html() |> LazyHTML.from_fragment()
    refute LazyHTML.text(document) =~ "original"
    assert Enum.any?(LazyHTML.query(document, "#product-owned-content"))
  end

  test "query-time revocation withholds the entire protected patch", %{page: page} do
    Application.put_env(:jido_code, :read_projection_fixture, fn context ->
      {:ok, sessions} = JidoCode.Identity.Sessions.managed(context.session_ref)
      current = Enum.find(sessions, & &1.current)

      {:ok, :current} =
        JidoCode.Identity.Sessions.revoke_managed(context.session_ref, current.management_ref)

      Fixture.projection(:fleet)
    end)

    assert {:error, :revoked} = StreamUpdate.render(page)
  end

  test "encoded frame limits include nudge metadata and escaped HTML", %{page: page} do
    Application.put_env(:jido_code, :read_projection_fixture, fn _ ->
      Fixture.projection(:fleet, %{
        dataset_revision: 10,
        fleet:
          Enum.map(1..200, fn _ ->
            Fixture.fleet_row(String.duplicate("<", 500), "/projects/project_browser_alpha")
          end)
      })
    end)

    assert {:error, :event_overflow} = StreamUpdate.render(page)
  end

  defp fixture(label, revision) do
    Application.put_env(:jido_code, :read_projection_fixture, fn _ ->
      Fixture.projection(:fleet, %{
        dataset_revision: revision,
        fleet: [Fixture.fleet_row(label, "/projects/project_browser_alpha")]
      })
    end)
  end

  defp html(frame),
    do:
      frame
      |> String.split("\n")
      |> Enum.filter(&String.starts_with?(&1, "data: elements "))
      |> Enum.map_join("\n", &String.replace_prefix(&1, "data: elements ", ""))
end
