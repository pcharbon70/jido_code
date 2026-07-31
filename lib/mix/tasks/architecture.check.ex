defmodule Mix.Tasks.Architecture.Check do
  use Mix.Task

  alias JidoCode.Architecture.Checker
  alias JidoCode.Architecture.Violation

  @shortdoc "Checks graph-only persistence and module boundaries"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    case Checker.check() do
      {:ok, []} ->
        Mix.shell().info("Architecture checks passed")

      {:error, violations} ->
        Enum.each(violations, &Mix.shell().error(Violation.format(&1)))
        Mix.raise("architecture checks failed with #{length(violations)} violation(s)")
    end
  end
end
