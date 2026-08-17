defmodule JidoCode.Factory.Harness.PhaseH02BufferedProfileTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Outcome
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.Response
  alias JidoCode.Factory.ModelGateway
  alias JidoCode.Integrations.ReqLLM, as: ReqLLMAdapter
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeModelAuthority
  alias JidoCode.TestSupport.FakeReqLLMClient
  alias JidoCode.TestSupport.FakeSecretProvider

  test "admits only the initial exact API-key profile and records residual posture" do
    assert {:ok, profile} = profile()
    assert profile.provider == "openai"
    assert profile.model == "gpt-4.1-mini"
    assert profile.endpoint == "https://api.openai.com/v1"
    assert profile.access_mode == :host_api
    assert profile.credential_class == :static_reusable
    assert profile.billing_mode == :metered_api
    assert profile.retention_posture == :provider_contract_external
    assert profile.provider_cache_posture == :provider_managed_residual
    assert profile.structured_effects == :disabled_unproven_strict_json

    for {key, value} <- [
          provider: "anthropic",
          model: "gpt-4.1",
          endpoint: "https://proxy.invalid/v1",
          access_mode: :host_subscription,
          credential_class: :short_lived_bearer,
          billing_mode: :subscription
        ] do
      assert {:error, %AdapterError{kind: :invalid_input, operation: :buffered_model_profile}} =
               profile_attributes()
               |> Map.put(key, value)
               |> BufferedProfile.new(credential_reference())
    end
  end

  test "missing broker credentials fail before ReqLLM dispatch" do
    FakeReqLLMClient.put_generate_result({:ok, req_llm_response()})
    assert {:ok, request} = Request.new(request_attributes())

    gateway = gateway(secret_result: {:error, AdapterError.new(:unavailable, :secret_fetch)})

    assert {:error, %AdapterError{operation: :secret_fetch}} =
             ModelGateway.generate(gateway, request)

    assert_received {:model_authorize, :before_credential_release, _profile, ^request}
    assert_received {:secret_fetch, _reference}
    refute_received {:model_authorize, :before_dispatch, _profile, _request}
    refute_received {:req_llm_generate_text, _model, _messages, _options}
  end

  test "uses only broker bytes and rebuilds the complete hardened option set" do
    ambient_key = "ambient-key-must-not-be-used"
    previous_env = System.get_env("OPENAI_API_KEY")
    previous_app = Application.get_env(:req_llm, :openai_api_key, :missing)

    on_exit(fn ->
      restore_env("OPENAI_API_KEY", previous_env)
      restore_app_env(:openai_api_key, previous_app)
    end)

    System.put_env("OPENAI_API_KEY", ambient_key)
    Application.put_env(:req_llm, :openai_api_key, ambient_key)
    FakeReqLLMClient.put_generate_result({:ok, req_llm_response()})

    assert {:ok, request} = Request.new(request_attributes())
    assert {:ok, %Response{} = response} = ModelGateway.generate(gateway(), request)

    assert_received {:req_llm_generate_text, "openai:gpt-4.1-mini", "compiled context", options}
    assert Keyword.fetch!(options, :api_key) == "broker-key"
    refute Keyword.fetch!(options, :api_key) == ambient_key
    assert Keyword.fetch!(options, :cache) == nil
    assert Keyword.fetch!(options, :max_retries) == 0
    assert Keyword.fetch!(options, :receive_timeout) == 30_000
    assert Keyword.fetch!(options, :total_timeout) == 60_000
    assert Keyword.fetch!(options, :stream_idle_timeout) == 15_000
    assert Keyword.fetch!(options, :telemetry) == [payloads: :none]
    assert Keyword.fetch!(options, :json_repair) == false
    assert Keyword.fetch!(options, :output_validation) == :strict
    assert Keyword.fetch!(options, :provider_options) == [store: false]
    assert Keyword.fetch!(options, :tools) == []
    assert Keyword.fetch!(options, :tool_choice) == :none
    refute Keyword.has_key?(options, :base_url)
    refute Keyword.has_key?(options, :req_http_options)
    refute Keyword.has_key?(options, :on_finch_request)
    refute Keyword.has_key?(options, :output_repair)

    assert response.provenance.endpoint == "https://api.openai.com/v1"
    assert response.provenance.req_llm_version == "1.20.0"
    assert Application.fetch_env!(:req_llm, :load_dotenv) == false
    assert Application.fetch_env!(:llm_db, :load_dotenv) == false
    assert Application.fetch_env!(:req_llm, :telemetry) == [payloads: :none]
  end

  test "rejects cache, repair, provider, endpoint, hook, fixture, and tool injection before dispatch" do
    FakeReqLLMClient.put_generate_result({:ok, req_llm_response()})

    injections = [
      cache: __MODULE__,
      output: :arbitrary,
      output_repair: fn value -> {:ok, value} end,
      provider_options: [store: true],
      base_url: "https://proxy.invalid/v1",
      req_http_options: [plug: __MODULE__],
      on_finch_request: fn request -> request end,
      fixture: "provider-recording",
      tools: [%{"type" => "web_search"}]
    ]

    for {key, value} <- injections do
      attributes = Map.put(request_attributes(), :options, [{key, value}])
      assert {:ok, request} = Request.new(attributes)

      assert {:error, %AdapterError{kind: :unauthorized, operation: :model_dispatch}} =
               ModelGateway.generate(gateway(), request)

      refute_received {:secret_fetch, _reference}
      refute_received {:req_llm_generate_text, _model, _messages, _options}
    end
  end

  test "wire conformance forces store false and emits no provider-native tools" do
    FakeReqLLMClient.put_generate_result({:ok, req_llm_response()})
    assert {:ok, request} = Request.new(request_attributes())
    assert {:ok, %Response{}} = ModelGateway.generate(gateway(), request)

    assert_received {:req_llm_generate_text, model_spec, messages, options}
    assert {:ok, model} = ReqLLM.model(model_spec)
    assert {:ok, context} = ReqLLM.Context.normalize(messages, options)

    request_options = options |> Map.new() |> Map.put(:req_llm_model, model)

    body =
      ReqLLM.Providers.OpenAI.ResponsesAPI.build_request_body(
        context,
        model.id,
        options,
        %{options: request_options}
      )

    assert body["model"] == "gpt-4.1-mini"
    assert body["store"] == false
    refute Map.has_key?(body, "tools")
    refute Map.has_key?(body, "previous_response_id")
    refute Map.has_key?(body, "prompt_cache_key")
    assert Map.get(model.extra, :category, Map.get(model.extra, "category")) != "deep_research"
  end

  test "rejects response-cache hits and every repair or coercion diagnostic" do
    cached = req_llm_response(provider_meta: %{response_cache_hit: true})
    FakeReqLLMClient.put_generate_result({:ok, cached})
    assert {:ok, request} = Request.new(request_attributes())

    assert {:error, %AdapterError{operation: :req_llm_cache_hit}} =
             ModelGateway.generate(gateway(), request)

    repaired =
      req_llm_response(
        provider_meta: %{
          req_llm_output: %{
            repairs: [%{type: :legacy_type_coercion, status: :applied}]
          }
        }
      )

    FakeReqLLMClient.put_generate_result({:ok, repaired})

    assert {:error, %AdapterError{operation: :req_llm_output_repair}} =
             ModelGateway.generate(gateway(), request)
  end

  test "validates retained raw tool arguments without repair and refuses every tool effect" do
    assert {:ok, request} = Request.new(request_attributes())

    valid_raw = ReqLLM.ToolCall.new("call-1", "write_file", ~s({"path":"README.md"}))
    FakeReqLLMClient.put_generate_result({:ok, tool_response(valid_raw)})

    assert {:error, %AdapterError{operation: :req_llm_tool_calls}} =
             ModelGateway.generate(gateway(), request)

    malformed = ReqLLM.ToolCall.new("call-2", "write_file", ~s({"path":))
    FakeReqLLMClient.put_generate_result({:ok, tool_response(malformed)})

    assert {:error, %AdapterError{operation: :req_llm_tool_arguments}} =
             ModelGateway.generate(gateway(), request)

    builtin = ReqLLM.ToolCall.new_builtin("call-3", "web_search", ~s({"query":"secret"}))
    FakeReqLLMClient.put_generate_result({:ok, tool_response(builtin)})

    assert {:error, %AdapterError{operation: :req_llm_tool_calls}} =
             ModelGateway.generate(gateway(), request)
  end

  test "normalizes observed usage, cost, provenance, and Phase 1 outcome attributes" do
    FakeReqLLMClient.put_generate_result(
      {:ok, req_llm_response(usage: %{input_tokens: 20, output_tokens: 5, total_cost: 0.001_234})}
    )

    assert {:ok, request} = Request.new(request_attributes())
    result = ModelGateway.generate(gateway(), request)

    assert {:ok,
            %Response{
              usage: %{input_tokens: 20, output_tokens: 5, cost_units: 1234},
              provenance: %{
                cost_unit: :micro_usd,
                cost_enforcement: :observed_post_dispatch,
                structured_effects: :disabled_unproven_strict_json
              }
            }} = result

    assert %{
             status: :completed,
             model_call_ref: "response-1",
             usage: %{input_tokens: 20, output_tokens: 5, cost_units: 1234},
             diagnostic: "gateway=buffered;cost_enforcement=observed_post_dispatch"
           } = Outcome.attributes(result, request)
  end

  test "revalidates authority after credential release and never falls back" do
    assert {:ok, request} = Request.new(request_attributes())

    gateway =
      gateway(
        authority_results: %{
          before_dispatch: {:error, AdapterError.new(:unauthorized, :before_dispatch)}
        }
      )

    assert {:error, %AdapterError{operation: :before_dispatch}} =
             ModelGateway.generate(gateway, request)

    assert_received {:secret_fetch, _reference}
    assert_received {:model_authorize, :before_dispatch, _profile, ^request}
    refute_received {:req_llm_generate_text, _model, _messages, _options}

    mismatched = %{request_attributes() | model: "gpt-4.1"}
    assert {:ok, wrong_request} = Request.new(mismatched)

    assert {:error, %AdapterError{operation: :model_dispatch}} =
             ModelGateway.generate(gateway(), wrong_request)

    refute_received {:secret_fetch, _reference}
  end

  defp gateway(options \\ []) do
    assert {:ok, adapter} = ReqLLMAdapter.new(client: FakeReqLLMClient)
    assert {:ok, profile} = profile()

    secret_result = Keyword.get(options, :secret_result, {:ok, "broker-key"})
    authority_results = Keyword.get(options, :authority_results, %{})

    assert {:ok, gateway} =
             ModelGateway.new(ReqLLMAdapter, adapter,
               profile: profile,
               secret_provider: {
                 FakeSecretProvider,
                 %{owner: self(), result: secret_result}
               },
               authority: {
                 FakeModelAuthority,
                 %{owner: self(), results: authority_results}
               }
             )

    gateway
  end

  defp profile do
    BufferedProfile.new(profile_attributes(), credential_reference())
  end

  defp profile_attributes do
    %{
      profile_iri: deterministic!(:model_access_profile, "buffered-profile"),
      credential_reference_iri: deterministic!(:knowledge_assertion, "buffered-credential"),
      provider: "openai",
      model: "gpt-4.1-mini",
      endpoint: "https://api.openai.com/v1",
      access_mode: :host_api,
      credential_class: :static_reusable,
      billing_mode: :metered_api,
      readiness: [:credential_available, :authenticated, :model_available, :policy_allowed]
    }
  end

  defp credential_reference do
    {:ok, reference} =
      CredentialReference.new(%{
        iri: deterministic!(:knowledge_assertion, "buffered-credential"),
        provider: "openai",
        key: "openai-buffered-profile"
      })

    reference
  end

  defp request_attributes do
    %{
      invocation_iri: deterministic!(:model_invocation, "buffered-invocation"),
      profile_iri: deterministic!(:model_access_profile, "buffered-profile"),
      context_manifest_iri: deterministic!(:context_manifest, "buffered-context"),
      provider: "openai",
      model: "gpt-4.1-mini",
      messages: "compiled context",
      options: [temperature: 0.0, max_tokens: 512],
      deadline: DateTime.add(DateTime.utc_now(), 30, :second)
    }
  end

  defp req_llm_response(options \\ []) do
    content = ReqLLM.Message.ContentPart.text("bounded answer")
    message = struct(ReqLLM.Message, role: :assistant, content: [content])

    struct(ReqLLM.Response,
      id: "response-1",
      model: "gpt-4.1-mini",
      context: [],
      message: message,
      finish_reason: :stop,
      usage: Keyword.get(options, :usage, %{input_tokens: 12, output_tokens: 3}),
      provider_meta: Keyword.get(options, :provider_meta, %{})
    )
  end

  defp tool_response(tool_call) do
    message =
      struct(ReqLLM.Message,
        role: :assistant,
        content: [],
        tool_calls: [tool_call]
      )

    struct(ReqLLM.Response,
      id: "response-tools",
      model: "gpt-4.1-mini",
      context: [],
      message: message,
      finish_reason: :tool_calls,
      usage: %{input_tokens: 12, output_tokens: 3}
    )
  end

  defp deterministic!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)

  defp restore_app_env(key, :missing), do: Application.delete_env(:req_llm, key)
  defp restore_app_env(key, value), do: Application.put_env(:req_llm, key, value)
end
