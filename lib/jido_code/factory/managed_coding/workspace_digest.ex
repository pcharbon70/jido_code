defmodule JidoCode.Factory.ManagedCoding.WorkspaceDigest do
  @moduledoc "Canonical filesystem digests for disposable managed coding workspaces."

  alias JidoCode.Factory.AdapterError

  @spec tree(Path.t(), map()) :: {:ok, map()} | {:error, AdapterError.t()}
  def tree(root, limits) when is_binary(root) and is_map(limits) do
    with {:ok, files} <- regular_files(root),
         true <- length(files) <= limits.file_count,
         {:ok, entries} <- entries(root, files, limits.input_bytes),
         bytes = Enum.reduce(entries, 0, &(&1.bytes + &2)),
         true <- bytes <= limits.disk_bytes do
      {:ok,
       %{
         digest: digest(entries),
         file_count: length(entries),
         byte_count: bytes,
         entries: entries
       }}
    else
      _invalid -> {:error, AdapterError.new(:unauthorized, :workspace_limits)}
    end
  rescue
    _error -> {:error, AdapterError.new(:unavailable, :workspace_digest)}
  end

  def tree(_root, _limits), do: {:error, AdapterError.new(:invalid_input, :workspace_digest)}

  @spec digest(term()) :: String.t()
  def digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp regular_files(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.reject(&(Path.relative_to(&1, root) == ".git"))
    |> Enum.reduce_while({:ok, []}, fn path, {:ok, files} ->
      case File.lstat(path) do
        {:ok, %File.Stat{type: :regular}} -> {:cont, {:ok, [path | files]}}
        {:ok, %File.Stat{type: :directory}} -> {:cont, {:ok, files}}
        _special_or_symlink -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, files} -> {:ok, Enum.sort(files)}
      :error -> :error
    end
  end

  defp entries(root, files, max_input) do
    Enum.reduce_while(files, {:ok, []}, fn path, {:ok, entries} ->
      with {:ok, stat} <- File.stat(path),
           true <- stat.size <= max_input,
           {:ok, content} <- File.read(path) do
        entry = %{
          path: Path.relative_to(path, root),
          mode: stat.mode,
          bytes: stat.size,
          digest: digest(content)
        }

        {:cont, {:ok, [entry | entries]}}
      else
        _invalid -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, entries} -> {:ok, Enum.sort_by(entries, & &1.path)}
      :error -> :error
    end
  end
end
