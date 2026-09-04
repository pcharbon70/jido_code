defmodule Mix.Tasks.Hui.B4.ProductionBoundary do
  use Mix.Task

  @shortdoc "Verifies the HUI qualification fixture is absent from production"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    unless Mix.env() == :prod do
      Mix.raise("hui.b4.production_boundary must run with MIX_ENV=prod")
    end

    qualification_routes =
      JidoCodeWeb.Router.__routes__()
      |> Enum.filter(&String.starts_with?(&1.path, "/__qualification"))

    previous = Application.get_env(:jido_code, :hypermedia_qualification)

    children =
      try do
        Application.put_env(:jido_code, :hypermedia_qualification,
          enabled: true,
          allowed_hosts: ["127.0.0.1"]
        )

        JidoCode.Application.qualification_children()
      after
        restore(previous)
      end

    build_enabled? = Application.get_env(:jido_code, :hypermedia_qualification_build, false)

    case {build_enabled?, qualification_routes, children} do
      {false, [], []} ->
        Mix.shell().info("HUI-B4 production route and supervision boundary passed")

      other ->
        Mix.raise("qualification fixture leaked into production: #{inspect(other)}")
    end
  end

  defp restore(nil), do: Application.delete_env(:jido_code, :hypermedia_qualification)
  defp restore(value), do: Application.put_env(:jido_code, :hypermedia_qualification, value)
end
