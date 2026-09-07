defmodule JidoCodeWeb.StreamUpdate do
  @moduledoc "Fresh authorized HEEx updates; no hint payload participates in rendering."
  alias JidoCode.Product.ReadProjection

  alias JidoCodeWeb.{
    ProductController,
    ProductPageViewModel,
    ProductRequest,
    ReadResponse,
    StreamContext,
    StreamDelivery
  }

  import Plug.Conn

  def render(conn) do
    with {:ok, page} <- current_page(conn),
         {:ok, %ReadProjection{} = projection} <- ProductController.stream_projection(conn, page),
         true <- projection.state != :unauthorized do
      render_projection(conn, page, projection)
    else
      false -> {:error, :revoked}
      {:error, reason} -> {:error, reason}
    end
  end

  def recovery(conn) do
    with {:ok, page} <- current_page(conn),
         do: render_projection(conn, page, ReadProjection.unavailable(page.key, :recovery))
  end

  defp current_page(conn) do
    {spec, params, original} = conn.private.read_authorization
    conn = put_private(conn, :read_reauthorization_point, :before_query_execution)

    with {:ok, page} <- ProductRequest.evaluate(conn, spec, params),
         true <-
           ReadResponse.fingerprint(page.authorization) == ReadResponse.fingerprint(original) do
      {:ok, page}
    else
      false -> {:error, :revoked}
      {:error, reason} -> {:error, reason}
    end
  end

  defp render_projection(conn, page, projection) do
    with :ok <- StreamDelivery.reauthorize(conn) do
      {view, template} = conn.private.stream_render

      conn =
        assign(
          conn,
          :read_receipt,
          Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
        )

      conn =
        if context = conn.private[:stream_context] do
          revision =
            projection.dataset_revision || conn.private[:stream_evaluated_revision] ||
              context.minimum_revision

          assign(conn, :stream_cursor, StreamContext.cursor(context, revision))
        else
          conn
        end

      assigns =
        Map.merge(conn.assigns, %{
          conn: conn,
          page: page,
          projection: projection,
          view_model: ProductPageViewModel.build(conn, page, projection),
          current_scope: page.authorization.current_scope,
          canonical_url: page.canonical_url,
          page_title: page.title
        })

      body = Phoenix.Template.render_to_string(view, to_string(template), "html", assigns)

      delivery =
        if ReadProjection.protected_state?(projection.state), do: "required", else: "visual"

      # Closed nudge metadata shares the one-event byte/rate budget. The browser
      # cannot use it to choose a root, query, revision or executable expression.
      event_id =
        if conn.assigns[:stream_cursor], do: "id: #{conn.assigns.stream_cursor}\n", else: ""

      frame =
        event_id <>
          "data: nudge #{page.key}\ndata: delivery #{delivery}\n" <>
          Dstar.Elements.format_patch(body, selector: "#product-owned-content")

      with :ok <- within_limit(frame),
           :ok <- StreamDelivery.reauthorize(conn),
           do: {:ok, frame, projection.dataset_revision}
    end
  end

  defp within_limit(frame) do
    if byte_size(frame) <= StreamDelivery.max_event_bytes(),
      do: :ok,
      else: {:error, :event_overflow}
  end
end
