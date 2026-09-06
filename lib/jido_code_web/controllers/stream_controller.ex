defmodule JidoCodeWeb.StreamController do
  @moduledoc "Explicit stream connects reuse native controllers under a distinct stream authorization."
  use JidoCodeWeb, :controller
  alias JidoCode.Product.StreamCoordinator
  alias JidoCodeWeb.{ReadController, ReadSecurity, ReadSignals, StreamDelivery, StreamIntent}

  def factory(conn, params), do: connect(conn, params, :factory)
  def fleet(conn, params), do: connect(conn, params, :fleet)
  def projects(conn, params), do: connect(conn, params, :projects)
  def project(conn, params), do: connect(conn, params, :project)
  def project_attempts(conn, params), do: connect(conn, params, :project_attempts)
  def project_wiki(conn, params), do: connect(conn, params, :project_wiki)
  def project_dependencies(conn, params), do: connect(conn, params, :project_dependencies)
  def attempt(conn, params), do: connect(conn, params, :attempt)
  def account(conn, params), do: connect(conn, params, :account)
  def sessions(conn, params), do: connect(conn, params, :sessions)

  defp connect(conn, params, surface) do
    case StreamIntent.decode(surface, conn.private[:read_raw_body]) do
      {:ok, intent} ->
        try do
          conn =
            conn
            |> put_format("html")
            |> put_private(:stream_intent, intent)
            |> put_private(
              :read_raw_body,
              Jason.encode!(%{ReadSignals.namespace(surface) => intent.query})
            )

          # `surface` is an atom literal from the explicit functions above.
          conn = apply(ReadController, surface, [conn, params])
          if conn.private[:stream_snapshot], do: StreamDelivery.deliver(conn), else: conn
        after
          StreamCoordinator.release_owner()
        end

      {:error, _} ->
        ReadSecurity.reject(conn, 422)
    end
  end
end
