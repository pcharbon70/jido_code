defmodule JidoCodeWeb.Plugs.RequireProductArea do
  @moduledoc "Repeats exact named-human authority construction for a restricted route area."

  import Plug.Conn

  alias JidoCode.Identity.AuthorityBuilder

  def init(area)
      when area in [
             :developer,
             :reviewer,
             :operations,
             :security,
             :cost,
             :knowledge,
             :administration
           ],
      do: area

  def call(conn, area) do
    with %{session_ref: session_ref} <- conn.assigns[:current_scope],
         {:ok, request} <-
           AuthorityBuilder.request(operation(area), area, :page, :factory,
             reauthorization_point: :before_response_start,
             correlation_ref: conn.assigns[:request_id] || conn.assigns.current_scope.nonce
           ),
         {:ok, authorization} <- AuthorityBuilder.build(session_ref, request),
         :allowed <- authorization.decision do
      conn
      |> assign(:current_scope, authorization.current_scope)
      |> assign(:product_identity, authorization.product_identity)
      |> assign(:authority, authorization.authority_context)
      |> assign(:authorization, authorization)
    else
      {:ok, %{decision: :concealed_not_found}} -> concealed(conn)
      :concealed_not_found -> concealed(conn)
      {:error, :concealed_not_found} -> concealed(conn)
      _denied_or_unavailable -> unavailable(conn)
    end
  end

  defp operation(:developer), do: :project_page
  defp operation(:reviewer), do: :evidence_page
  defp operation(:operations), do: :operations_page
  defp operation(:security), do: :security_page
  defp operation(:cost), do: :cost_page
  defp operation(:knowledge), do: :knowledge_page
  defp operation(:administration), do: :administration_page

  defp concealed(conn), do: conn |> send_resp(:not_found, "Not found.") |> halt()

  defp unavailable(conn),
    do: conn |> send_resp(:service_unavailable, "The product authority is unavailable.") |> halt()
end
