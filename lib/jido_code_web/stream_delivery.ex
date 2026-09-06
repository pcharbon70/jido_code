defmodule JidoCodeWeb.StreamDelivery do
  @moduledoc "Shared SSE encoding and the last fresh authority fence before response start."
  import Plug.Conn
  alias JidoCode.Product.StreamCoordinator
  alias JidoCodeWeb.{ProductRequest, ReadResponse, ReadSecurity, StreamContext}

  @max_event_bytes 131_072
  def max_event_bytes, do: @max_event_bytes

  def deliver(conn) do
    context = conn.private.stream_context

    body =
      "id: " <>
        StreamContext.cursor(context) <>
        "\n" <>
        Dstar.Elements.format_patch(conn.private.stream_snapshot,
          selector: "#product-owned-content"
        )

    with true <- byte_size(body) <= @max_event_bytes,
         :ok <- reauthorize(conn),
         :ok <- StreamCoordinator.active(conn.private.stream_lease) do
      conn =
        conn
        |> ReadSecurity.private_response()
        |> put_resp_header("x-accel-buffering", "no")
        |> put_resp_content_type("text/event-stream")
        |> send_chunked(200)

      case chunk(conn, body) do
        {:ok, conn} -> conn
        {:error, _} -> conn
      end
    else
      false -> ReadSecurity.reject(conn, 503)
      {:error, :revoked} -> ReadSecurity.reject(conn, 401)
      {:error, _} -> ReadSecurity.reject(conn, 409)
    end
  end

  def reauthorize(conn) do
    {spec, params, original} = conn.private.read_authorization
    conn = put_private(conn, :read_reauthorization_point, :before_each_protected_patch)

    case ProductRequest.evaluate(conn, spec, params) do
      {:ok, %{authorization: current}} ->
        if ReadResponse.fingerprint(original) == ReadResponse.fingerprint(current),
          do: :ok,
          else: {:error, :changed}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
