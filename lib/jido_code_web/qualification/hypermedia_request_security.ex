defmodule JidoCodeWeb.Qualification.HypermediaRequestSecurity do
  @moduledoc "Request admission and response privacy policy for HUI-B3 enhancements."

  import Plug.Conn

  @same_origin_headers [["same-origin"], ["none"]]

  @spec admit(Plug.Conn.t(), :get | :post) :: {:ok, Plug.Conn.t()} | {:error, atom()}
  def admit(conn, method) when method in [:get, :post] do
    with :ok <- require_datastar_request(conn),
         :ok <- require_fetch_metadata(conn),
         :ok <- require_origin(conn, method) do
      {:ok, private_response(conn)}
    end
  end

  @spec reject(Plug.Conn.t(), Plug.Conn.status(), atom()) :: Plug.Conn.t()
  def reject(conn, status, code) when is_atom(code) do
    body = Jason.encode!(%{error: Atom.to_string(code)})

    conn
    |> private_response()
    |> put_resp_content_type("application/json")
    |> send_resp(status, body)
  end

  @spec private_response(Plug.Conn.t()) :: Plug.Conn.t()
  def private_response(conn) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> put_resp_header("referrer-policy", "no-referrer")
    |> put_resp_header("vary", "datastar-request, sec-fetch-site")
  end

  defp require_datastar_request(conn) do
    if get_req_header(conn, "datastar-request") == ["true"],
      do: :ok,
      else: {:error, :enhanced_request_required}
  end

  defp require_fetch_metadata(conn) do
    if get_req_header(conn, "sec-fetch-site") in @same_origin_headers,
      do: :ok,
      else: {:error, :cross_site_request}
  end

  defp require_origin(conn, :get) do
    case get_req_header(conn, "origin") do
      [] -> :ok
      [origin] -> compare_origin(conn, origin)
      _other -> {:error, :invalid_origin}
    end
  end

  defp require_origin(conn, :post) do
    case get_req_header(conn, "origin") do
      [origin] -> compare_origin(conn, origin)
      _other -> {:error, :invalid_origin}
    end
  end

  defp compare_origin(conn, origin) do
    expected =
      URI.to_string(%URI{scheme: Atom.to_string(conn.scheme), host: conn.host, port: conn.port})

    if origin == expected, do: :ok, else: {:error, :invalid_origin}
  end
end
