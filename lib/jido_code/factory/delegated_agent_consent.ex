defmodule JidoCode.Factory.DelegatedAgentConsent do
  @moduledoc "Exact short-lived foreground consent for one billable delegated Codex effect."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Knowledge

  @purposes ~w[execution live_smoke qualification]a
  @maximum_lifetime_seconds 900
  @enforce_keys [
    :iri,
    :actor_iri,
    :repository_iri,
    :task_iri,
    :attempt_iri,
    :lease_iri,
    :effect_iri,
    :fencing_token,
    :profile_digest,
    :credential_reference_iri,
    :credential_generation,
    :billing_classification,
    :billing_terms_digest,
    :purpose,
    :granted_at,
    :expires_at,
    :consent_digest
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes) when is_map(attributes) do
    with :ok <- exact_keys(attributes),
         :ok <- resources(attributes),
         fence when is_integer(fence) and fence > 0 <- attributes[:fencing_token],
         true <- digest?(attributes[:profile_digest]),
         true <- digest?(attributes[:billing_terms_digest]),
         generation when is_integer(generation) and generation > 0 <-
           attributes[:credential_generation],
         :subscription <- attributes[:billing_classification],
         purpose when purpose in @purposes <- attributes[:purpose],
         true <- attributes[:granted] == true,
         true <- attributes[:billing_acknowledged] == true,
         true <- attributes[:foreground] == true,
         false <- attributes[:background_dispatch],
         false <- attributes[:managed_eligible],
         false <- attributes[:reusable_credential_export],
         %DateTime{} = granted_at <- attributes[:granted_at],
         %DateTime{} = expires_at <- attributes[:expires_at],
         :ok <- lifetime(granted_at, expires_at),
         material <- material(attributes),
         consent_digest <- digest(material),
         {:ok, iri} <-
           Knowledge.deterministic_resource_identity(
             :approval_request,
             Enum.join([attributes.actor_iri, attributes.effect_iri, consent_digest], "\n")
           ) do
      {:ok,
       struct!(
         __MODULE__,
         material
         |> Map.put(:iri, iri)
         |> Map.put(:consent_digest, consent_digest)
       )}
    else
      _invalid -> invalid(:delegated_agent_consent)
    end
  rescue
    _error -> invalid(:delegated_agent_consent)
  end

  def new(_attributes), do: invalid(:delegated_agent_consent)

  @spec authorize(t(), map(), DateTime.t()) :: {:ok, map()} | {:error, AdapterError.t()}
  def authorize(%__MODULE__{} = consent, current, %DateTime{} = at) when is_map(current) do
    fields = [
      :actor_iri,
      :repository_iri,
      :task_iri,
      :attempt_iri,
      :lease_iri,
      :effect_iri,
      :fencing_token,
      :profile_digest,
      :credential_reference_iri,
      :credential_generation,
      :billing_classification,
      :billing_terms_digest,
      :purpose
    ]

    if Enum.all?(fields, &(current[&1] == Map.fetch!(consent, &1))) and
         current[:lease_state] == :active and current[:foreground] == true and
         current[:background_dispatch] == false and current[:managed_eligible] == false and
         current[:reusable_credential_export] == false and
         DateTime.compare(consent.granted_at, at) in [:lt, :eq] and
         DateTime.compare(at, consent.expires_at) == :lt do
      {:ok,
       %{
         consent_iri: consent.iri,
         consent_digest: consent.consent_digest,
         effect_iri: consent.effect_iri,
         purpose: consent.purpose,
         billing_classification: consent.billing_classification,
         credential_reference_iri: consent.credential_reference_iri,
         credential_generation: consent.credential_generation,
         expires_at: consent.expires_at
       }}
    else
      unauthorized(:delegated_agent_consent)
    end
  rescue
    _error -> unauthorized(:delegated_agent_consent)
  end

  def authorize(_consent, _current, _at), do: invalid(:delegated_agent_consent)

  @spec durable_record(t()) :: map()
  def durable_record(%__MODULE__{} = consent) do
    %{
      iri: consent.iri,
      actor_iri: consent.actor_iri,
      repository_iri: consent.repository_iri,
      task_iri: consent.task_iri,
      attempt_iri: consent.attempt_iri,
      lease_iri: consent.lease_iri,
      fencing_token: consent.fencing_token,
      effect_iri: consent.effect_iri,
      profile_digest: consent.profile_digest,
      credential_reference_iri: consent.credential_reference_iri,
      credential_generation: consent.credential_generation,
      billing_classification: consent.billing_classification,
      billing_terms_digest: consent.billing_terms_digest,
      purpose: consent.purpose,
      expires_at: consent.expires_at,
      consent_digest: consent.consent_digest
    }
  end

  defp exact_keys(attributes) do
    keys =
      (@enforce_keys -- [:iri, :consent_digest]) ++
        ~w[granted billing_acknowledged foreground background_dispatch managed_eligible reusable_credential_export]a

    if MapSet.new(Map.keys(attributes)) == MapSet.new(keys), do: :ok, else: :error
  end

  defp resources(attributes) do
    fields =
      ~w[actor_iri repository_iri task_iri attempt_iri lease_iri effect_iri credential_reference_iri]a

    if Enum.all?(fields, &(Knowledge.validate_resource_identity(attributes[&1]) == :ok)),
      do: :ok,
      else: :error
  end

  defp lifetime(granted_at, expires_at) do
    seconds = DateTime.diff(expires_at, granted_at, :second)
    if seconds in 1..@maximum_lifetime_seconds, do: :ok, else: :error
  end

  defp material(attributes),
    do:
      Map.take(attributes, @enforce_keys -- [:iri, :consent_digest])
      |> Map.update!(:granted_at, &DateTime.truncate(&1, :microsecond))
      |> Map.update!(:expires_at, &DateTime.truncate(&1, :microsecond))

  defp digest?(value), do: is_binary(value) and Regex.match?(~r/^[a-f0-9]{64}$/, value)

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
