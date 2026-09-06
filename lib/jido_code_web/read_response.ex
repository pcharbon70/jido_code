defmodule JidoCodeWeb.ReadResponse do
  @moduledoc "A finite read response is shaped first, then checked against fresh exact authority."
  import Plug.Conn
  alias JidoCodeWeb.{ProductRequest, ReadSecurity}
  alias JidoCode.Identity.AuthorizationResult

  def render(conn, template, assigns) do
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
        if fingerprint(original) == fingerprint(current) do
          conn
          |> ReadSecurity.private_response()
          |> put_resp_content_type("text/html")
          |> send_resp(200, body)
        else
          ReadSecurity.reject(conn, 409)
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
