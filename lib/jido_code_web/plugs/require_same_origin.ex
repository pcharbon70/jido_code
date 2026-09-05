defmodule JidoCodeWeb.Plugs.RequireSameOrigin do
  @moduledoc "Fail-closed Origin and Fetch Metadata enforcement for browser writes."

  import Plug.Conn

  @unsafe_methods ~w[POST PUT PATCH DELETE]

  def init(options), do: options

  def call(%Plug.Conn{method: method} = conn, _options) when method in @unsafe_methods do
    if same_origin?(conn) and same_site_fetch?(conn) do
      conn
    else
      conn
      |> send_resp(:forbidden, "Request origin was not accepted.")
      |> halt()
    end
  end

  def call(conn, _options), do: conn

  defp same_origin?(conn) do
    case get_req_header(conn, "origin") do
      [origin] -> origin_matches?(URI.parse(origin), conn)
      _missing_or_ambiguous -> false
    end
  end

  defp origin_matches?(%URI{} = origin, conn) do
    origin.scheme == Atom.to_string(conn.scheme) and origin.host == conn.host and
      normalized_port(origin.scheme, origin.port) == normalized_port(conn.scheme, conn.port) and
      origin.userinfo == nil and origin.path in [nil, ""] and origin.query == nil and
      origin.fragment == nil
  end

  defp same_site_fetch?(conn) do
    case get_req_header(conn, "sec-fetch-site") do
      [] -> true
      [value] when value in ["same-origin", "same-site", "none"] -> true
      _cross_site_or_ambiguous -> false
    end
  end

  defp normalized_port(scheme, nil) when scheme in ["https", :https], do: 443
  defp normalized_port(scheme, nil) when scheme in ["http", :http], do: 80
  defp normalized_port(_scheme, port), do: port
end
