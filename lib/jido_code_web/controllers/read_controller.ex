defmodule JidoCodeWeb.ReadController do
  @moduledoc "Explicit finite read handlers, each using its existing native controller and query boundary."
  use JidoCodeWeb, :controller
  alias JidoCode.Product.ReadRequestLimiter

  alias JidoCodeWeb.{
    AccountController,
    AttemptController,
    FactoryController,
    ProjectController,
    ReadSecurity,
    ReadSignals
  }

  def factory(conn, params),
    do: serve(conn, params, :factory, "/factory", FactoryController, :attention)

  def fleet(conn, params),
    do: serve(conn, params, :fleet, "/factory/fleet", FactoryController, :fleet)

  def projects(conn, params),
    do: serve(conn, params, :projects, "/projects", ProjectController, :index)

  def project(conn, params),
    do: serve(conn, params, :project, project_path(params), ProjectController, :overview)

  def project_attempts(conn, params),
    do:
      serve(
        conn,
        params,
        :project_attempts,
        project_path(params) <> "/attempts",
        ProjectController,
        :attempts
      )

  def project_wiki(conn, params),
    do:
      serve(
        conn,
        params,
        :project_wiki,
        project_path(params) <> "/wiki",
        ProjectController,
        :wiki
      )

  def project_dependencies(conn, params),
    do:
      serve(
        conn,
        params,
        :project_dependencies,
        project_path(params) <> "/dependencies",
        ProjectController,
        :dependencies
      )

  def attempt(conn, params),
    do:
      serve(
        conn,
        params,
        :attempt,
        project_path(params) <> "/attempts/" <> params["attempt_ref"],
        AttemptController,
        :show
      )

  def account(conn, params),
    do: serve(conn, params, :account, "/account", AccountController, :show)

  def sessions(conn, params),
    do: serve(conn, params, :sessions, "/account/sessions", AccountController, :sessions)

  defp project_path(params), do: "/projects/" <> params["project_ref"]

  defp serve(conn, params, surface, native_path, controller, action) do
    with {:ok, lease} <-
           ReadRequestLimiter.acquire(conn.assigns.authenticated_human.account.subject_ref) do
      try do
        case ReadSignals.decode(surface, conn.private[:read_raw_body]) do
          {:ok, query} ->
            conn =
              conn
              |> assign(:enhanced_read, surface)
              |> put_view(
                html:
                  Module.concat(
                    JidoCodeWeb,
                    controller
                    |> Module.split()
                    |> List.last()
                    |> String.replace("Controller", "HTML")
                  )
              )
              |> Map.put(:request_path, native_path)
              |> Map.put(:query_string, URI.encode_query(query))

            apply(controller, action, [
              conn,
              Map.merge(Map.take(params, ["project_ref", "attempt_ref"]), query)
            ])

          {:error, _reason} ->
            ReadSecurity.reject(conn, 422)
        end
      after
        ReadRequestLimiter.release(lease)
      end
    else
      {:error, :rate_limited} ->
        conn |> put_resp_header("retry-after", "60") |> ReadSecurity.reject(429)

      {:error, _unavailable} ->
        ReadSecurity.reject(conn, 503)
    end
  end
end
