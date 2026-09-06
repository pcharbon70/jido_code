defmodule JidoCodeWeb.StreamContext do
  @moduledoc "Trusted stream identity; correlation can select a transport, never a grant."
  alias JidoCode.Identity.Sessions
  alias JidoCodeWeb.ReadResponse

  def build(conn, page) do
    with {:ok, %{session: session, account: account}} <-
           Sessions.validate(conn.assigns.authenticated_human.session_ref, touch: false) do
      scope = Map.get(page.authorization, :current_scope, %{})
      intent = conn.private.stream_intent

      context = %{
        subject: account.subject_ref,
        session: session.session_ref,
        session_generation: session.session_generation,
        account_generation: session.account_generation,
        tenant: Map.get(scope, :tenant_ref),
        project: Map.get(scope, :project_ref),
        resource: Map.get(scope, :resource_ref),
        route: conn.request_path,
        projection: page.key,
        query: page.query,
        fingerprint: ReadResponse.fingerprint(page.authorization),
        hard_expires_at: DateTime.to_unix(session.hard_expires_at, :millisecond),
        idle_expires_at: DateTime.to_unix(session.idle_expires_at, :millisecond),
        tab: intent.tab,
        request: intent.request
      }

      case validate_cursor(
             context,
             intent.cursor,
             Plug.Conn.get_req_header(conn, "last-event-id")
           ) do
        :ok -> {:ok, context}
        _ -> {:error, :invalid_cursor}
      end
    end
  end

  def cursor(context) do
    Phoenix.Token.sign(JidoCodeWeb.Endpoint, "product-stream-cursor-v1", digest(context))
  end

  def validate_cursor(context, cursor, headers) when headers == [] or headers == [cursor] do
    case cursor do
      nil ->
        :ok

      value ->
        case Phoenix.Token.verify(JidoCodeWeb.Endpoint, "product-stream-cursor-v1", value,
               max_age: 120
             ) do
          {:ok, digest} -> if digest == digest(context), do: :ok, else: {:error, :invalid_cursor}
          _ -> {:error, :invalid_cursor}
        end
    end
  end

  def validate_cursor(_, _, _), do: {:error, :invalid_cursor}

  defp digest(context) do
    context
    |> Map.take([
      :subject,
      :session,
      :session_generation,
      :account_generation,
      :tenant,
      :project,
      :resource,
      :route,
      :projection,
      :query,
      :tab
    ])
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
  end
end
