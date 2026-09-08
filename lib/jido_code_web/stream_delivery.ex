defmodule JidoCodeWeb.StreamDelivery do
  @moduledoc "One shared bounded HTTP delivery loop; page controllers never own stream processes."
  import Plug.Conn
  alias JidoCode.Product.StreamCoordinator
  alias JidoCode.Product.StreamSubscription
  alias JidoCode.Product.StreamConvergence
  alias JidoCodeWeb.{ProductRequest, ReadResponse, ReadSecurity, StreamHTML}

  @max_event_bytes 131_072
  def max_event_bytes, do: @max_event_bytes

  def deliver(conn) do
    body =
      "id: " <>
        conn.assigns.stream_cursor <>
        "\n" <>
        Dstar.Elements.format_patch(conn.private.stream_snapshot,
          selector: "#product-owned-content"
        )

    with true <- byte_size(body) <= @max_event_bytes,
         :ok <- reauthorize(conn),
         {:ok, lifecycle} <- StreamCoordinator.connect(conn.private.stream_lease) do
      monitor = Process.monitor(lifecycle.coordinator)

      try do
        case StreamSubscription.open(conn.private.stream_binding, conn.private.stream_projection) do
          {:ok, subscription} ->
            try do
              start_response(
                put_private(conn, :stream_subscription, subscription),
                body,
                lifecycle,
                monitor
              )
            after
              StreamSubscription.close(subscription)
            end

          {:error, _} ->
            ReadSecurity.reject(conn, 503)
        end
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
            :ok ->
              revision =
                Map.get(conn.private.stream_projection || %{}, :dataset_revision) ||
                  conn.private.stream_context.minimum_revision

              conn =
                conn
                |> put_private(:stream_snapshot, nil)
                |> put_private(:stream_projection, nil)
                |> put_private(:stream_evaluated_revision, revision)

              loop(conn, lifecycle, monitor)

            _ ->
              terminal(conn)
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
      {:product_stream, ^lease, {:closed, reason}} ->
        terminal(conn, reason)

      {:DOWN, ^monitor, :process, _, _} ->
        terminal(conn)

      {:product_stream, ^lease, {:check, heartbeat?}} ->
        with :ok <- reauthorize(conn),
             {:ok, conn, refreshed?} <- refresh(conn),
             :ok <- StreamCoordinator.checked(lease),
             {:ok, conn} <- heartbeat(conn, heartbeat? and not refreshed?) do
          loop(conn, lifecycle, monitor)
        else
          {:reconnect, conn} ->
            conn

          {:error, reason} ->
            state =
              if reason in [:revoked, :changed, :denied, :concealed_not_found, :step_up_required],
                do: :revoked,
                else: :unavailable

            StreamCoordinator.terminate_owner(lease, state)
            terminal(conn, state)
        end
    after
      remaining ->
        StreamCoordinator.terminate_owner(lease, :expired)
        terminal(conn, :expired)
    end
  end

  defp refresh(conn) do
    subscription = conn.private.stream_subscription

    case StreamSubscription.poll(subscription) do
      :idle ->
        {:ok, conn, false}

      {:refresh, reason} ->
        StreamConvergence.emit(reason, conn.private.stream_context.projection)
        refresh_projection(conn, subscription)

      {:error, :subscription_lost} ->
        StreamConvergence.emit(:subscription_lost, conn.private.stream_context.projection)
        with {:ok, conn, true} <- recover(conn), do: {:reconnect, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp refresh_projection(conn, subscription) do
    started = System.monotonic_time(:millisecond)

    with {:ok, frame, revision} <- JidoCodeWeb.StreamUpdate.render(conn),
         :ok <- StreamSubscription.evaluated(subscription, revision),
         {:ok, conn} <- write_update(conn, frame) do
      StreamConvergence.emit(
        :refreshed,
        conn.private.stream_context.projection,
        System.monotonic_time(:millisecond) - started
      )

      {:ok, put_private(conn, :stream_evaluated_revision, revision), true}
    else
      {:retry, reason} ->
        StreamConvergence.emit(reason, conn.private.stream_context.projection)
        recover(conn)

      {:error, reason} when reason in [:read_projection_unavailable, :unavailable] ->
        case StreamSubscription.evaluated(subscription, nil) do
          {:retry, _} -> recover(conn)
          other -> other
        end

      {:error, reason} ->
        StreamConvergence.emit(reason, conn.private.stream_context.projection)
        {:error, reason}
    end
  end

  defp recover(conn) do
    with {:ok, frame, _} <- JidoCodeWeb.StreamUpdate.recovery(conn),
         {:ok, conn} <- write_update(conn, frame),
         do: {:ok, conn, true}
  end

  defp write_update(conn, frame) do
    lease = conn.private.stream_lease

    with :ok <- reauthorize(conn),
         :ok <- StreamCoordinator.reserve(lease, byte_size(frame)),
         :ok <- reauthorize(conn),
         :ok <- StreamCoordinator.active(lease),
         {:ok, conn} <- chunk(conn, frame),
         :ok <- StreamCoordinator.sent(lease),
         do: {:ok, conn}
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

  def terminal_frame(reason) do
    state = if reason in [:revoked, :expired], do: reason, else: :closed

    StreamHTML.terminal(%{state: state})
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
    |> Dstar.Elements.format_patch(selector: "#product-shell")
  end

  defp terminal(conn, reason \\ :closed) do
    # One fixed, unprotected terminal patch replaces all old scope/account DOM.
    frame = terminal_frame(reason)

    frame =
      if byte_size(frame) <= StreamCoordinator.limits().terminal_bytes,
        do: frame,
        else: ": closed\n\n"

    case chunk(conn, frame) do
      {:ok, conn} -> conn
      {:error, _} -> conn
    end
  end

  def reauthorize(conn) do
    if JidoCode.Product.DeliveryControl.enabled?(),
      do: reauthorize_enabled(conn),
      else: {:error, :unavailable}
  end

  defp reauthorize_enabled(conn) do
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
