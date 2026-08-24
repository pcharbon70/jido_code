defmodule JidoCode.Factory.ManagedCoding.ReadRequest do
  @moduledoc "Exact authority and bounds for managed source discovery and reads."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @enforce_keys [
    :repository_iri,
    :snapshot_iri,
    :actor_iri,
    :workspace_iri,
    :workspace_root,
    :workspace_digest,
    :analysis_revision,
    :allowed_paths,
    :visible_classifications,
    :max_results,
    :max_bytes
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}
  @digest ~r/^[a-f0-9]{64}$/

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with true <-
           Enum.all?(~w[repository_iri snapshot_iri actor_iri workspace_iri]a, fn key ->
             Knowledge.validate_resource_identity(attributes[key]) == :ok
           end),
         root when is_binary(root) <- attributes[:workspace_root],
         true <- Path.type(root) == :absolute,
         {:ok, %File.Stat{type: :directory}} <- File.lstat(root),
         true <- digest?(attributes[:workspace_digest]),
         true <- digest?(attributes[:analysis_revision]),
         paths when is_list(paths) and paths != [] and length(paths) <= 64 <-
           attributes[:allowed_paths],
         true <- Enum.all?(paths, &relative_path?/1),
         classifications when is_list(classifications) and classifications != [] <-
           attributes[:visible_classifications],
         true <- Enum.all?(classifications, &(&1 in [:public, :internal, :confidential])),
         maximum when is_integer(maximum) and maximum in 1..100 <- attributes[:max_results],
         bytes when is_integer(bytes) and bytes in 1..262_144 <- attributes[:max_bytes] do
      {:ok,
       struct!(
         __MODULE__,
         attributes
         |> Map.take(@enforce_keys)
         |> Map.update!(:allowed_paths, &(&1 |> Enum.uniq() |> Enum.sort()))
         |> Map.update!(:visible_classifications, &(&1 |> Enum.uniq() |> Enum.sort()))
       )}
    else
      _invalid -> {:error, AdapterError.new(:invalid_input, :managed_coding_read)}
    end
  rescue
    _error -> {:error, AdapterError.new(:invalid_input, :managed_coding_read)}
  end

  def new(_attributes), do: {:error, AdapterError.new(:invalid_input, :managed_coding_read)}

  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp relative_path?(path) when is_binary(path) and byte_size(path) in 1..512//1,
    do:
      String.normalize(path, :nfc) == path and Path.type(path) == :relative and
        Enum.all?(Path.split(path), &(&1 not in ["", ".", ".."]))

  defp relative_path?(_path), do: false
end
