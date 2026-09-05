defmodule JidoCodeWeb.AccountController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController
  alias JidoCodeWeb.ProductAuth

  @session %{resource: :session, operation: :compatibility_product, area: :developer}

  def show(conn, params) do
    with {:ok, conn, page, view_model} <-
           ProductController.prepare(
             conn,
             params,
             spec(:account, "Account", "Current named-human account and assurance posture.")
           ) do
      render_page(conn, :show, page, view_model,
        account: conn.assigns.authenticated_human.account,
        capabilities: JidoCode.Identity.capabilities()
      )
    else
      {:error, conn} -> conn
    end
  end

  def sessions(conn, params) do
    with {:ok, conn, page, view_model} <-
           ProductController.prepare(
             conn,
             params,
             spec(:sessions, "Sessions", "Current browser session and revocation controls.")
           ),
         {:ok, sessions} <- ProductAuth.managed_sessions(conn) do
      render_page(conn, :sessions, page, view_model,
        sessions: Enum.map(sessions, &session_view/1),
        logout_all_form: Phoenix.Component.to_form(%{}, as: :logout_all)
      )
    else
      {:error, %Plug.Conn{} = conn} ->
        conn

      {:error, _unavailable} ->
        conn |> put_status(:service_unavailable) |> text("Session management is unavailable.")
    end
  end

  def revoke(conn, %{"management_ref" => management_ref})
      when is_binary(management_ref) and byte_size(management_ref) in 1..64 do
    case ProductAuth.revoke_managed_session(conn, management_ref) do
      {:ok, :current} ->
        conn
        |> ProductAuth.delete_session()
        |> redirect(to: ~p"/sign-in?#{%{reason: "session-ended"}}")

      {:ok, :other} ->
        conn
        |> put_flash(:info, "The selected browser session was ended.")
        |> redirect(to: ~p"/account/sessions")

      {:error, _reason} ->
        revoke_failed(conn)
    end
  end

  def revoke(conn, _params), do: revoke_failed(conn)

  defp spec(key, title, summary),
    do: Map.merge(@session, %{key: key, title: title, summary: summary, query: []})

  defp render_page(conn, template, page, view_model, extra) do
    render(
      conn,
      template,
      [
        page: page,
        view_model: view_model,
        page_title: page.title,
        canonical_url: page.canonical_url,
        current_scope: conn.assigns[:current_scope]
      ] ++ extra
    )
  end

  defp session_view(session) do
    %{
      management_ref: session.management_ref,
      current: session.current,
      assurance: humanize(session.assurance),
      issued_at: Calendar.strftime(session.issued_at, "%Y-%m-%d %H:%M UTC"),
      last_seen_at: Calendar.strftime(session.last_seen_at, "%Y-%m-%d %H:%M UTC"),
      hard_expires_at: Calendar.strftime(session.hard_expires_at, "%Y-%m-%d %H:%M UTC"),
      form: Phoenix.Component.to_form(%{}, as: :session_revoke)
    }
  end

  defp revoke_failed(conn) do
    conn
    |> put_flash(:error, "The selected browser session could not be changed.")
    |> redirect(to: ~p"/account/sessions")
  end

  defp humanize(:baseline), do: "Baseline assurance"
  defp humanize(:phishing_resistant), do: "Phishing-resistant assurance"
  defp humanize(:action_bound_step_up), do: "Action-bound step-up"
end
