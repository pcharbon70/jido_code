defmodule JidoCode.Factory.CodexProviderEgress do
  @moduledoc "Closed parent-only OpenAI egress policy builder for DGA1."

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Egress.Destination
  alias JidoCode.Factory.Egress.Policy
  alias JidoCode.Factory.Egress.Request

  @spec policy(map()) :: {:ok, Policy.t()} | {:error, AdapterError.t()}
  def policy(attributes) when is_map(attributes) do
    with {:ok, destination} <-
           Destination.new(%{
             scheme: "https",
             host: "api.openai.com",
             port: 443,
             path_prefix: "/v1",
             kind: :approved_api
           }) do
      Policy.new(%{
        policy_iri: attributes[:policy_iri],
        attempt_iri: attributes[:attempt_iri],
        invocation_iri: attributes[:invocation_iri],
        lease_iri: attributes[:lease_iri],
        fencing_token: attributes[:fencing_token],
        profile_revision: attributes[:profile_revision],
        egress_revision: attributes[:egress_revision],
        revocation_generation: attributes[:revocation_generation],
        destinations: [destination],
        methods: [:get, :post],
        allowed_integrity: [:untrusted],
        allowed_confidentiality: [:restricted],
        maximum_request_bytes: 10_485_760,
        maximum_response_bytes: 10_485_760,
        maximum_redirects: 0,
        rate_limit: %{requests: 120, window_ms: 60_000},
        resolver_identity: attributes[:resolver_identity],
        expires_at: attributes[:expires_at]
      })
    end
  end

  def policy(_attributes), do: invalid(:codex_provider_egress)

  @spec request(Policy.t(), atom(), map()) :: {:ok, Request.t()} | {:error, AdapterError.t()}
  def request(%Policy{} = policy, :codex_parent, attributes) when is_map(attributes) do
    Request.new(policy, %{
      uri: attributes[:uri],
      method: attributes[:method],
      traffic_class: :provider_api,
      integrity: :untrusted,
      confidentiality: :restricted,
      request_bytes: attributes[:request_bytes],
      redirect_count: 0
    })
  end

  def request(%Policy{}, :tool_descendant, _attributes),
    do: unauthorized(:codex_tool_descendant_egress)

  def request(_policy, _principal, _attributes), do: invalid(:codex_provider_egress)

  defp invalid(operation), do: {:error, AdapterError.new(:invalid_input, operation)}
  defp unauthorized(operation), do: {:error, AdapterError.new(:unauthorized, operation)}
end
