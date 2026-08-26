defmodule JidoCode.Knowledge.Control.DelegatedAgentAdmission do
  @moduledoc "Exact immutable binding produced by delegated-agent selection."

  alias JidoCode.Knowledge.Control.DelegatedAgentContract, as: Contract
  alias JidoCode.Knowledge.Error
  alias JidoCode.Knowledge.ResourceIdentity

  @enforce_keys [
    :offering_reference,
    :profile_iri,
    :profile_digest,
    :runtime_class,
    :adapter_release_iri,
    :adapter_release_digest,
    :harness_profile_iri,
    :model_access_profile_iri,
    :deployment_class,
    :authentication_kind,
    :billing_mode,
    :capability_class,
    :readiness_iri,
    :readiness_digest,
    :credential_generation,
    :workspace_policy_revision,
    :sandbox_profile_revision,
    :network_policy_revision,
    :candidate_protocol_revision,
    :verification_profile_revision,
    :source_snapshot_iri,
    :source_graph_revisions,
    :attempt_iri,
    :lease_iri,
    :fencing_token,
    :invocation_before_effect_iri,
    :bound_at,
    :binding_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @jf "https://jido.run/ontology/factory#"
  @concept "https://jido.run/ontology/concept/"

  @spec new(map()) :: {:ok, t()} | {:error, Error.t()}
  def new(attributes) when is_map(attributes) do
    resources =
      ~w[profile_iri adapter_release_iri harness_profile_iri model_access_profile_iri readiness_iri source_snapshot_iri attempt_iri lease_iri invocation_before_effect_iri]a

    digests =
      ~w[profile_digest adapter_release_digest readiness_digest workspace_policy_revision sandbox_profile_revision network_policy_revision candidate_protocol_revision verification_profile_revision]a

    with true <- Enum.all?(resources, &(ResourceIdentity.validate(attributes[&1]) == :ok)),
         true <- Enum.all?(digests, &Contract.digest?(attributes[&1])),
         :delegated_cli <- attributes[:runtime_class],
         generation when is_integer(generation) and generation > 0 <-
           attributes[:credential_generation],
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         %DateTime{} <- attributes[:bound_at],
         true <- valid_revisions?(attributes[:source_graph_revisions]),
         reference when is_binary(reference) and byte_size(reference) in 24..128 <-
           attributes[:offering_reference],
         expected_digest <- binding_digest(attributes),
         ^expected_digest <- attributes[:binding_digest] do
      {:ok, struct!(__MODULE__, Map.take(attributes, @enforce_keys))}
    else
      _invalid -> {:error, Error.new(:invalid_input, :delegated_agent_admission)}
    end
  rescue
    _error -> {:error, Error.new(:invalid_input, :delegated_agent_admission)}
  end

  def new(_attributes), do: {:error, Error.new(:invalid_input, :delegated_agent_admission)}

  @spec binding_digest(map()) :: String.t()
  def binding_digest(attributes),
    do: Contract.digest(Map.drop(attributes, [:binding_digest]))

  @spec statements(t()) :: [tuple()]
  def statements(%__MODULE__{} = binding) do
    [
      {binding.attempt_iri, @jf <> "delegatedAgentProfile", RDF.iri(binding.profile_iri)},
      {binding.attempt_iri, @jf <> "profileDigest", RDF.XSD.String.new(binding.profile_digest)},
      {binding.attempt_iri, @jf <> "runtimeClass", RDF.iri(concept(binding.runtime_class))},
      {binding.attempt_iri, @jf <> "adapterRelease", RDF.iri(binding.adapter_release_iri)},
      {binding.attempt_iri, @jf <> "releaseDigest",
       RDF.XSD.String.new(binding.adapter_release_digest)},
      {binding.attempt_iri, @jf <> "harnessProfile", RDF.iri(binding.harness_profile_iri)},
      {binding.attempt_iri, @jf <> "modelAccessProfile",
       RDF.iri(binding.model_access_profile_iri)},
      {binding.attempt_iri, @jf <> "deploymentClass", RDF.iri(concept(binding.deployment_class))},
      {binding.attempt_iri, @jf <> "authenticationKind",
       RDF.iri(concept(binding.authentication_kind))},
      {binding.attempt_iri, @jf <> "billingMode", RDF.iri(concept(binding.billing_mode))},
      {binding.attempt_iri, @jf <> "capabilityClass", RDF.iri(concept(binding.capability_class))},
      {binding.attempt_iri, @jf <> "readinessEvidence", RDF.iri(binding.readiness_iri)},
      {binding.attempt_iri, @jf <> "observationDigest",
       RDF.XSD.String.new(binding.readiness_digest)},
      {binding.attempt_iri, @jf <> "credentialGeneration",
       RDF.XSD.NonNegativeInteger.new(binding.credential_generation)},
      {binding.attempt_iri, @jf <> "workspacePolicyRevision",
       RDF.XSD.String.new(binding.workspace_policy_revision)},
      {binding.attempt_iri, @jf <> "sandboxProfileRevision",
       RDF.XSD.String.new(binding.sandbox_profile_revision)},
      {binding.attempt_iri, @jf <> "networkPolicyRevision",
       RDF.XSD.String.new(binding.network_policy_revision)},
      {binding.attempt_iri, @jf <> "candidateProtocolRevision",
       RDF.XSD.String.new(binding.candidate_protocol_revision)},
      {binding.attempt_iri, @jf <> "verificationProfileRevision",
       RDF.XSD.String.new(binding.verification_profile_revision)},
      {binding.attempt_iri, @jf <> "invocationBeforeEffect",
       RDF.iri(binding.invocation_before_effect_iri)},
      {binding.attempt_iri, @jf <> "admissionBindingDigest",
       RDF.XSD.String.new(binding.binding_digest)}
    ]
  end

  defp valid_revisions?(revisions) when is_map(revisions) and map_size(revisions) > 0 do
    Enum.all?(revisions, fn {graph, revision} ->
      is_binary(graph) and RDF.IRI.valid?(graph) and is_integer(revision) and revision >= 0
    end)
  end

  defp valid_revisions?(_revisions), do: false

  defp concept(value),
    do: @concept <> (value |> Atom.to_string() |> Macro.camelize())
end
