defmodule JidoCodeWeb.ReadEnhancement do
  @moduledoc "Code-owned routes and static expressions for native-first finite read enhancement."
  alias JidoCodeWeb.ReadSignals

  def supported?(surface), do: surface in ReadSignals.surfaces()

  def attributes(page, conn) do
    if supported?(page.key) do
      [
        {"data-read-endpoint", endpoint(page)},
        {"data-read-namespace", ReadSignals.namespace(page.key)},
        {"data-read-native", conn.request_path},
        {"data-on:submit", "@readProjection(evt)"},
        {"data-on:click", "@readProjection(evt)"}
      ]
    else
      []
    end
  end

  def native_url(page) do
    uri = URI.parse(page.canonical_url)
    uri.path <> if(uri.query, do: "?" <> uri.query, else: "")
  end

  defp endpoint(%{key: :factory}), do: "/ui/reads/factory"
  defp endpoint(%{key: :fleet}), do: "/ui/reads/fleet"
  defp endpoint(%{key: :projects}), do: "/ui/reads/projects"
  defp endpoint(%{key: :account}), do: "/ui/reads/account"
  defp endpoint(%{key: :sessions}), do: "/ui/reads/sessions"
  defp endpoint(%{key: :project, route_params: params}), do: project(params) <> "/overview"

  defp endpoint(%{key: :project_attempts, route_params: params}),
    do: project(params) <> "/attempts"

  defp endpoint(%{key: :project_wiki, route_params: params}), do: project(params) <> "/wiki"

  defp endpoint(%{key: :project_dependencies, route_params: params}),
    do: project(params) <> "/dependencies"

  defp endpoint(%{key: :attempt, route_params: params}),
    do:
      "/ui/reads/projects/" <>
        URI.encode_www_form(params.parent_ref) <>
        "/attempts/" <> URI.encode_www_form(params.resource_ref)

  defp project(params), do: "/ui/reads/projects/" <> URI.encode_www_form(params.resource_ref)
end
