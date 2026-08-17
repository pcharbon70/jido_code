defmodule JidoCode.Integrations.OAuthFileEnrollment do
  @moduledoc "Filesystem validation for explicitly enrolled developer OAuth files."

  import Bitwise

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.OAuthFileReference

  @spec enroll(map(), keyword()) ::
          {:ok, OAuthFileReference.t()} | {:error, AdapterError.t()}
  def enroll(attributes, options) when is_map(attributes) and is_list(options) do
    with {:ok, reference} <- OAuthFileReference.new(attributes),
         :ok <- validate(reference, options) do
      {:ok, reference}
    end
  end

  def enroll(_attributes, _options), do: invalid()

  @spec validate(OAuthFileReference.t(), keyword()) :: :ok | {:error, AdapterError.t()}
  def validate(%OAuthFileReference{} = reference, options) when is_list(options) do
    forbidden_roots = Keyword.get(options, :forbidden_roots, [])

    with true <- valid_roots?(forbidden_roots),
         false <- inside_any_root?(reference.path, forbidden_roots),
         true <- symlink_free_path?(reference.path),
         {:ok, %File.Stat{type: :regular, uid: uid, mode: mode}} <- File.lstat(reference.path),
         true <- uid == reference.expected_uid,
         true <- (mode &&& 0o077) == 0 do
      :ok
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def validate(_reference, _options), do: invalid()

  defp valid_roots?(roots) when is_list(roots) and roots != [] do
    Enum.all?(roots, &(is_binary(&1) and Path.type(&1) == :absolute))
  end

  defp valid_roots?(_roots), do: false

  defp inside_any_root?(path, roots) do
    expanded = Path.expand(path)

    Enum.any?(roots, fn root ->
      relative = Path.relative_to(expanded, Path.expand(root))

      relative == "." or
        (Path.type(relative) == :relative and relative != ".." and
           not String.starts_with?(relative, "../"))
    end)
  end

  defp symlink_free_path?(path) do
    path
    |> Path.split()
    |> Enum.scan(fn segment, parent -> Path.join(parent, segment) end)
    |> Enum.all?(fn component ->
      match?(
        {:ok, %File.Stat{type: type}} when type in [:directory, :regular],
        File.lstat(component)
      )
    end)
  end

  defp invalid, do: {:error, AdapterError.new(:unauthorized, :oauth_file_enrollment)}
end
