defmodule JidoCodeWeb.HomeLiveTest do
  use JidoCodeWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  setup do
    original_loader = Application.get_env(:jido_code, :system_config_loader, :__missing__)
    original_config = Application.get_env(:jido_code, :system_config, :__missing__)

    on_exit(fn ->
      restore_env(:system_config_loader, original_loader)
      restore_env(:system_config, original_config)
    end)

    :ok
  end

  test "redirects incomplete onboarding state to setup and preserves step", %{conn: conn} do
    Application.put_env(:jido_code, :system_config_loader, fn ->
      {:ok, %{onboarding_completed: false, onboarding_step: 4}}
    end)

    log =
      capture_log([level: :info], fn ->
        assert {:error, {:redirect, %{to: redirect_to}}} = live(conn, ~p"/")
        params = assert_setup_redirect(redirect_to, "4", "onboarding_incomplete")
        assert params["diagnostic"] =~ "Setup is incomplete"

        Logger.flush()
        send(self(), {:redirect_to, redirect_to})
      end)

    assert log =~ "onboarding_redirect"
    assert log =~ "reason=onboarding_incomplete"
    assert log =~ "step=4"

    assert_receive {:redirect_to, redirect_to}
    setup_response = build_conn() |> get(redirect_to)
    setup_html = html_response(setup_response, 200)

    assert setup_html =~ "Step 4"
    assert setup_html =~ "onboarding_incomplete"
    assert setup_html =~ "Setup is incomplete"
  end

  test "redirects to welcome with diagnostics when SystemConfig cannot be loaded", %{conn: conn} do
    Application.put_env(:jido_code, :system_config_loader, fn ->
      {:error, :database_unreachable}
    end)

    log =
      capture_log([level: :warning], fn ->
        assert {:error, {:redirect, %{to: redirect_to}}} = live(conn, ~p"/")
        assert redirect_to == "/welcome"

        Logger.flush()
      end)

    assert log =~ "onboarding_redirect"
    assert log =~ "reason=system_config_unavailable"
    assert log =~ "database_unreachable"
  end

  defp assert_setup_redirect(redirect_to, expected_step, expected_reason) do
    uri = URI.parse(redirect_to)
    assert uri.path == "/setup"

    params = URI.decode_query(uri.query || "")
    assert params["step"] == expected_step
    assert params["reason"] == expected_reason

    params
  end

  defp restore_env(key, :__missing__), do: Application.delete_env(:jido_code, key)
  defp restore_env(key, value), do: Application.put_env(:jido_code, key, value)
end
