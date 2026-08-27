defmodule JidoCode.Factory.DelegatedVerificationResult do
  @moduledoc "Independent delegated-candidate verification evidence without acceptance authority."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.DelegatedCandidate
  alias JidoCode.Knowledge

  @statuses ~w[passed failed indeterminate unavailable timed_out]a
  @check_statuses ~w[passed failed timed_out unavailable]a
  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys [
    :verification_iri,
    :candidate_iri,
    :candidate_digest,
    :verifier_actor_iri,
    :verifier_profile_revision,
    :environment_revision,
    :verifier_workspace_digest,
    :status,
    :checks,
    :patch_digest,
    :tree_digest,
    :file_manifest_digest,
    :generated_artifact_digest,
    :secret_scan_digest,
    :evidence_iri,
    :evidence_digest,
    :completed_at,
    :fresh_checkout,
    :delegated_workspace_reused,
    :provider_session_reused,
    :cli_process_reused,
    :acceptance_authority,
    :publication_authority,
    :merge_authority,
    :goal_satisfaction_authority
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(DelegatedCandidate.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%DelegatedCandidate{} = candidate, attributes) when is_map(attributes) do
    with status when status in @statuses <- attributes[:status],
         :ok <- resources(attributes),
         true <- Enum.all?(digest_fields(), &digest?(attributes[&1])),
         {:ok, checks} <- checks(attributes[:checks]),
         true <- coherent_status?(status, checks),
         true <- attributes[:patch_digest] == candidate.patch_digest,
         true <- attributes[:tree_digest] == candidate.tree_digest,
         %DateTime{} = completed_at <- attributes[:completed_at],
         {:ok, verification_iri} <- identity(candidate, attributes, checks) do
      {:ok,
       %__MODULE__{
         verification_iri: verification_iri,
         candidate_iri: candidate.candidate_iri,
         candidate_digest: candidate.candidate_digest,
         verifier_actor_iri: attributes.verifier_actor_iri,
         verifier_profile_revision: attributes.verifier_profile_revision,
         environment_revision: attributes.environment_revision,
         verifier_workspace_digest: attributes.verifier_workspace_digest,
         status: status,
         checks: checks,
         patch_digest: attributes.patch_digest,
         tree_digest: attributes.tree_digest,
         file_manifest_digest: attributes.file_manifest_digest,
         generated_artifact_digest: attributes.generated_artifact_digest,
         secret_scan_digest: attributes.secret_scan_digest,
         evidence_iri: attributes.evidence_iri,
         evidence_digest: attributes.evidence_digest,
         completed_at: DateTime.truncate(completed_at, :microsecond),
         fresh_checkout: true,
         delegated_workspace_reused: false,
         provider_session_reused: false,
         cli_process_reused: false,
         acceptance_authority: false,
         publication_authority: false,
         merge_authority: false,
         goal_satisfaction_authority: false
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_candidate, _attributes), do: invalid()

  defp resources(attributes) do
    if Enum.all?(~w[verifier_actor_iri evidence_iri]a, fn field ->
         Knowledge.validate_resource_identity(attributes[field]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp digest_fields do
    ~w[verifier_profile_revision environment_revision verifier_workspace_digest patch_digest tree_digest file_manifest_digest generated_artifact_digest secret_scan_digest evidence_digest]a
  end

  defp checks(values) when is_list(values) and values != [] and length(values) <= 64 do
    valid =
      Enum.all?(values, fn
        %{
          check: check,
          status: status,
          command_digest: command,
          result_digest: result,
          output_digest: output
        } ->
          is_binary(check) and status in @check_statuses and digest?(command) and
            digest?(result) and digest?(output)

        _invalid ->
          false
      end)

    names = Enum.map(values, & &1.check)

    if valid and names == Enum.uniq(names),
      do: {:ok, Enum.sort_by(values, & &1.check)},
      else: :error
  end

  defp checks(_values), do: :error

  defp coherent_status?(:passed, checks), do: Enum.all?(checks, &(&1.status == :passed))
  defp coherent_status?(:failed, checks), do: Enum.any?(checks, &(&1.status == :failed))
  defp coherent_status?(:timed_out, checks), do: Enum.any?(checks, &(&1.status == :timed_out))
  defp coherent_status?(:unavailable, checks), do: Enum.any?(checks, &(&1.status == :unavailable))
  defp coherent_status?(:indeterminate, _checks), do: true

  defp identity(candidate, attributes, checks) do
    Knowledge.deterministic_resource_identity(
      :verification_activity,
      :erlang.term_to_binary(
        {
          candidate.candidate_digest,
          attributes.verifier_actor_iri,
          attributes.verifier_profile_revision,
          attributes.environment_revision,
          checks
        },
        [:deterministic]
      )
    )
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)
  defp invalid, do: {:error, AdapterError.new(:invalid_input, :delegated_verification_result)}
end
