defmodule JidoCode.Factory.ManagedCoding.MutationRequest do
  @moduledoc "Exact linearization-point authority for one managed workspace mutation."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @enforce_keys [
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :workspace_iri,
    :workspace_root,
    :workspace_digest,
    :snapshot_iri,
    :capability_iri,
    :policy_revision,
    :allowed_paths,
    :protected_paths,
    :limits
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @digest ~r/^[a-f0-9]{64}$/

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    resources = ~w[attempt_iri lease_iri workspace_iri snapshot_iri capability_iri]a

    with true <-
           Enum.all?(resources, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         root when is_binary(root) <- attributes[:workspace_root],
         true <- Path.type(root) == :absolute,
         {:ok, %File.Stat{type: :directory}} <- File.lstat(root),
         true <- digest?(attributes[:workspace_digest]),
         true <- digest?(attributes[:policy_revision]),
         {:ok, allowed} <- paths(attributes[:allowed_paths], false),
         {:ok, protected} <- paths(attributes[:protected_paths], true),
         limits when is_map(limits) <- attributes[:limits],
         true <-
           Enum.all?(~w[disk_bytes changed_files diff_bytes output_bytes]a, fn key ->
             is_integer(limits[key]) and limits[key] > 0
           end) do
      {:ok,
       struct!(
         __MODULE__,
         attributes
         |> Map.take(@enforce_keys)
         |> Map.put(:allowed_paths, allowed)
         |> Map.put(:protected_paths, protected)
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  defp paths(paths, empty?) when is_list(paths) and length(paths) <= 64 do
    if (empty? or paths != []) and Enum.all?(paths, &relative?/1),
      do: {:ok, paths |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp paths(_paths, _empty?), do: :error

  defp relative?(path) when is_binary(path) and byte_size(path) in 1..512//1,
    do:
      String.normalize(path, :nfc) == path and Path.type(path) == :relative and
        Enum.all?(Path.split(path), &(&1 not in ["", ".", ".."]))

  defp relative?(_path), do: false
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_mutation)}
end
