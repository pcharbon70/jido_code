defmodule JidoCodeWeb.StreamUpdate do
  @moduledoc "Fresh authorized HEEx updates; no hint payload participates in rendering."
  alias JidoCode.Product.ReadProjection

  alias JidoCodeWeb.{
    ProductController,
    ProductPageViewModel,
    ProductRequest,
    ReadResponse,
    StreamDelivery
  }

  import Plug.Conn

  def render(conn) do
    {spec, params, original} = conn.private.read_authorization
    conn = put_private(conn, :read_reauthorization_point, :before_query_execution)

    with {:ok, page} <- ProductRequest.evaluate(conn, spec, params),
         true <-
           ReadResponse.fingerprint(page.authorization) == ReadResponse.fingerprint(original),
         {:ok, %ReadProjection{} = projection} <- ProductController.stream_projection(conn, page),
         true <- projection.state != :unauthorized,
         :ok <- StreamDelivery.reauthorize(conn) do
      view_model = ProductPageViewModel.build(conn, page, projection)
      {view, template} = conn.private.stream_render

      conn =
        assign(
          conn,
          :read_receipt,
          Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
        )

      assigns =
        Map.merge(conn.assigns, %{
          conn: conn,
          page: page,
          projection: projection,
          view_model: view_model,
          current_scope: page.authorization.current_scope,
          canonical_url: page.canonical_url,
          page_title: page.title
        })

      body = Phoenix.Template.render_to_string(view, to_string(template), "html", assigns)

      delivery =
        if ReadProjection.protected_state?(projection.state), do: "required", else: "visual"

      # Closed application metadata on the same bounded event. Datastar's patch
      # watcher ignores these keys; the local adapter can offer a native refresh
      # instead of applying a nonessential update. It cannot select a query/root.
      frame =
        "data: nudge #{page.key}\ndata: delivery #{delivery}\n" <>
          Dstar.Elements.format_patch(body, selector: "#product-owned-content")

      with :ok <- within_limit(frame),
           :ok <- StreamDelivery.reauthorize(conn),
           do: {:ok, frame, projection.dataset_revision}
    else
      false -> {:error, :revoked}
      {:error, reason} -> {:error, reason}
    end
  end

  defp within_limit(frame) do
    if byte_size(frame) <= StreamDelivery.max_event_bytes(),
      do: :ok,
      else: {:error, :event_overflow}
  end
end
