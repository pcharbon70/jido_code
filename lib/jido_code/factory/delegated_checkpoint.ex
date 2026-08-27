defmodule JidoCode.Factory.DelegatedCheckpoint do
  @moduledoc "Immutable controller-owned workspace checkpoint accepted only at a turn boundary."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @boundaries ~w[completed_turn explicit_handoff]a
  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys [
    :checkpoint_iri,
    :checkpoint_digest,
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :source_snapshot_iri,
    :base_commit,
    :workspace_iri,
    :workspace_digest,
    :turn,
    :boundary,
    :patch_artifact_iri,
    :patch_digest,
    :patch_bytes,
    :tree_digest,
    :changed_paths,
    :accounting_digest,
    :captured_at,
    :provider_session_required,
    :process_reference_required
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         turn when is_integer(turn) and turn in 1..2 <- attributes[:turn],
         boundary when boundary in @boundaries <- attributes[:boundary],
         commit when is_binary(commit) and byte_size(commit) == 40 <- attributes[:base_commit],
         true <- Regex.match?(~r/^[a-f0-9]{40}$/, commit),
         true <- Enum.all?(digest_fields(), &digest?(attributes[&1])),
         bytes when is_integer(bytes) and bytes in 0..1_048_576 <- attributes[:patch_bytes],
         {:ok, paths} <- paths(attributes[:changed_paths]),
         %DateTime{} = captured_at <- attributes[:captured_at],
         material <- material(attributes, paths),
         checkpoint_digest <- digest(material),
         {:ok, checkpoint_iri} <-
           Knowledge.deterministic_resource_identity(:patch_artifact, checkpoint_digest) do
      {:ok,
       %__MODULE__{
         checkpoint_iri: checkpoint_iri,
         checkpoint_digest: checkpoint_digest,
         attempt_iri: attributes.attempt_iri,
         lease_iri: attributes.lease_iri,
         fencing_token: fence,
         source_snapshot_iri: attributes.source_snapshot_iri,
         base_commit: commit,
         workspace_iri: attributes.workspace_iri,
         workspace_digest: attributes.workspace_digest,
         turn: turn,
         boundary: boundary,
         patch_artifact_iri: attributes.patch_artifact_iri,
         patch_digest: attributes.patch_digest,
         patch_bytes: bytes,
         tree_digest: attributes.tree_digest,
         changed_paths: paths,
         accounting_digest: attributes.accounting_digest,
         captured_at: DateTime.truncate(captured_at, :microsecond),
         provider_session_required: false,
         process_reference_required: false
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec material(t()) :: map()
  def material(%__MODULE__{} = checkpoint) do
    checkpoint
    |> Map.from_struct()
    |> Map.drop([:checkpoint_iri, :checkpoint_digest, :captured_at])
  end

  defp material(attributes, paths) do
    attributes
    |> Map.take(@enforce_keys)
    |> Map.put(:changed_paths, paths)
    |> Map.put(:provider_session_required, false)
    |> Map.put(:process_reference_required, false)
    |> Map.drop([:checkpoint_iri, :checkpoint_digest, :captured_at])
  end

  defp resources(attributes) do
    fields = ~w[attempt_iri lease_iri source_snapshot_iri workspace_iri patch_artifact_iri]a

    if Enum.all?(fields, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: :error
  end

  defp digest_fields,
    do: ~w[workspace_digest patch_digest tree_digest accounting_digest]a

  defp paths(paths) when is_list(paths) and length(paths) <= 1_000 do
    if Enum.all?(paths, &valid_path?/1),
      do: {:ok, paths |> Enum.uniq() |> Enum.sort()},
      else: :error
  end

  defp paths(_paths), do: :error

  defp valid_path?(path) when is_binary(path) and byte_size(path) in 1..1_024 do
    parts = Path.split(path)

    Path.type(path) == :relative and path == Path.join(parts) and
      Enum.all?(parts, &(&1 not in ["", ".", ".."]))
  end

  defp valid_path?(_path), do: false
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :delegated_checkpoint)}
end
