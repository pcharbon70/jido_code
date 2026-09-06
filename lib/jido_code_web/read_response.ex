defmodule JidoCodeWeb.ReadResponse do
  @moduledoc "A finite read response is shaped first, then checked against fresh exact authority."
  import Plug.Conn
  alias JidoCodeWeb.{ProductRequest, ReadSecurity}
  alias JidoCode.Identity.AuthorizationResult

  @max_patch_bytes 131_072
  def max_patch_bytes, do: @max_patch_bytes
  def max_roots, do: 1
  def within_limit?(body) when is_binary(body), do: byte_size(body) <= @max_patch_bytes

  def render(conn, template, assigns) do
    conn =
      assign(
        conn,
        :read_receipt,
        Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
      )

    body =
      Phoenix.Template.render_to_string(
        Phoenix.Controller.view_module(conn),
        to_string(template),
        "html",
        Map.merge(conn.assigns, Map.new(assigns)) |> Map.put(:conn, conn)
      )

    {spec, params, original} = conn.private.read_authorization
    conn = put_private(conn, :read_reauthorization_point, :before_each_protected_patch)

    case ProductRequest.authorize(conn, spec, params) do
      {:ok, conn, %{authorization: current}} ->
        cond do
          fingerprint(original) != fingerprint(current) ->
            ReadSecurity.reject(conn, 409)

          not within_limit?(body) ->
            ReadSecurity.reject(conn, 503)

          true ->
            conn
            |> ReadSecurity.private_response()
            |> put_resp_header("datastar-selector", "#product-owned-content")
            |> put_resp_header("datastar-mode", "outer")
            |> put_resp_content_type("text/html")
            |> send_resp(200, body)
        end

      {:error, conn} ->
        conn
    end
  end

  # Access timestamps and correlation IDs are deliberately not an authority fence.
  # All grants, generations, redaction, assurance and resource/graph revisions are.
  defp fingerprint(%AuthorizationResult{} = result) do
    result
    |> Map.take([
      :decision,
      :exact_grant_ref,
      :delegation_ref,
      :obligations,
      :policy_revision,
      :graph_revisions,
      :concealment,
      :redaction
    ])
    |> Map.put(:scope, Map.drop(result.current_scope, [:idle_expires_at]))
  end

  defp fingerprint(session), do: session
end
