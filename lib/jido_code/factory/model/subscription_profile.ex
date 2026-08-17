defmodule JidoCode.Factory.Model.SubscriptionProfile do
  @moduledoc """
  Version-pinned host subscription profile with explicit release evidence.

  Provider terms acceptance and a consented live verification are required
  before dispatch. Provider conversation identifiers are never recovery state;
  every recovery starts a new graph-owned interaction.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.OAuthFileReference
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Knowledge

  @derive {Inspect,
           only: [
             :profile_iri,
             :contract,
             :provider,
             :model,
             :credential_source,
             :deployment
           ]}
  @enforce_keys [
    :profile_iri,
    :contract,
    :contract_version,
    :provider,
    :model,
    :endpoint,
    :access_mode,
    :credential_class,
    :billing_mode,
    :credential_source,
    :credential_reference,
    :credential_expires_at,
    :oauth_file_reference,
    :deployment,
    :refresh_owner,
    :terms_evidence_iri,
    :live_verification_iri,
    :timeouts,
    :retention_posture,
    :provider_cache_posture,
    :training_posture,
    :structured_effects,
    :cost_enforcement,
    :recovery_mode
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @contracts %{
    openai_codex_oauth: %{
      version: "req_llm-1.20.0/openai-codex-oauth/1",
      provider: "openai_codex",
      model: "gpt-5.3-codex",
      endpoint: "https://chatgpt.com/backend-api",
      sources: [:explicit_access_token, :oauth_file]
    },
    anthropic_subscription: %{
      version: "req_llm-1.20.0/anthropic-subscription/1",
      provider: "anthropic",
      model: "claude-sonnet-4-5-20250929",
      endpoint: "https://api.anthropic.com",
      sources: [:explicit_access_token, :oauth_file]
    },
    github_copilot: %{
      version: "req_llm-1.20.0/github-copilot/1",
      provider: "github_copilot",
      model: "gpt-4o-mini",
      endpoint: "https://api.githubcopilot.com",
      sources: [:explicit_access_token, :gh_auth_token]
    }
  }

  @spec new(map(), CredentialReference.t(), keyword()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes, reference, options \\ [])

  def new(attributes, %CredentialReference{} = reference, options)
      when is_map(attributes) and is_list(options) do
    contract = Map.get(@contracts, attributes[:contract])
    timeouts = Keyword.get(options, :timeouts, BufferedProfile.default_timeouts())
    oauth_file_reference = Keyword.get(options, :oauth_file_reference)

    with contract when is_map(contract) <- contract,
         :ok <- Knowledge.validate_resource_identity(attributes[:profile_iri]),
         :ok <- Knowledge.validate_resource_identity(attributes[:credential_reference_iri]),
         :ok <- Knowledge.validate_resource_identity(attributes[:terms_evidence_iri]),
         :ok <- Knowledge.validate_resource_identity(attributes[:live_verification_iri]),
         true <- attributes[:credential_reference_iri] == reference.iri,
         true <- attributes[:provider] == reference.provider,
         true <- exact_contract?(attributes, contract),
         true <- attributes[:credential_source] in contract.sources,
         true <- deployment?(attributes),
         true <- refresh_owner?(attributes),
         true <- credential_lifetime?(attributes),
         true <- valid_timeouts?(timeouts),
         :ok <- oauth_file_reference(attributes, oauth_file_reference),
         :accepted <- attributes[:terms_status],
         :verified <- attributes[:live_status] do
      {:ok,
       %__MODULE__{
         profile_iri: attributes.profile_iri,
         contract: attributes.contract,
         contract_version: contract.version,
         provider: contract.provider,
         model: contract.model,
         endpoint: contract.endpoint,
         access_mode: :host_subscription,
         credential_class: :short_lived_bearer,
         billing_mode: :subscription,
         credential_source: attributes.credential_source,
         credential_reference: reference,
         credential_expires_at: attributes[:credential_expires_at],
         oauth_file_reference: oauth_file_reference,
         deployment: attributes.deployment,
         refresh_owner: attributes.refresh_owner,
         terms_evidence_iri: attributes.terms_evidence_iri,
         live_verification_iri: attributes.live_verification_iri,
         timeouts: timeouts,
         retention_posture: :provider_contract_external,
         provider_cache_posture: :provider_managed_residual,
         training_posture: :provider_contract_external,
         structured_effects: :disabled_pending_separate_conformance,
         cost_enforcement: :observed_post_dispatch,
         recovery_mode: :new_interaction_from_graph
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_attributes, _reference, _options), do: invalid()

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = profile) do
    contract = Map.get(@contracts, profile.contract)

    is_map(contract) and
      Knowledge.validate_resource_identity(profile.profile_iri) == :ok and
      Knowledge.validate_resource_identity(profile.credential_reference.iri) == :ok and
      Knowledge.validate_resource_identity(profile.terms_evidence_iri) == :ok and
      Knowledge.validate_resource_identity(profile.live_verification_iri) == :ok and
      profile.credential_reference.provider == profile.provider and
      exact_contract?(profile, contract) and
      profile.contract_version == contract.version and
      profile.credential_source in contract.sources and
      deployment?(profile) and
      refresh_owner?(profile) and
      credential_lifetime?(profile) and
      valid_timeouts?(profile.timeouts) and
      oauth_file_reference(profile, profile.oauth_file_reference) == :ok and
      exact_posture?(profile)
  rescue
    _error -> false
  end

  def valid?(_profile), do: false

  @spec accepts?(t(), Request.t()) :: boolean()
  def accepts?(%__MODULE__{} = profile, %Request{} = request) do
    profile.profile_iri == request.profile_iri and profile.provider == request.provider and
      profile.model == request.model and
      DateTime.compare(request.deadline, DateTime.utc_now()) == :gt and
      credential_fresh?(profile, request.deadline)
  end

  @spec contracts() :: map()
  def contracts, do: @contracts

  defp exact_contract?(attributes, contract) do
    Map.get(attributes, :provider) == contract.provider and
      Map.get(attributes, :model) == contract.model and
      Map.get(attributes, :endpoint) == contract.endpoint and
      Map.get(attributes, :access_mode) == :host_subscription and
      Map.get(attributes, :credential_class) == :short_lived_bearer and
      Map.get(attributes, :billing_mode) == :subscription
  end

  defp exact_posture?(profile) do
    profile.retention_posture == :provider_contract_external and
      profile.provider_cache_posture == :provider_managed_residual and
      profile.training_posture == :provider_contract_external and
      profile.structured_effects == :disabled_pending_separate_conformance and
      profile.cost_enforcement == :observed_post_dispatch and
      profile.recovery_mode == :new_interaction_from_graph
  end

  defp deployment?(%{credential_source: source, deployment: :developer_local})
       when source in [:oauth_file, :gh_auth_token],
       do: true

  defp deployment?(%{credential_source: :explicit_access_token, deployment: deployment})
       when deployment in [:developer_local, :managed, :multi_user],
       do: true

  defp deployment?(_attributes), do: false

  defp refresh_owner?(%{credential_source: :oauth_file, refresh_owner: :req_llm}), do: true

  defp refresh_owner?(%{credential_source: source, refresh_owner: :host_adapter})
       when source in [:explicit_access_token, :gh_auth_token],
       do: true

  defp refresh_owner?(_attributes), do: false

  defp credential_lifetime?(%{
         credential_source: :explicit_access_token,
         credential_expires_at: %DateTime{} = expires_at
       }) do
    DateTime.diff(expires_at, DateTime.utc_now(), :second) in 1..3_600
  end

  defp credential_lifetime?(%{credential_source: source, credential_expires_at: nil})
       when source in [:oauth_file, :gh_auth_token],
       do: true

  defp credential_lifetime?(_attributes), do: false

  defp credential_fresh?(
         %__MODULE__{
           credential_source: :explicit_access_token,
           credential_expires_at: expires_at
         },
         deadline
       ),
       do: DateTime.compare(expires_at, deadline) == :gt

  defp credential_fresh?(%__MODULE__{}, _deadline), do: true

  defp oauth_file_reference(%{credential_source: :oauth_file, provider: provider}, reference) do
    if match?(%OAuthFileReference{provider: ^provider}, reference), do: :ok, else: :error
  end

  defp oauth_file_reference(%{credential_source: source}, nil)
       when source in [:explicit_access_token, :gh_auth_token],
       do: :ok

  defp oauth_file_reference(_attributes, _reference), do: :error

  defp valid_timeouts?(timeouts) when is_map(timeouts) and map_size(timeouts) == 4 do
    is_integer(timeouts[:receive_ms]) and timeouts.receive_ms in 1_000..60_000 and
      is_integer(timeouts[:total_ms]) and timeouts.total_ms in 1_000..120_000 and
      timeouts.total_ms >= timeouts.receive_ms and
      is_integer(timeouts[:stream_idle_ms]) and timeouts.stream_idle_ms in 1_000..30_000 and
      is_integer(timeouts[:metadata_ms]) and timeouts.metadata_ms in 500..15_000
  end

  defp valid_timeouts?(_timeouts), do: false

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :subscription_profile)}
end
