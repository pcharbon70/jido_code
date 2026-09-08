defmodule JidoCodeWeb.Plugs.LocalTransport do
  @moduledoc "Rejects unsupported local exposure before static assets, cookies or routing."
  import Plug.Conn

  def init(options), do: options

  def call(conn, _options) do
    if JidoCode.LocalDeployment.active?() do
      url = JidoCodeWeb.Endpoint.config(:url)

      forwarded? =
        Enum.any?(conn.req_headers, fn {name, _} ->
          name == "forwarded" or String.starts_with?(name, "x-forwarded-")
        end)

      if conn.remote_ip == {127, 0, 0, 1} and conn.scheme == :http and
           conn.host == Keyword.fetch!(url, :host) and
           conn.port == Keyword.fetch!(url, :port) and not forwarded? do
        conn
      else
        conn
        |> put_resp_header("cache-control", "no-store")
        |> send_resp(421, "Unsupported local transport.")
        |> halt()
      end
    else
      conn
    end
  end
end
