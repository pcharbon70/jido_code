defmodule JidoCodeWeb.Plugs.ReadBody do
  @moduledoc "Bounds enhanced read bodies before the general parser or parameter logger."
  import Plug.Conn
  alias JidoCodeWeb.ReadSignals

  def init(options), do: options

  def call(%{request_path: "/ui/reads/" <> _} = conn, _options) do
    conn = JidoCodeWeb.ReadSecurity.private_response(conn)

    cond do
      conn.method != "POST" ->
        reject(conn, 405)

      conn.query_string != "" ->
        reject(conn, 422)

      get_req_header(conn, "content-type") not in [
        ["application/json"],
        ["application/json; charset=utf-8"]
      ] ->
        reject(conn, 415)

      true ->
        read(conn)
    end
  end

  def call(conn, _options), do: conn

  defp read(conn) do
    case read_body(conn,
           length: ReadSignals.max_bytes() + 1,
           read_length: ReadSignals.max_bytes() + 1,
           read_timeout: 5_000
         ) do
      {:ok, body, conn} when byte_size(body) <= 2_048 ->
        conn |> Map.put(:body_params, %{}) |> put_private(:read_raw_body, body)

      {:more, _body, conn} ->
        reject(conn, 413)

      {:ok, _body, conn} ->
        reject(conn, 413)

      {:error, _reason} ->
        reject(conn, 400)
    end
  end

  defp reject(conn, status),
    do: conn |> send_resp(status, "Read request was not accepted.") |> halt()
end
