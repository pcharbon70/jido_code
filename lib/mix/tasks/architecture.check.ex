defmodule Mix.Tasks.Architecture.Check do
  use Mix.Task

  alias JidoCode.Architecture.Checker
  alias JidoCode.Architecture.HypermediaUIPhaseA1
  alias JidoCode.Architecture.Violation

  @shortdoc "Checks graph-only persistence and module boundaries"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("compile")

    source_result = Checker.check()
    hui_result = HypermediaUIPhaseA1.check()

    case {source_result, hui_result} do
      {{:ok, []}, {:ok, []}} ->
        Mix.shell().info("Architecture checks passed")

      {source_result, hui_result} ->
        violations = errors(source_result)
        hui_errors = errors(hui_result)

        Enum.each(violations, &Mix.shell().error(Violation.format(&1)))
        Enum.each(hui_errors, &Mix.shell().error("HUI-A1: #{&1}"))

        count = length(violations) + length(hui_errors)
        Mix.raise("architecture checks failed with #{count} violation(s)")
    end
  end

  defp errors({:ok, []}), do: []
  defp errors({:error, errors}), do: errors
end
