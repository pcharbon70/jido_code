defmodule Mix.Tasks.JidoCode.Bootstrap do
  @moduledoc "Initializes the ontology and graph authority on a pristine dataset."

  use Mix.Task

  alias JidoCode.Install

  @shortdoc "Bootstrap a pristine JidoCode graph dataset"

  @impl true
  def run(["--confirm", "INITIALIZE"]) do
    token =
      System.get_env("JIDO_CODE_OPERATOR_TOKEN") ||
        Mix.raise("JIDO_CODE_OPERATOR_TOKEN is required")

    if byte_size(token) < 24 do
      Mix.raise("JIDO_CODE_OPERATOR_TOKEN must contain at least 24 bytes")
    end

    Mix.Task.run("app.start")

    case Install.bootstrap(token) do
      {:ok, receipt} ->
        receipt
        |> json_value()
        |> Jason.encode!(pretty: true)
        |> Mix.shell().info()

      {:error, error} ->
        Mix.raise("clean install failed: #{error.kind}/#{error.operation}")
    end
  end

  def run(_arguments),
    do: Mix.raise("usage: mix jido_code.bootstrap --confirm INITIALIZE")

  defp json_value(value) when is_map(value),
    do: Map.new(value, fn {key, item} -> {key, json_value(item)} end)

  defp json_value(value) when is_list(value), do: Enum.map(value, &json_value/1)
  defp json_value(value), do: value
end
