defmodule JidoCode.Factory.ManagedCoding.WorkspaceSpec do
  @moduledoc "Exact, bounded authority contract for one disposable coding worktree."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :iri,
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :repository_iri,
    :snapshot_iri,
    :source_root,
    :base_commit,
    :sandbox_profile_revision,
    :allowed_paths,
    :limits
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @commit ~r/^[a-f0-9]{40}$/
  @digest ~r/^[a-f0-9]{64}$/
  @limit_keys ~w[file_count input_bytes output_bytes disk_bytes processes memory_bytes wall_time_ms idle_time_ms changed_files diff_bytes]a

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         root when is_binary(root) <- attributes[:source_root],
         true <- Path.type(root) == :absolute,
         {:ok, %File.Stat{type: :directory}} <- File.lstat(root),
         commit when is_binary(commit) <- attributes[:base_commit],
         true <- Regex.match?(@commit, commit),
         revision when is_binary(revision) <- attributes[:sandbox_profile_revision],
         true <- Regex.match?(@digest, revision),
         {:ok, paths} <- paths(attributes[:allowed_paths]),
         {:ok, limits} <- limits(attributes[:limits]),
         {:ok, iri} <-
           ResourceIdentity.deterministic(
             :sandbox_instance,
             Enum.join(
               [
                 attributes.attempt_iri,
                 attributes.snapshot_iri,
                 fence,
                 commit,
                 revision
               ],
               "\n"
             )
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         attempt_iri: attributes.attempt_iri,
         lease_iri: attributes.lease_iri,
         fencing_token: fence,
         repository_iri: attributes.repository_iri,
         snapshot_iri: attributes.snapshot_iri,
         source_root: root,
         base_commit: commit,
         sandbox_profile_revision: revision,
         allowed_paths: paths,
         limits: limits
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp resources(attributes) do
    if Enum.all?(~w[attempt_iri lease_iri repository_iri snapshot_iri]a, fn key ->
         Knowledge.validate_resource_identity(attributes[key]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp paths(paths) when is_list(paths) and paths != [] and length(paths) <= 64 do
    if Enum.all?(paths, &valid_path?/1),
      do: {:ok, paths |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp paths(_paths), do: :error

  defp valid_path?(path) when is_binary(path) and byte_size(path) in 1..512//1 do
    String.normalize(path, :nfc) == path and Path.type(path) == :relative and
      not String.contains?(path, ["\\", <<0>>, "//"]) and
      Enum.all?(Path.split(path), &(&1 not in ["", ".", ".."]))
  end

  defp valid_path?(_path), do: false

  defp limits(limits) when is_map(limits) do
    if Enum.sort(Map.keys(limits)) == Enum.sort(@limit_keys) and
         Enum.all?(limits, fn {_key, value} -> is_integer(value) and value > 0 end),
       do: {:ok, limits},
       else: :error
  end

  defp limits(_limits), do: :error
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_workspace)}
end
