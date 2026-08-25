defmodule JidoCode.Factory.ManagedCoding.VerificationRequest do
  @moduledoc "Exact immutable candidate handoff to an independent fresh-checkout verifier."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.ManagedCoding.CandidateManifest
  alias JidoCode.Factory.ManagedCoding.Identity

  @digest ~r/^[a-f0-9]{64}$/
  @enforce_keys ~w[verification_iri candidate_iri candidate_digest repository_iri base_snapshot_iri base_revision patch_artifact_iri normalized_patch_digest changed_paths verifier_actor_iri producer_actor_iri verifier_profile_iri verifier_profile_revision environment_revision toolchain_revision policy_revision checks deadline evidence_iris producer_workspace_allowed mutable_cache_allowed credential_reuse_allowed publication_authority]a
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(CandidateManifest.t(), map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(%CandidateManifest{} = candidate, attributes) when is_map(attributes) do
    with :ok <- resources(attributes),
         true <- attributes[:verifier_actor_iri] != attributes[:producer_actor_iri],
         true <- Enum.all?(revision_fields(), &digest?(attributes[&1])),
         {:ok, checks} <- checks(attributes[:checks]),
         %DateTime{} = deadline <- attributes[:deadline],
         true <- DateTime.compare(deadline, DateTime.utc_now()) == :gt,
         {:ok, evidence} <- references(attributes[:evidence_iris]),
         {:ok, verification_iri} <- identity(candidate, attributes, checks) do
      {:ok,
       %__MODULE__{
         verification_iri: verification_iri,
         candidate_iri: candidate.candidate_iri,
         candidate_digest: candidate.candidate_digest,
         repository_iri: candidate.repository_iri,
         base_snapshot_iri: candidate.base_snapshot_iri,
         base_revision: candidate.base_revision,
         patch_artifact_iri: candidate.patch_artifact_iri,
         normalized_patch_digest: candidate.normalized_patch_digest,
         changed_paths: Enum.map(candidate.changed_files, & &1.path),
         verifier_actor_iri: attributes.verifier_actor_iri,
         producer_actor_iri: attributes.producer_actor_iri,
         verifier_profile_iri: attributes.verifier_profile_iri,
         verifier_profile_revision: attributes.verifier_profile_revision,
         environment_revision: attributes.environment_revision,
         toolchain_revision: attributes.toolchain_revision,
         policy_revision: attributes.policy_revision,
         checks: checks,
         deadline: DateTime.truncate(deadline, :microsecond),
         evidence_iris: evidence,
         producer_workspace_allowed: false,
         mutable_cache_allowed: false,
         credential_reuse_allowed: false,
         publication_authority: false
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_candidate, _attributes), do: invalid()

  defp resources(attributes) do
    if Enum.all?(~w[verifier_actor_iri producer_actor_iri verifier_profile_iri]a, fn field ->
         Identity.validate_resource(attributes[field]) == :ok
       end),
       do: :ok,
       else: :error
  end

  defp revision_fields,
    do: ~w[verifier_profile_revision environment_revision toolchain_revision policy_revision]a

  defp checks(checks) when is_list(checks) and checks != [] and length(checks) <= 100 do
    if Enum.all?(checks, fn
         %{id: id, command_digest: digest, deadline_ms: deadline}
         when is_binary(id) and byte_size(id) in 1..160 and is_integer(deadline) and deadline > 0 ->
           digest?(digest)

         _invalid ->
           false
       end) do
      {:ok, Enum.sort_by(checks, & &1.id)}
    else
      :error
    end
  end

  defp checks(_checks), do: :error

  defp references(values) when is_list(values) and length(values) <= 64 do
    if Enum.all?(values, &(Identity.validate_resource(&1) == :ok)),
      do: {:ok, Enum.sort(Enum.uniq(values))},
      else: :error
  end

  defp references(_values), do: :error

  defp identity(candidate, attributes, checks) do
    Identity.deterministic(
      :verification_activity,
      :erlang.term_to_binary(
        {
          candidate.candidate_digest,
          attributes[:verifier_profile_revision],
          attributes[:environment_revision],
          attributes[:toolchain_revision],
          attributes[:policy_revision],
          checks
        },
        [:deterministic]
      )
    )
  end

  defp digest?(value), do: is_binary(value) and Regex.match?(@digest, value)

  defp invalid,
    do: {:error, AdapterError.new(:invalid_input, :managed_coding_verification_request)}
end
