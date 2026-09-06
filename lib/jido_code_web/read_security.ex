defmodule JidoCodeWeb.ReadSecurity do
  @moduledoc "Admission and privacy for finite, explicit product read requests."
  import Plug.Conn
  alias JidoCodeWeb.ProductAuth

  def init(options), do: options

  def call(conn, _options) do
    conn = private_response(conn)

    with ["true"] <- get_req_header(conn, "datastar-request"),
         ["same-origin"] <- get_req_header(conn, "sec-fetch-site"),
         [origin] <- get_req_header(conn, "origin"),
         {:ok, uri} <- URI.new(origin),
         true <-
           uri.scheme == Atom.to_string(conn.scheme) and uri.host == conn.host and
             uri.port == conn.port and uri.userinfo == nil and uri.path in [nil, ""] and
             uri.query == nil and uri.fragment == nil do
      conn = ProductAuth.fetch_authenticated_session(conn, [])
      if conn.assigns[:authenticated_human], do: conn, else: reject(conn, 401)
    else
      _invalid -> reject(conn, 403)
    end
  end

  def private_response(conn) do
    conn
    |> put_resp_header("cache-control", "no-store, private")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("vary", "datastar-request, sec-fetch-site")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-robots-tag", "noindex, nofollow")
  end

  def reject(conn, status),
    do:
      conn |> private_response() |> send_resp(status, "Read request was not accepted.") |> halt()
end
