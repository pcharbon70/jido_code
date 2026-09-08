defmodule JidoCodeWeb.LocalTransportTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  alias JidoCodeWeb.Plugs.LocalTransport

  setup do
    old = Application.get_env(:jido_code, :deployment_profile)
    Application.put_env(:jido_code, :deployment_profile, JidoCode.LocalDeployment.profile())

    on_exit(fn ->
      if old,
        do: Application.put_env(:jido_code, :deployment_profile, old),
        else: Application.delete_env(:jido_code, :deployment_profile)
    end)

    url = JidoCodeWeb.Endpoint.config(:url)
    conn = Plug.Test.conn(:get, "http://#{url[:host]}:#{url[:port] || 80}/")
    %{conn: %{conn | remote_ip: {127, 0, 0, 1}}}
  end

  test "accepts only the configured local origin and actual loopback peer", %{conn: conn} do
    refute LocalTransport.call(conn, []).halted

    for bad <- [
          %{conn | host: "attacker.example"},
          %{conn | remote_ip: {192, 168, 1, 1}},
          %{conn | port: conn.port + 1},
          %{conn | scheme: :https},
          put_req_header(conn, "forwarded", "for=127.0.0.1"),
          put_req_header(conn, "x-forwarded-host", conn.host),
          put_req_header(conn, "x-forwarded-proto", "http")
        ] do
      rejected = LocalTransport.call(bad, [])
      assert rejected.halted
      assert rejected.status == 421
      assert get_resp_header(rejected, "cache-control") == ["no-store"]
      assert rejected.resp_cookies == %{}
    end
  end
end
