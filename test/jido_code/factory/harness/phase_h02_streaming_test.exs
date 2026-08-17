defmodule JidoCode.Factory.Harness.PhaseH02StreamingTest do
  use ExUnit.Case, async: false

  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Outcome
  alias JidoCode.Factory.Model.Request
  alias JidoCode.Factory.Model.StreamCoordinator
  alias JidoCode.Factory.Model.StreamEvent
  alias JidoCode.Factory.Model.StreamResult
  alias JidoCode.Factory.ModelGateway
  alias JidoCode.Integrations.ReqLLM, as: ReqLLMAdapter
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeModelAuthority
  alias JidoCode.TestSupport.FakeModelInteraction
  alias JidoCode.TestSupport.FakeReqLLMClient
  alias JidoCode.TestSupport.FakeSecretProvider

  test "consumes the ReqLLM events view once, forwards text, closes, and commits one result" do
    chunks = [ReqLLM.StreamChunk.text("hel"), ReqLLM.StreamChunk.text("lo")]

    response =
      req_llm_stream(chunks,
        usage: %{input_tokens: 8, output_tokens: 2, total_cost: 0.000_01},
        finish_reason: :stop
      )

    FakeReqLLMClient.put_stream_result({:ok, response})
    stream = start_req_llm_stream()
    coordinator = start_supervised!({StreamCoordinator, {stream, subscriber: self()}})

    assert %StreamResult{
             status: :completed,
             text: "hello",
             tool_calls: [],
             usage: %{input_tokens: 8, output_tokens: 2, cost_units: 10},
             finish_reason: :stop,
             diagnostic: "stream=completed"
           } = result = StreamCoordinator.await(coordinator)

    assert %{status: :completed, usage: %{cost_units: 10}, diagnostic: "stream=completed"} =
             Outcome.attributes(result, stream.request)

    assert_received {:model_stream_delta, _invocation_iri, "hel"}
    assert_received {:model_stream_delta, _invocation_iri, "lo"}
    assert_received {:req_llm_stream_closed, _response}

    assert_received {:req_llm_stream_text, "openai:gpt-4.1-mini", "compiled context", options}

    assert Keyword.fetch!(options, :max_retries) == 0
    assert Keyword.fetch!(options, :stream_idle_timeout) == 15_000
  end

  test "never publishes or accepts partial or assembled tool calls" do
    chunks = [
      ReqLLM.StreamChunk.tool_call(
        "write_file",
        %{"path" => "README.md"},
        %{id: "call-1", index: 0}
      )
    ]

    FakeReqLLMClient.put_stream_result({:ok, req_llm_stream(chunks, finish_reason: :tool_calls)})

    stream = start_req_llm_stream()
    coordinator = start_supervised!({StreamCoordinator, {stream, subscriber: self()}})

    assert %StreamResult{
             status: :failed,
             text: "",
             tool_calls: [],
             diagnostic: "stream=policy_violation"
           } = StreamCoordinator.await(coordinator)

    refute_received {:model_stream_delta, _invocation_iri, _partial_tool_data}
    assert_received {:req_llm_stream_closed, _response}
  end

  test "committed cancellation closes the stream and wins over a later finish" do
    {:ok, consumer_registry} = Agent.start_link(fn -> nil end)
    events = blocking_events(consumer_registry, true)
    stream = start_fake_stream(events, fn -> release_consumer(consumer_registry) end)

    coordinator =
      start_supervised!({StreamCoordinator, {stream, subscriber: self(), cancel_wait_ms: 50}})

    assert_receive {:blocking_stream_consumer, consumer}
    assert :ok = StreamCoordinator.cancel(coordinator, :cancelled)

    assert %StreamResult{status: :cancelled, diagnostic: "stream=cancelled"} =
             StreamCoordinator.await(coordinator)

    assert_receive {:fake_stream_close_callback, _caller}
    assert_eventually_stopped(consumer)
  end

  test "lease loss closes first, then forcibly terminates an unresponsive consumer" do
    {:ok, consumer_registry} = Agent.start_link(fn -> nil end)
    events = blocking_events(consumer_registry, false)
    stream = start_fake_stream(events, fn -> send(self(), :close_without_release) end)

    coordinator =
      start_supervised!({StreamCoordinator, {stream, subscriber: self(), cancel_wait_ms: 20}})

    assert_receive {:blocking_stream_consumer, consumer}
    assert :ok = StreamCoordinator.cancel(coordinator, :lease_lost)

    assert %StreamResult{status: :failed, diagnostic: "stream=lease_lost"} =
             StreamCoordinator.await(coordinator)

    assert_eventually_stopped(consumer)
    assert_received {:model_stream_close, _handle}
  end

  test "finite deadline times out, closes, and terminates a stalled consumer" do
    {:ok, consumer_registry} = Agent.start_link(fn -> nil end)
    events = blocking_events(consumer_registry, false)
    stream = start_fake_stream(events, fn -> :ok end, deadline_ms: 40)

    coordinator =
      start_supervised!({StreamCoordinator, {stream, subscriber: self(), cancel_wait_ms: 20}})

    assert_receive {:blocking_stream_consumer, consumer}

    assert %StreamResult{status: :timed_out, diagnostic: "stream=timed_out"} =
             StreamCoordinator.await(coordinator, 1_000)

    assert_eventually_stopped(consumer)
    assert_received {:model_stream_close, _handle}
  end

  test "first terminal result wins and duplicate terminal events fail closed" do
    events = [
      event!(:start, %{}),
      event!(:text_delta, "answer"),
      event!(:finish, %{finish_reason: :stop}),
      event!(:cancelled, %{finish_reason: :cancelled})
    ]

    stream = start_fake_stream(events, fn -> :ok end)
    coordinator = start_supervised!({StreamCoordinator, {stream, subscriber: self()}})

    assert %StreamResult{
             status: :failed,
             text: "",
             diagnostic: "stream=invalid_terminal_count"
           } = StreamCoordinator.await(coordinator)

    assert_received {:model_stream_delta, _invocation_iri, "answer"}
  end

  defp start_req_llm_stream do
    assert {:ok, adapter} = ReqLLMAdapter.new(client: FakeReqLLMClient)
    assert {:ok, gateway} = gateway(ReqLLMAdapter, adapter)
    assert {:ok, request} = Request.new(request_attributes())
    assert {:ok, stream} = ModelGateway.stream(gateway, request)
    stream
  end

  defp start_fake_stream(events, close, options \\ []) do
    owner = self()

    handle = %{
      events: events,
      close: fn ->
        send(owner, {:fake_stream_close_callback, self()})
        close.()
      end
    }

    adapter = %{
      owner: self(),
      generate_result: {:error, :not_used},
      stream_result: {:ok, handle}
    }

    assert {:ok, gateway} = gateway(FakeModelInteraction, adapter)

    attributes =
      Map.put(
        request_attributes(),
        :deadline,
        DateTime.add(DateTime.utc_now(), Keyword.get(options, :deadline_ms, 30_000), :millisecond)
      )

    assert {:ok, request} = Request.new(attributes)
    assert {:ok, stream} = ModelGateway.stream(gateway, request)
    stream
  end

  defp blocking_events(registry, _release_on_close?) do
    owner = self()

    Stream.resource(
      fn -> :start end,
      fn
        :start ->
          consumer = self()
          Agent.update(registry, fn _current -> consumer end)
          send(owner, {:blocking_stream_consumer, consumer})
          {[event!(:start, %{}), event!(:text_delta, "partial")], :blocked}

        :blocked ->
          receive do
            :release_stream ->
              {[event!(:finish, %{finish_reason: :stop})], :done}
          end

        :done ->
          {:halt, :done}
      end,
      fn _state -> :ok end
    )
  end

  defp release_consumer(registry) do
    case Agent.get(registry, & &1) do
      pid when is_pid(pid) -> send(pid, :release_stream)
      _missing -> :ok
    end
  end

  defp req_llm_stream(chunks, metadata) do
    owner = self()
    assert {:ok, model} = ReqLLM.model("openai:gpt-4.1-mini")
    assert {:ok, context} = ReqLLM.Context.normalize("compiled context")

    assert {:ok, metadata_handle} =
             ReqLLM.StreamResponse.MetadataHandle.start_link(fn -> Map.new(metadata) end)

    struct(ReqLLM.StreamResponse,
      stream: chunks,
      metadata_handle: metadata_handle,
      cancel: fn ->
        send(owner, {:req_llm_stream_closed, self()})
        :ok
      end,
      model: model,
      context: context
    )
  end

  defp gateway(adapter_module, adapter) do
    assert {:ok, profile} = profile()

    ModelGateway.new(adapter_module, adapter,
      profile: profile,
      secret_provider: {FakeSecretProvider, %{owner: self(), result: {:ok, "broker-key"}}},
      authority: {FakeModelAuthority, %{owner: self(), results: %{}}}
    )
  end

  defp profile do
    credential_iri = deterministic!(:knowledge_assertion, "stream-credential")

    {:ok, reference} =
      CredentialReference.new(%{
        iri: credential_iri,
        provider: "openai",
        key: "openai-stream-profile"
      })

    BufferedProfile.new(
      %{
        profile_iri: deterministic!(:model_access_profile, "stream-profile"),
        credential_reference_iri: credential_iri,
        provider: "openai",
        model: "gpt-4.1-mini",
        endpoint: "https://api.openai.com/v1",
        access_mode: :host_api,
        credential_class: :static_reusable,
        billing_mode: :metered_api,
        readiness: [:credential_available, :authenticated, :model_available, :policy_allowed]
      },
      reference
    )
  end

  defp request_attributes do
    %{
      invocation_iri: deterministic!(:model_invocation, "stream-invocation"),
      profile_iri: deterministic!(:model_access_profile, "stream-profile"),
      context_manifest_iri: deterministic!(:context_manifest, "stream-context"),
      provider: "openai",
      model: "gpt-4.1-mini",
      messages: "compiled context",
      options: [temperature: 0.0, max_tokens: 512],
      deadline: DateTime.add(DateTime.utc_now(), 30, :second)
    }
  end

  defp event!(type, data) do
    {:ok, event} = StreamEvent.new(type, data)
    event
  end

  defp deterministic!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end

  defp assert_eventually_stopped(pid) do
    monitor = Process.monitor(pid)

    if Process.alive?(pid) do
      assert_receive {:DOWN, ^monitor, :process, ^pid, _reason}, 500
    else
      Process.demonitor(monitor, [:flush])
    end
  end
end
