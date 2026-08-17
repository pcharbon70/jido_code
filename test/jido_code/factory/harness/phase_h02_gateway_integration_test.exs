defmodule JidoCode.Factory.Harness.PhaseH02GatewayIntegrationTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.ModelGateway
  alias JidoCode.Integrations.ReqLLM, as: ReqLLMAdapter
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeModelAuthority
  alias JidoCode.TestSupport.FakeReqLLMClient
  alias JidoCode.TestSupport.FakeSecretProvider

  test "revocation before credential release prevents release and dispatch" do
    request = request!()

    gateway =
      gateway!(
        before_credential_release:
          {:error, AdapterError.new(:unauthorized, :before_credential_release)}
      )

    assert {:error, %AdapterError{operation: :before_credential_release}} =
             ModelGateway.generate(gateway, request)

    assert_received {:model_authorize, :before_credential_release, _profile, ^request}
    refute_received {:secret_fetch, _reference}
    refute_received {:model_authorize, :before_dispatch, _profile, _request}
    refute_received {:req_llm_generate_text, _model, _messages, _options}
  end

  test "revocation after credential release prevents the later dispatch" do
    request = request!()

    gateway =
      gateway!(before_dispatch: {:error, AdapterError.new(:unauthorized, :before_dispatch)})

    assert {:error, %AdapterError{operation: :before_dispatch}} =
             ModelGateway.generate(gateway, request)

    assert_received {:model_authorize, :before_credential_release, _profile, ^request}
    assert_received {:secret_fetch, _reference}
    assert_received {:model_authorize, :before_dispatch, _profile, ^request}
    refute_received {:req_llm_generate_text, _model, _messages, _options}
  end

  test "one failed transport call is never retried by the gateway or ReqLLM profile" do
    FakeReqLLMClient.put_generate_result({:error, :transport_failed})

    assert {:error,
            %AdapterError{kind: :unavailable, operation: :req_llm_generate, retry: :retry}} =
             ModelGateway.generate(gateway!(), request!())

    assert_received {:req_llm_generate_text, "openai:gpt-4.1-mini", "compiled context", options}
    assert Keyword.fetch!(options, :max_retries) == 0
    assert Keyword.fetch!(options, :cache) == nil
    assert Keyword.fetch!(options, :telemetry) == [payloads: :none]
    assert Keyword.fetch!(options, :json_repair) == false
    refute_received {:req_llm_generate_text, _model, _messages, _options}
  end

  test "mutated identities and billing modes are rejected instead of falling back" do
    profile = profile!()

    for {field, value} <- [
          provider: "anthropic",
          model: "gpt-4.1",
          endpoint: "https://proxy.invalid/v1",
          access_mode: :host_subscription,
          credential_class: :short_lived_bearer,
          billing_mode: :subscription
        ] do
      mutated = Map.put(profile, field, value)

      assert {:error, %AdapterError{operation: :model_gateway_adapter}} =
               new_gateway(mutated, %{})
    end

    for {field, value} <- [provider: "anthropic", model: "gpt-4.1"] do
      request = request!() |> Map.put(field, value)

      assert {:error, %AdapterError{operation: :model_dispatch}} =
               ModelGateway.generate(gateway!(), request)

      refute_received {:secret_fetch, _reference}
      refute_received {:req_llm_generate_text, _model, _messages, _options}
    end
  end

  defp gateway!(authority_results \\ %{}) do
    assert {:ok, gateway} = new_gateway(profile!(), Map.new(authority_results))
    gateway
  end

  defp new_gateway(profile, authority_results) do
    assert {:ok, adapter} = ReqLLMAdapter.new(client: FakeReqLLMClient)

    ModelGateway.new(ReqLLMAdapter, adapter,
      profile: profile,
      secret_provider: {
        FakeSecretProvider,
        %{owner: self(), result: {:ok, "broker-key"}}
      },
      authority: {
        FakeModelAuthority,
        %{owner: self(), results: authority_results}
      }
    )
  end

  defp profile! do
    assert {:ok, profile} =
             BufferedProfile.new(
               %{
                 profile_iri: deterministic!(:model_access_profile, "integration-profile"),
                 credential_reference_iri:
                   deterministic!(:knowledge_assertion, "integration-credential"),
                 provider: "openai",
                 model: "gpt-4.1-mini",
                 endpoint: "https://api.openai.com/v1",
                 access_mode: :host_api,
                 credential_class: :static_reusable,
                 billing_mode: :metered_api,
                 readiness: [
                   :credential_available,
                   :authenticated,
                   :model_available,
                   :policy_allowed
                 ]
               },
               credential_reference!()
             )

    profile
  end

  defp credential_reference! do
    assert {:ok, reference} =
             CredentialReference.new(%{
               iri: deterministic!(:knowledge_assertion, "integration-credential"),
               provider: "openai",
               key: "integration-openai-profile"
             })

    reference
  end

  defp request! do
    assert {:ok, request} =
             Request.new(%{
               invocation_iri: deterministic!(:model_invocation, "integration-invocation"),
               profile_iri: deterministic!(:model_access_profile, "integration-profile"),
               context_manifest_iri: deterministic!(:context_manifest, "integration-context"),
               provider: "openai",
               model: "gpt-4.1-mini",
               messages: "compiled context",
               options: [temperature: 0.0, max_tokens: 256],
               deadline: DateTime.add(DateTime.utc_now(), 30, :second)
             })

    request
  end

  defp deterministic!(kind, seed) do
    assert {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end
