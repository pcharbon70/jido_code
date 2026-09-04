defmodule JidoCodeWeb.Plugs.HypermediaQualificationAccessTest do
  use JidoCodeWeb.ConnCase, async: false

  setup do
    prior = Application.get_env(:jido_code, :hypermedia_qualification)

    Application.put_env(:jido_code, :hypermedia_qualification,
      enabled: true,
      allowed_hosts: ["www.example.com"]
    )

    on_exit(fn -> Application.put_env(:jido_code, :hypermedia_qualification, prior) end)
  end

  test "conceals the qualification surface when disabled", %{conn: conn} do
    Application.put_env(:jido_code, :hypermedia_qualification,
      enabled: false,
      allowed_hosts: ["www.example.com"]
    )

    assert conn |> get(~p"/__qualification/hypermedia") |> response(404) == "Not Found"
  end

  test "conceals non-loopback callers and hosts outside the explicit allowlist", %{conn: conn} do
    remote = %{conn | remote_ip: {192, 0, 2, 10}}
    assert remote |> get(~p"/__qualification/hypermedia") |> response(404) == "Not Found"

    wrong_host = %{conn | host: "qualification.example.test"}
    assert wrong_host |> get(~p"/__qualification/hypermedia") |> response(404) == "Not Found"
  end
end
