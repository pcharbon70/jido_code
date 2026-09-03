defmodule Mix.Tasks.Architecture.Check do
  use Mix.Task

  alias JidoCode.Architecture.Checker
  alias JidoCode.Architecture.HypermediaUIPhaseA1
  alias JidoCode.Architecture.HypermediaUIPhaseA2
  alias JidoCode.Architecture.Violation

  @shortdoc "Checks graph-only persistence and module boundaries"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    violations = Checker.check() |> errors()
    hui_a1_errors = HypermediaUIPhaseA1.check() |> errors()
    hui_a2_errors = HypermediaUIPhaseA2.check() |> errors()

    Enum.each(violations, &Mix.shell().error(Violation.format(&1)))
    Enum.each(hui_a1_errors, &Mix.shell().error("HUI-A1: #{&1}"))
    Enum.each(hui_a2_errors, &Mix.shell().error("HUI-A2: #{&1}"))

    count = length(violations) + length(hui_a1_errors) + length(hui_a2_errors)

    if count == 0,
      do: Mix.shell().info("Architecture checks passed"),
      else: Mix.raise("architecture checks failed with #{count} violation(s)")
  end

  defp errors({:ok, []}), do: []
  defp errors({:error, errors}), do: errors
end
