defmodule JidoCode.Factory.DelegatedCandidate do
  @moduledoc "Immutable controller-recomputed delegated coding proposal with no decision authority."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.DelegatedCheckpoint
  alias JidoCode.Knowledge

  @digest ~r/^[a-f0-9]{64}$/
  @operations ~w[add modify delete]a
  @check_statuses ~w[success failure timeout unavailable]a
  @omissions ~w[internal_prompts hidden_reasoning provider_context internal_tool_mediation provider_private_state]a

  @enforce_keys [
    :candidate_iri,
    :candidate_digest,
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :source_snapshot_iri,
    :base_commit,
    :checkpoint_iri,
    :checkpoint_digest,
    :delegated_profile_iri,
    :profile_digest,
    :adapter_release_digest,
    :cli_digest,
    :model_digest,
    :sandbox_revision,
    :policy_revision,
    :tool_manifest_digest,
    :check_registry_revision,
    :candidate_protocol_revision,
    :patch_artifact_iri,
    :patch_digest,
    :patch_bytes,
    :tree_digest,
    :changed_files,
    :generated_artifacts,
    :check_receipts,
    :secret_scan_evidence_iri,
    :secret_scan_digest,
    :terminal_summary_digest,
    :accounting_digest,
    :accounting_omissions,
    :captured_at,
    :candidate_status,
    :verification_status,
    :evidence_sufficiency,
    :disposition,
    :acceptance_authority,
    :publication_authority,
    :merge_authority,
    :goal_satisfied
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec secret_scan_identity(DelegatedCheckpoint.t(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
  def secret_scan_identity(%DelegatedCheckpoint{} = checkpoint, patch_digest)
      when is_binary(patch_digest) do
    Knowledge.deterministic_resource_identity(
      :artifact_finding,
      Enum.join([checkpoint.checkpoint_digest, patch_digest, "clean"], "\n")
    )
  end

  def secret_scan_identity(_checkpoint, _patch_digest), do: invalid()

  @spec new(DelegatedCheckpoint.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%DelegatedCheckpoint{} = checkpoint, attributes) when is_map(attributes) do
    with :ok <- checkpoint_match(checkpoint, attributes),
         :ok <- resources(attributes),
         true <- Enum.all?(digest_fields(), &digest?(attributes[&1])),
         {:ok, changed_files} <- changed_files(attributes[:changed_files]),
         true <- Enum.map(changed_files, & &1.path) == checkpoint.changed_paths,
         {:ok, generated} <- generated_artifacts(attributes[:generated_artifacts], changed_files),
         {:ok, checks} <- check_receipts(attributes[:check_receipts], checkpoint),
         true <- attributes[:accounting_omissions] == @omissions,
         %DateTime{} = captured_at <- attributes[:captured_at],
         material <- material(checkpoint, attributes, changed_files, generated, checks),
         candidate_digest <- digest(material),
         {:ok, candidate_iri} <-
           Knowledge.deterministic_resource_identity(:patch_artifact, candidate_digest) do
      {:ok,
       struct!(
         __MODULE__,
         Map.merge(material, %{
           candidate_iri: candidate_iri,
           candidate_digest: candidate_digest,
           captured_at: DateTime.truncate(captured_at, :microsecond),
           candidate_status: :ready,
           verification_status: :not_started,
           evidence_sufficiency: :unknown,
           disposition: :proposed,
           acceptance_authority: false,
           publication_authority: false,
           merge_authority: false,
           goal_satisfied: false
         })
       )}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_checkpoint, _attributes), do: invalid()

  @spec material(t()) :: map()
  def material(%__MODULE__{} = candidate) do
    candidate
    |> Map.from_struct()
    |> Map.drop([
      :candidate_iri,
      :candidate_digest,
      :captured_at,
      :candidate_status,
      :verification_status,
      :evidence_sufficiency,
      :disposition,
      :acceptance_authority,
      :publication_authority,
      :merge_authority,
      :goal_satisfied
    ])
  end

  defp material(checkpoint, attributes, changed_files, generated, checks) do
    %{
      attempt_iri: checkpoint.attempt_iri,
      lease_iri: checkpoint.lease_iri,
      fencing_token: checkpoint.fencing_token,
      source_snapshot_iri: checkpoint.source_snapshot_iri,
      base_commit: checkpoint.base_commit,
      checkpoint_iri: checkpoint.checkpoint_iri,
      checkpoint_digest: checkpoint.checkpoint_digest,
      delegated_profile_iri: attributes.delegated_profile_iri,
      profile_digest: attributes.profile_digest,
      adapter_release_digest: attributes.adapter_release_digest,
      cli_digest: attributes.cli_digest,
      model_digest: attributes.model_digest,
      sandbox_revision: attributes.sandbox_revision,
      policy_revision: attributes.policy_revision,
      tool_manifest_digest: attributes.tool_manifest_digest,
      check_registry_revision: attributes.check_registry_revision,
      candidate_protocol_revision: attributes.candidate_protocol_revision,
      patch_artifact_iri: checkpoint.patch_artifact_iri,
      patch_digest: checkpoint.patch_digest,
      patch_bytes: checkpoint.patch_bytes,
      tree_digest: checkpoint.tree_digest,
      changed_files: changed_files,
      generated_artifacts: generated,
      check_receipts: checks,
      secret_scan_evidence_iri: attributes.secret_scan_evidence_iri,
      secret_scan_digest: attributes.secret_scan_digest,
      terminal_summary_digest: attributes.terminal_summary_digest,
      accounting_digest: checkpoint.accounting_digest,
      accounting_omissions: attributes.accounting_omissions
    }
  end

  defp checkpoint_match(checkpoint, attributes) do
    if attributes[:attempt_iri] == checkpoint.attempt_iri and
         attributes[:lease_iri] == checkpoint.lease_iri and
         attributes[:fencing_token] == checkpoint.fencing_token and
         attributes[:source_snapshot_iri] == checkpoint.source_snapshot_iri and
         attributes[:base_commit] == checkpoint.base_commit and
         attributes[:patch_digest] == checkpoint.patch_digest and
         attributes[:tree_digest] == checkpoint.tree_digest,
       do: :ok,
       else: :error
  end

  defp resources(attributes) do
    if Enum.all?(~w[delegated_profile_iri secret_scan_evidence_iri]a, fn field ->
         Knowledge.validate_resource_identity(attributes[field]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp digest_fields do
    ~w[profile_digest adapter_release_digest cli_digest model_digest sandbox_revision policy_revision tool_manifest_digest check_registry_revision candidate_protocol_revision secret_scan_digest terminal_summary_digest]a
  end

  defp changed_files(files) when is_list(files) and files != [] and length(files) <= 1_000 do
    with true <- Enum.all?(files, &valid_file?/1),
         paths <- Enum.map(files, & &1.path),
         true <- paths == Enum.uniq(paths) do
      {:ok, Enum.sort_by(files, & &1.path)}
    else
      _invalid -> :error
    end
  end

  defp changed_files(_files), do: :error

  defp valid_file?(file) when is_map(file) do
    Enum.sort(Map.keys(file)) ==
      Enum.sort([:binary?, :digest, :mode, :operation, :path, :size]) and
      valid_path?(file.path) and file.operation in @operations and digest?(file.digest) and
      is_integer(file.size) and file.size >= 0 and file.mode in [0o644, 0o755, :deleted] and
      is_boolean(file.binary?) and coherent_file?(file)
  end

  defp valid_file?(_file), do: false
  defp coherent_file?(%{operation: :delete, mode: :deleted}), do: true

  defp coherent_file?(%{operation: operation, mode: mode}) when operation in [:add, :modify],
    do: mode in [0o644, 0o755]

  defp coherent_file?(_file), do: false

  defp generated_artifacts(values, changed_files)
       when is_list(values) and length(values) <= 128 do
    changed = Map.new(changed_files, &{&1.path, &1})

    if Enum.all?(values, fn
         %{path: path, digest: digest} ->
           valid_path?(path) and digest?(digest) and match?(%{digest: ^digest}, changed[path])

         _invalid ->
           false
       end) do
      {:ok, values |> Enum.uniq() |> Enum.sort_by(& &1.path)}
    else
      :error
    end
  end

  defp generated_artifacts(_values, _changed_files), do: :error

  defp check_receipts(values, checkpoint) when is_list(values) and length(values) <= 64 do
    valid =
      Enum.all?(values, fn receipt ->
        is_map(receipt) and is_binary(receipt[:check]) and
          receipt[:status] in @check_statuses and digest?(receipt[:command_digest]) and
          digest?(receipt[:output_digest]) and digest?(receipt[:receipt_digest]) and
          receipt[:attempt_iri] == checkpoint.attempt_iri and
          receipt[:lease_iri] == checkpoint.lease_iri and
          receipt[:fencing_token] == checkpoint.fencing_token and
          receipt[:source_snapshot_iri] == checkpoint.source_snapshot_iri and
          receipt[:workspace_iri] == checkpoint.workspace_iri and
          receipt[:workspace_digest] == checkpoint.workspace_digest
      end)

    names = Enum.map(values, & &1.check)

    if valid and names == Enum.uniq(names),
      do: {:ok, Enum.sort_by(values, & &1.check)},
      else: :error
  end

  defp check_receipts(_values, _checkpoint), do: :error

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

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :delegated_candidate)}
end
