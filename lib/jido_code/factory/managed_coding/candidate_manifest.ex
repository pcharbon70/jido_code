defmodule JidoCode.Factory.ManagedCoding.CandidateManifest do
  @moduledoc "Canonical immutable evidence manifest for one managed coding candidate."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.Identity

  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys ~w[candidate_iri candidate_digest attempt_iri fencing_token repository_iri base_snapshot_iri base_revision normalized_patch_digest patch_artifact_iri tree_digest changed_files generated_artifact_iris check_evidence_iris model_invocation_iris tool_invocation_iris terminal_summary_digest policy_revision profile_revision toolchain_revision secret_scan_evidence_iri captured_at]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- resources(attributes),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         true <- Enum.all?(digest_fields(), &digest?(attributes[&1])),
         {:ok, changed_files} <- changed_files(attributes[:changed_files]),
         {:ok, references} <- reference_lists(attributes),
         %DateTime{} = captured_at <- attributes[:captured_at],
         material <- material(attributes, changed_files, references),
         candidate_digest <- digest(material),
         {:ok, candidate_iri} <- Identity.deterministic(:patch_artifact, candidate_digest) do
      values =
        attributes
        |> Map.take(@enforce_keys)
        |> Map.merge(references)
        |> Map.put(:changed_files, changed_files)
        |> Map.put(:candidate_digest, candidate_digest)
        |> Map.put(:candidate_iri, candidate_iri)
        |> Map.put(:captured_at, DateTime.truncate(captured_at, :microsecond))

      {:ok, struct!(__MODULE__, values)}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes), do: invalid()

  @spec material(t()) :: map()
  def material(%__MODULE__{} = manifest) do
    manifest
    |> Map.from_struct()
    |> Map.drop([:candidate_iri, :candidate_digest, :captured_at])
  end

  defp material(attributes, changed_files, references) do
    attributes
    |> Map.take(@enforce_keys)
    |> Map.merge(references)
    |> Map.put(:changed_files, changed_files)
    |> Map.drop([:candidate_iri, :candidate_digest, :captured_at])
  end

  defp resources(attributes) do
    fields =
      ~w[attempt_iri repository_iri base_snapshot_iri patch_artifact_iri secret_scan_evidence_iri]a

    if Enum.all?(fields, &(Identity.validate_resource(attributes[&1]) == :ok)),
      do: :ok,
      else: :error
  end

  defp digest_fields do
    ~w[base_revision normalized_patch_digest tree_digest terminal_summary_digest policy_revision profile_revision toolchain_revision]a
  end

  defp reference_lists(attributes) do
    fields =
      ~w[generated_artifact_iris check_evidence_iris model_invocation_iris tool_invocation_iris]a

    if Enum.all?(fields, fn field ->
         values = attributes[field]

         is_list(values) and length(values) <= 128 and
           Enum.all?(values, &(Identity.validate_resource(&1) == :ok))
       end) do
      {:ok,
       Map.new(fields, fn field -> {field, attributes[field] |> Enum.uniq() |> Enum.sort()} end)}
    else
      :error
    end
  end

  defp changed_files(files) when is_list(files) and files != [] and length(files) <= 1_000 do
    with true <- Enum.all?(files, &valid_file?/1),
         paths <- Enum.map(files, & &1.path),
         true <- length(paths) == length(Enum.uniq(paths)) do
      {:ok, Enum.sort_by(files, & &1.path)}
    else
      _invalid -> :error
    end
  end

  defp changed_files(_files), do: :error

  defp valid_file?(file) when is_map(file) do
    Enum.sort(Map.keys(file)) == Enum.sort([:binary?, :digest, :mode, :path, :size]) and
      valid_path?(file.path) and digest?(file.digest) and
      is_integer(file.size) and file.size >= 0 and file.mode in [0o644, 0o755, :deleted] and
      is_boolean(file.binary?)
  end

  defp valid_file?(_file), do: false

  defp valid_path?(path) when is_binary(path) and byte_size(path) in 1..1_024 do
    normalized = Path.split(path)

    Path.type(path) == :relative and path == Path.join(normalized) and
      not Enum.any?(normalized, &(&1 in ["", ".", ".."]))
  end

  defp valid_path?(_path), do: false
  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :managed_coding_candidate_manifest)}
end
