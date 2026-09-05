defmodule JidoCodeWeb.ProjectController do
  use JidoCodeWeb, :controller

  alias JidoCodeWeb.ProductController
  alias JidoCodeWeb.ProductRequest

  @factory %{resource: :factory, operation: :project_page, area: :developer}
  @project %{
    resource: {:resource, "project_ref", :project},
    operation: :project_page,
    area: :developer
  }

  def index(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(@factory, :projects, "Projects", "Authorized repository-backed projects."),
        :index
      )

  def overview(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(
          @project,
          :project,
          "Project overview",
          "Repository identity, readiness, and work context."
        ),
        :overview
      )

  def attempts(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(
          @project,
          :project_attempts,
          "Project attempts",
          "Authorized attempts for this project."
        ),
        :attempts
      )

  def wiki(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(
          @project,
          :project_wiki,
          "Project wiki",
          "Current authorized repository knowledge edition."
        ),
        :wiki
      )

  def dependencies(conn, params),
    do:
      ProductController.serve(
        conn,
        params,
        spec(
          @project,
          :project_dependencies,
          "Project dependencies",
          "Bounded dependency posture for this project."
        ),
        :dependencies
      )

  def switch(conn, params) do
    spec = spec(@project, :project_switch, "Project switch", "Open an authorized project.")

    case ProductRequest.authorize(conn, spec, params) do
      {:ok, conn, %{route_params: %{resource_ref: project_ref}}} ->
        redirect(conn, to: ~p"/projects/#{project_ref}")

      {:error, conn} ->
        conn
    end
  end

  defp spec(base, key, title, summary),
    do:
      Map.merge(base, %{key: key, title: title, summary: summary, query: ["q", "state", "page"]})
end
