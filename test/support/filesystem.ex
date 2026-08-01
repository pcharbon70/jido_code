defmodule JidoCode.TestSupport.Filesystem do
  @moduledoc false

  def remove_root!(root, attempts \\ 20)
  def remove_root!(root, 0), do: File.rm_rf!(root)

  def remove_root!(root, attempts) do
    case File.rm_rf(root) do
      {:ok, _entries} ->
        :ok

      {:error, _reason, _path} ->
        Process.sleep(25)
        remove_root!(root, attempts - 1)
    end
  end
end
