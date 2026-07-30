defmodule JidoCodeWeb.HomeLiveTest do
  use JidoCodeWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders the root LiveView", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#application-shell")
    assert has_element?(view, "#runtime-workspace")
    assert has_element?(view, "#runtime-status-island")
    assert has_element?(view, "#toolchain-status-island")
    assert has_element?(view, "#heartbeat-count", "0")
  end

  test "handles heartbeat events", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#runtime-actions button[phx-click=ping]")
    |> render_click()

    assert has_element?(view, "#heartbeat-count", "1")
    assert has_element?(view, "#event-log", "Heartbeat acknowledged")

    view
    |> element("#runtime-actions button[phx-click=reset]")
    |> render_click()

    assert has_element?(view, "#heartbeat-count", "0")
    assert has_element?(view, "#event-log", "Heartbeat counter reset")
  end

  test "handles semantic events from the runtime island", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    render_hook(view, "runtime/semantic-event", %{"action" => "ping"})

    assert has_element?(view, "#heartbeat-count", "1")
    assert has_element?(view, "#event-log", "Heartbeat acknowledged")
  end
end
