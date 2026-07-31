defmodule Mix.Tasks.JidoCode.Ontology do
  use Mix.Task

  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.Ontology.Release

  @shortdoc "Verifies, canonicalizes, checksums, or loads an ontology release"

  @moduledoc """
  Operates on a digest-pinned local ontology release.

      mix jido_code.ontology verify
      mix jido_code.ontology checksum
      mix jido_code.ontology canonical
      mix jido_code.ontology load

  The command never resolves imports over the network. `load` writes the
  current immutable package only to its registered ontology version graph.
  """

  @impl Mix.Task
  def run(["verify"]) do
    print_json(Release.verify())
  end

  def run(["checksum"]) do
    print_json(Release.checksum())
  end

  def run(["canonical"]) do
    case Release.canonical_nquads() do
      {:ok, canonical} -> Mix.shell().info(canonical)
      {:error, %Error{} = error} -> fail(error)
    end
  end

  def run(["load"]) do
    Mix.Task.run("app.start")
    print_json(Release.load())
  end

  def run(_args), do: Mix.raise("invalid ontology command; run mix help jido_code.ontology")

  defp print_json({:ok, value}) do
    value
    |> json_value()
    |> Jason.encode!(pretty: true)
    |> Mix.shell().info()
  end

  defp print_json({:error, %Error{} = error}), do: fail(error)
  defp print_json(_unexpected), do: Mix.raise("ontology command failed")

  defp fail(error), do: Mix.raise(error.message <> " (#{error.operation})")

  defp json_value(value) when is_struct(value), do: value |> Map.from_struct() |> json_value()

  defp json_value(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {key, json_value(nested)} end)
  end

  defp json_value(value) when is_list(value), do: Enum.map(value, &json_value/1)
  defp json_value(value), do: value
end
