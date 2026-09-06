defmodule JidoCodeWeb.StreamDelivery do
  @moduledoc "One shared bounded HTTP delivery loop; page controllers never own stream processes."
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
         {:ok, lifecycle} <- StreamCoordinator.connect(conn.private.stream_lease) do
      monitor = Process.monitor(lifecycle.coordinator)

      try do
        start_response(conn, body, lifecycle, monitor)
      after
        Process.demonitor(monitor, [:flush])
      end
    else
      false -> ReadSecurity.reject(conn, 503)
      {:error, :revoked} -> ReadSecurity.reject(conn, 401)
      {:error, _} -> ReadSecurity.reject(conn, 409)
    end
  end

  defp start_response(conn, body, lifecycle, monitor) do
    lease = conn.private.stream_lease

    with :ok <- reauthorize(conn),
         :ok <- StreamCoordinator.reserve(lease, byte_size(body)),
         :ok <- StreamCoordinator.active(lease) do
      conn =
        conn
        |> ReadSecurity.private_response()
        |> put_resp_header("x-accel-buffering", "no")
        |> put_resp_content_type("text/event-stream")
        |> send_chunked(200)

      case chunk(conn, body) do
        {:ok, conn} ->
          case StreamCoordinator.sent(lease) do
            :ok -> loop(put_private(conn, :stream_snapshot, nil), lifecycle, monitor)
            _ -> terminal(conn)
          end

        {:error, _} ->
          conn
      end
    else
      _ -> ReadSecurity.reject(conn, 409)
    end
  end

  defp loop(conn, lifecycle, monitor) do
    lease = conn.private.stream_lease
    remaining = max(lifecycle.deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:product_stream, ^lease, {:closed, _reason}} ->
        terminal(conn)

      {:DOWN, ^monitor, :process, _, _} ->
        terminal(conn)

      {:product_stream, ^lease, {:check, heartbeat?}} ->
        with :ok <- reauthorize(conn),
             :ok <- StreamCoordinator.checked(lease),
             {:ok, conn} <- heartbeat(conn, heartbeat?) do
          loop(conn, lifecycle, monitor)
        else
          {:error, _} ->
            StreamCoordinator.terminate_owner(lease, :revoked)
            terminal(conn)
        end
    after
      remaining ->
        StreamCoordinator.terminate_owner(lease, :expired)
        terminal(conn)
    end
  end

  defp heartbeat(conn, false), do: {:ok, conn}

  defp heartbeat(conn, true) do
    body = ": heartbeat\n\n"
    lease = conn.private.stream_lease

    with :ok <- StreamCoordinator.reserve(lease, byte_size(body)),
         :ok <- StreamCoordinator.active(lease),
         {:ok, conn} <- chunk(conn, body),
         :ok <- StreamCoordinator.sent(lease),
         do: {:ok, conn}
  end

  defp terminal(conn) do
    # One fixed, unprotected terminal frame uses the reserved terminal allowance.
    case chunk(conn, "event: datastar-stream-status\ndata: state closed\n\n") do
      {:ok, conn} -> conn
      {:error, _} -> conn
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
