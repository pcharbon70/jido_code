defmodule JidoCode.Factory.Model.BufferedProfile do
  @moduledoc """
  Closed initial profile for one buffered, broker-credentialed model call.

  The profile is built from a reviewed graph projection and an opaque
  credential reference. Its provider, model, endpoint, access mode, credential
  class, and billing mode are exact; there is no fallback surface.
  """

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Knowledge

  @derive {Inspect,
           only: [
             :profile_iri,
             :provider,
             :model,
             :endpoint,
             :access_mode,
             :credential_class,
             :billing_mode
           ]}
  @enforce_keys [
    :profile_iri,
    :provider,
    :model,
    :endpoint,
    :access_mode,
    :credential_class,
    :billing_mode,
    :credential_reference,
    :timeouts,
    :retention_posture,
    :provider_cache_posture,
    :training_posture,
    :structured_effects,
    :cost_enforcement
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @initial_profile %{
    provider: "openai",
    model: "gpt-4.1-mini",
    endpoint: "https://api.openai.com/v1"
  }
  @required_readiness MapSet.new(~w[
                        credential_available authenticated model_available policy_allowed
                      ]a)
  @default_timeouts %{
    receive_ms: 30_000,
    total_ms: 60_000,
    stream_idle_ms: 15_000,
    metadata_ms: 5_000
  }

  @spec new(map(), CredentialReference.t(), keyword()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(attributes, reference, options \\ [])

  def new(attributes, %CredentialReference{} = reference, options)
      when is_map(attributes) and is_list(options) do
    timeouts = Keyword.get(options, :timeouts, @default_timeouts)
    readiness = Map.get(attributes, :readiness, [])

    with :ok <- Knowledge.validate_resource_identity(attributes[:profile_iri]),
         :ok <- Knowledge.validate_resource_identity(attributes[:credential_reference_iri]),
         true <- attributes[:credential_reference_iri] == reference.iri,
         true <- attributes[:provider] == reference.provider,
         true <- exact_initial_profile?(attributes),
         :host_api <- attributes[:access_mode],
         :static_reusable <- attributes[:credential_class],
         :metered_api <- attributes[:billing_mode],
         true <- readiness?(readiness),
         :ok <- validate_timeouts(timeouts) do
      {:ok,
       %__MODULE__{
         profile_iri: attributes.profile_iri,
         provider: attributes.provider,
         model: attributes.model,
         endpoint: attributes.endpoint,
         access_mode: attributes.access_mode,
         credential_class: attributes.credential_class,
         billing_mode: attributes.billing_mode,
         credential_reference: reference,
         timeouts: timeouts,
         retention_posture: :provider_contract_external,
         provider_cache_posture: :provider_managed_residual,
         training_posture: :provider_contract_external,
         structured_effects: :disabled_unproven_strict_json,
         cost_enforcement: :observed_post_dispatch
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
    Knowledge.validate_resource_identity(profile.profile_iri) == :ok and
      Knowledge.validate_resource_identity(profile.credential_reference.iri) == :ok and
      profile.credential_reference.provider == profile.provider and
      exact_initial_profile?(profile) and
      profile.access_mode == :host_api and
      profile.credential_class == :static_reusable and
      profile.billing_mode == :metered_api and
      validate_timeouts(profile.timeouts) == :ok and
      profile.retention_posture == :provider_contract_external and
      profile.provider_cache_posture == :provider_managed_residual and
      profile.training_posture == :provider_contract_external and
      profile.structured_effects == :disabled_unproven_strict_json and
      profile.cost_enforcement == :observed_post_dispatch
  rescue
    _error -> false
  end

  def valid?(_profile), do: false

  @spec accepts?(t(), Request.t()) :: boolean()
  def accepts?(%__MODULE__{} = profile, %Request{} = request) do
    profile.profile_iri == request.profile_iri and
      profile.provider == request.provider and
      profile.model == request.model and
      DateTime.compare(request.deadline, DateTime.utc_now()) == :gt
  end

  @spec default_timeouts() :: map()
  def default_timeouts, do: @default_timeouts

  defp exact_initial_profile?(attributes) do
    Enum.all?(@initial_profile, fn {key, expected} -> Map.get(attributes, key) == expected end)
  end

  defp readiness?(readiness) when is_list(readiness) do
    readiness
    |> MapSet.new()
    |> then(&MapSet.subset?(@required_readiness, &1))
  end

  defp readiness?(_readiness), do: false

  defp validate_timeouts(timeouts) when is_map(timeouts) and map_size(timeouts) == 4 do
    accepted = %{
      receive_ms: 1_000..60_000,
      total_ms: 1_000..120_000,
      stream_idle_ms: 1_000..30_000,
      metadata_ms: 500..15_000
    }

    if Enum.all?(accepted, fn {key, range} -> Map.get(timeouts, key) in range end) and
         timeouts.total_ms >= timeouts.receive_ms do
      :ok
    else
      :error
    end
  end

  defp validate_timeouts(_timeouts), do: :error

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :buffered_model_profile)}
end
