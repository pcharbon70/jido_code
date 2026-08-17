defmodule JidoCode.Factory.Harness.PhaseH02ModelGatewayTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.Response
  alias JidoCode.Factory.Model.Stream
  alias JidoCode.Factory.ModelGateway
  alias JidoCode.Integrations.ReqLLM, as: ReqLLMAdapter
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeModelInteraction
  alias JidoCode.TestSupport.FakeReqLLMClient

  test "pins a released ReqLLM compatible with the locked Req and catalog" do
    assert Application.spec(:req_llm, :vsn) |> to_string() == "1.20.0"
    assert Application.spec(:req, :vsn) |> to_string() == "0.6.3"

    assert {:ok, %LLMDB.Model{id: "gpt-4.1-mini", provider: :openai}} =
             ReqLLM.model("openai:gpt-4.1-mini")
  end

  test "validates bounded model requests and exact provider/model identity" do
    assert {:ok, request} = Request.new(request_attributes())
    assert Request.model_spec(request) == "openai:gpt-4.1-mini"

    assert {:error, %AdapterError{kind: :invalid_input, operation: :model_request}} =
             request_attributes()
             |> Map.put(:provider, "OpenAI/custom")
             |> Request.new()

    assert {:error, %AdapterError{kind: :invalid_input, operation: :model_request}} =
             request_attributes()
             |> Map.put(:messages, String.duplicate("x", 262_145))
             |> Request.new()
  end

  test "routes buffered calls and streams through one selected gateway adapter" do
    assert {:ok, request} = Request.new(request_attributes())
    response = response()
    handle = make_ref()

    adapter = %{
      owner: self(),
      generate_result: {:ok, response},
      stream_result: {:ok, handle}
    }

    assert {:ok, gateway} = ModelGateway.new(FakeModelInteraction, adapter)
    assert {:ok, ^response} = ModelGateway.generate(gateway, request)
    assert_received {:model_generate, ^request}

    assert {:ok, %Stream{invocation_iri: invocation_iri, handle: ^handle}} =
             ModelGateway.stream(gateway, request)

    assert invocation_iri == request.invocation_iri
    assert_received {:model_stream, ^request}
  end

  test "normalizes public ReqLLM response projections without executing tool helpers" do
    req_llm_response = req_llm_response("bounded answer")
    FakeReqLLMClient.put_generate_result({:ok, req_llm_response})

    assert {:ok, adapter} = ReqLLMAdapter.new(client: FakeReqLLMClient)
    assert {:ok, request} = Request.new(request_attributes())
    assert {:ok, gateway} = ModelGateway.new(ReqLLMAdapter, adapter)

    assert {:ok,
            %Response{
              type: :final_answer,
              text: "bounded answer",
              finish_reason: :stop,
              usage: %{input_tokens: 12, output_tokens: 3}
            }} = ModelGateway.generate(gateway, request)

    assert_received {:req_llm_generate_text, "openai:gpt-4.1-mini", "compiled context", options}
    assert Keyword.fetch!(options, :temperature) == 0.0
  end

  test "normalizes provider failures to a redacted adapter error" do
    error = ReqLLM.Error.API.Request.exception(reason: :bad_key, status: 401)
    FakeReqLLMClient.put_generate_result({:error, error})

    assert {:ok, adapter} = ReqLLMAdapter.new(client: FakeReqLLMClient)
    assert {:ok, request} = Request.new(request_attributes())

    assert {:error,
            %AdapterError{
              kind: :unauthorized,
              operation: :req_llm_generate,
              message: "external adapter operation failed"
            }} = ReqLLMAdapter.generate(adapter, request)
  end

  test "keeps direct ReqLLM calls inside the integrations adapter" do
    offenders =
      "lib/**/*.ex"
      |> Path.wildcard()
      |> Enum.reject(&(&1 == "lib/jido_code/integrations/req_llm.ex"))
      |> Enum.filter(fn path ->
        path
        |> File.read!()
        |> String.contains?("ReqLLM.")
      end)

    assert offenders == []
  end

  defp request_attributes do
    %{
      invocation_iri: deterministic!(:model_invocation, "gateway-invocation"),
      profile_iri: deterministic!(:model_access_profile, "gateway-profile"),
      context_manifest_iri: deterministic!(:context_manifest, "gateway-context"),
      provider: "openai",
      model: "gpt-4.1-mini",
      messages: "compiled context",
      options: [temperature: 0.0],
      deadline: DateTime.add(DateTime.utc_now(), 30, :second)
    }
  end

  defp response do
    {:ok, response} =
      Response.new(%{
        type: :final_answer,
        text: "bounded answer",
        thinking: "",
        tool_calls: [],
        finish_reason: :stop,
        usage: %{input_tokens: 12, output_tokens: 3},
        call_metadata: %{response_id: "response-1", model: "gpt-4.1-mini"}
      })

    response
  end

  defp req_llm_response(text) do
    content = ReqLLM.Message.ContentPart.text(text)
    message = struct(ReqLLM.Message, role: :assistant, content: [content])

    struct(ReqLLM.Response,
      id: "response-1",
      model: "gpt-4.1-mini",
      context: [],
      message: message,
      finish_reason: :stop,
      usage: %{input_tokens: 12, output_tokens: 3}
    )
  end

  defp deterministic!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end
