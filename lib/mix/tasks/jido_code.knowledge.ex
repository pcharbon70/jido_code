defmodule Mix.Tasks.JidoCode.Knowledge do
  use Mix.Task

  alias JidoCode.Knowledge.Admin
  alias JidoCode.Knowledge.Error

  @shortdoc "Runs a bounded graph-store health or maintenance command"

  @moduledoc """
  Runs a bounded operator command against the configured graph store.

      mix jido_code.knowledge health
      mix jido_code.knowledge integrity
      mix jido_code.knowledge backup
      mix jido_code.knowledge export --format nquads
      mix jido_code.knowledge restore --artifact ARTIFACT_ID --confirm ARTIFACT_ID

  Restore accepts an artifact identifier from the configured backup root. Raw
  source or destination paths and ad hoc graph operations are unsupported.
  """

  @switches [format: :string, artifact: :string, confirm: :string]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    with {options, [command], []} <- OptionParser.parse(args, strict: @switches),
         {:ok, command, options} <- command_options(command, options),
         {:ok, result} <- Admin.execute(command, options) do
      result
      |> json_value()
      |> Jason.encode!(pretty: true)
      |> Mix.shell().info()
    else
      {:error, %Error{} = error} -> Mix.raise(error.message <> " (#{error.operation})")
      _invalid -> Mix.raise("invalid knowledge command; run mix help jido_code.knowledge")
    end
  end

  defp command_options("health", []), do: {:ok, :health, []}
  defp command_options("integrity", []), do: {:ok, :integrity, []}
  defp command_options("backup", []), do: {:ok, :backup, []}

  defp command_options("export", options) do
    case {Keyword.keys(options), Keyword.get(options, :format)} do
      {[:format], "nquads"} -> {:ok, :export, [format: :nquads]}
      {[:format], "trig"} -> {:ok, :export, [format: :trig]}
      _invalid -> :error
    end
  end

  defp command_options("restore", options) do
    artifact = Keyword.get(options, :artifact)
    confirmation = Keyword.get(options, :confirm)

    if Enum.sort(Keyword.keys(options)) == [:artifact, :confirm] and is_binary(artifact) and
         artifact != "" and confirmation == artifact do
      {:ok, :restore, artifact: artifact, confirm: confirmation}
    else
      :error
    end
  end

  defp command_options(_command, _options), do: :error

  defp json_value(value) when is_struct(value) do
    value |> Map.from_struct() |> json_value()
  end

  defp json_value(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {key, json_value(nested)} end)
  end

  defp json_value(value) when is_list(value), do: Enum.map(value, &json_value/1)
  defp json_value(value), do: value
end
