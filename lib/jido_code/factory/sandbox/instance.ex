defmodule JidoCode.Factory.Sandbox.Instance do
  @moduledoc "Bounded identity and reporting attributes for one production sandbox instance."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Sandbox.IsolationProfile
  alias JidoCode.Factory.Sandbox.Request
  alias JidoCode.Knowledge

  @derive {Inspect, only: [:iri, :attempt_iri, :tier, :image_digest, :provider_ref]}
  @enforce_keys [
    :iri,
    :attempt_iri,
    :tier,
    :image_digest,
    :profile_digest,
    :limits_digest,
    :provider_ref,
    :provisioned_at
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(Request.t(), IsolationProfile.t(), String.t(), DateTime.t()) ::
          {:ok, t()} | {:error, AdapterError.t()}
  def new(
        %Request{} = request,
        %IsolationProfile{} = profile,
        provider_ref,
        %DateTime{} = provisioned_at
      )
      when is_binary(provider_ref) do
    with :ok <- Knowledge.validate_resource_identity(request.execution.attempt_iri),
         true <- Regex.match?(~r/^[a-f0-9]{64}$/, provider_ref),
         {:ok, iri} <-
           Knowledge.sandbox_instance_identity(
             request.execution.attempt_iri,
             profile.tier,
             profile.image_digest,
             request.execution.fencing_token
           ) do
      {:ok,
       %__MODULE__{
         iri: iri,
         attempt_iri: request.execution.attempt_iri,
         tier: profile.tier,
         image_digest: profile.image_digest,
         profile_digest: IsolationProfile.digest(profile),
         limits_digest: digest(request.limits),
         provider_ref: provider_ref,
         provisioned_at: DateTime.truncate(provisioned_at, :microsecond)
       }}
    else
      _invalid -> invalid()
    end
  rescue
    _error -> invalid()
  end

  def new(_request, _profile, _provider_ref, _provisioned_at), do: invalid()

  @spec observation(t()) :: map()
  def observation(%__MODULE__{} = instance) do
    %{
      instance_iri: instance.iri,
      attempt_iri: instance.attempt_iri,
      isolation_tier: instance.tier,
      image_digest: instance.image_digest,
      profile_digest: instance.profile_digest,
      limits_digest: instance.limits_digest,
      provider_ref: instance.provider_ref,
      provisioned_at: instance.provisioned_at
    }
  end

  @spec event_details(t()) :: map()
  def event_details(%__MODULE__{} = instance) do
    %{
      instance_iri: instance.iri,
      isolation_tier: instance.tier,
      image_digest: instance.image_digest,
      profile_digest: instance.profile_digest,
      limits_digest: instance.limits_digest
    }
  end

  defp digest(value) do
    value
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> then(&("sha256:" <> &1))
  end

  defp invalid, do: {:error, AdapterError.new(:invalid_input, :sandbox_instance)}
end
