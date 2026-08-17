defmodule JidoCode.Factory.Tool.RepositoryPathGuard do
  @moduledoc "Resolves an authorized repository path without following symlink components."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Tool.ResolvedPath

  @modes ~w[existing_file new_file]a

  @spec resolve(Path.t(), Path.t(), [Path.t()], atom()) ::
          {:ok, ResolvedPath.t()} | {:error, AdapterError.t()}
  def resolve(root, relative, prefixes, mode)

  def resolve(root, relative, prefixes, mode)
      when is_binary(root) and is_binary(relative) and is_list(prefixes) and mode in @modes do
    with true <- Path.type(root) == :absolute,
         :ok <- relative_path(relative),
         true <- prefixes != [] and Enum.all?(prefixes, &(relative_path(&1) == :ok)),
         true <- Enum.any?(prefixes, &inside?(relative, &1)),
         {:ok, %File.Stat{type: :directory}} <- File.lstat(root),
         {:ok, absolute} <- walk(root, Path.split(relative), mode) do
      {:ok, %ResolvedPath{absolute: absolute, relative: relative}}
    else
      _invalid -> denied()
    end
  rescue
    _error -> denied()
  end

  def resolve(_root, _relative, _prefixes, _mode), do: denied()

  defp walk(root, components, mode) do
    last = length(components) - 1

    components
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, root}, fn {component, index}, {:ok, parent} ->
      candidate = Path.join(parent, component)

      case {File.lstat(candidate), index == last, mode} do
        {{:ok, %File.Stat{type: :directory}}, false, _mode} ->
          {:cont, {:ok, candidate}}

        {{:ok, %File.Stat{type: :regular}}, true, :existing_file} ->
          {:cont, {:ok, candidate}}

        {{:error, :enoent}, true, :new_file} ->
          {:cont, {:ok, candidate}}

        _symlink_missing_or_wrong_type ->
          {:halt, :error}
      end
    end)
  end

  defp relative_path(path) when is_binary(path) and byte_size(path) in 1..512 do
    valid? =
      Path.type(path) == :relative and
        not String.contains?(path, ["\\", <<0>>, "//"]) and
        not String.starts_with?(path, ["./", "/"]) and
        path == Path.join(Path.split(path)) and
        Enum.all?(Path.split(path), &(&1 not in [".", "..", ""]))

    if valid?, do: :ok, else: :error
  end

  defp relative_path(_path), do: :error

  defp inside?(path, prefix) do
    relative = Path.relative_to(path, prefix)

    relative == "." or
      (Path.type(relative) == :relative and relative != ".." and
         not String.starts_with?(relative, "../"))
  end

  defp denied, do: {:error, AdapterError.new(:unauthorized, :repository_path)}
end
