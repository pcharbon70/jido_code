defmodule JidoCodeWeb.Plugs.ProductCanonicalPath do
  @moduledoc "Normalizes trailing slashes for the explicit product route vocabulary."

  import Plug.Conn

  @product_roots ~w[/factory /projects /reviews /operations /security /governance /account]

  def init(options), do: options

  def call(%Plug.Conn{method: method, request_path: path} = conn, _options)
      when method in ["GET", "HEAD"] do
    if product_path?(path) and path != "/" and String.ends_with?(path, "/") do
      canonical = String.trim_trailing(path, "/")

      location =
        if conn.query_string == "", do: canonical, else: canonical <> "?" <> conn.query_string

      conn
      |> put_resp_header("cache-control", "no-store")
      |> put_resp_header("referrer-policy", "no-referrer")
      |> put_resp_header("location", location)
      |> send_resp(:permanent_redirect, "")
      |> halt()
    else
      conn
    end
  end

  def call(conn, _options), do: conn

  defp product_path?(path),
    do: Enum.any?(@product_roots, &(path == &1 or String.starts_with?(path, &1 <> "/")))
end
