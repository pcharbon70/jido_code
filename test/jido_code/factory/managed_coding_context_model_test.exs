defmodule JidoCode.Factory.ManagedCodingContextModelTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.AdapterError
  alias JidoCode.Factory.CredentialReference
  alias JidoCode.Factory.ManagedCoding.Context
  alias JidoCode.Factory.ManagedCoding.ContextDirectiveExecutor
  alias JidoCode.Factory.ManagedCoding.ModelDecision
  alias JidoCode.Factory.ManagedCoding.ModelDirectiveExecutor
  alias JidoCode.Factory.Model.BufferedProfile
  alias JidoCode.Factory.Model.Response
  alias JidoCode.Factory.ModelGateway
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.Runtime.ManagedCoding.Directive.Context, as: ContextDirective
  alias JidoCode.Runtime.ManagedCoding.Directive.Model, as: ModelDirective
  alias JidoCode.TestSupport.FakeManagedCodingContextSink
  alias JidoCode.TestSupport.FakeManagedCodingModelLedger
  alias JidoCode.TestSupport.FakeModelAuthority
  alias JidoCode.TestSupport.FakeModelInteraction
  alias JidoCode.TestSupport.FakeSecretProvider
  alias JidoCode.TestSupport.Phase04Fixture

  @policy_graph "https://jido.run/graph/factory/policy"

  test "pins exact context revisions, preserves no-memory equivalence, and detects every material change" do
    attributes = context_attributes()

    assert {:ok, disabled} =
             Context.compile(Map.put(attributes, :memory, :disabled), query: &query/6)

    assert {:ok, absent} = Context.compile(Map.put(attributes, :memory, nil), query: &query/6)
    assert disabled.compiled == absent.compiled
    assert disabled.digest == absent.digest
    assert disabled.pins == attributes.pins

    material = [
      :source_revision,
      :workspace_revision,
      :policy_revision,
      :lease_iri,
      :capability_iri,
      :prompt_revision,
      :tool_revision,
      :memory_partition_digest,
      :erasure_generation
    ]

    Enum.each(material, fn key ->
      changed = put_in(attributes, [:pins, key], changed_pin(key, attributes.pins[key]))
      assert Context.recompile?(disabled, changed.pins), "expected #{key} to invalidate context"
    end)

    unauthorized_memory = %{
      authorized?: false,
      temporally_eligible?: true,
      source_complete?: true,
      expires_at: DateTime.add(DateTime.utc_now(), 60, :second),
      partition_digest: attributes.pins.memory_partition_digest,
      erasure_generation: attributes.pins.erasure_generation,
      packet: %{}
    }

    assert {:error, %AdapterError{operation: :managed_coding_memory_context}} =
             Context.compile(Map.put(attributes, :memory, unauthorized_memory), query: &query/6)
  end

  test "context directive persists the full manifest and returns only bounded references" do
    attempt = Phase04Fixture.local!(:attempt, 610)
    attributes = context_attributes(attempt)
    invocation = resource(:context_manifest, "managed-context-directive")

    assert {:ok, directive} =
             ContextDirective.new(%{
               attempt_iri: attempt,
               fencing_token: 3,
               sequence: 1,
               invocation_iri: invocation,
               deadline: DateTime.add(DateTime.utc_now(), 30, :second),
               payload: %{context: attributes}
             })

    state = %{
      compiler_options: [query: &query/6],
      context_sink: {FakeManagedCodingContextSink, %{owner: self()}}
    }

    assert {:ok, result} = ContextDirectiveExecutor.execute(state, directive.envelope, [])
    assert result.outcome == :completed
    assert byte_size(result.context_digest) == 64
    assert is_binary(result.model_invocation_iri)
    refute Map.has_key?(result, :serialized)
    assert_receive {:managed_coding_context, context}
    assert context.compiled.manifest.iri == result.context_manifest_iri
  end

  test "strict model union accepts four exact variants and rejects repair or provider tool calls" do
    variants = [
      {%{
         "kind" => "tool_proposal",
         "tool" => %{
           "name" => "workspace.read",
           "version" => "1.0.0",
           "arguments" => %{"path" => "mix.exs"},
           "classification" => "internal",
           "input_refs" => [resource(:context_manifest, "model-input")]
         }
       }, :tool_proposal},
      {%{"kind" => "completion_proposal", "summary" => "candidate", "claims" => ["edited"]},
       :completion_proposal},
      {%{"kind" => "clarification", "question" => "Which file?", "reason" => "ambiguous_intent"},
       :clarification},
      {%{"kind" => "abstention", "reason" => "insufficient evidence"}, :abstention}
    ]

    Enum.each(variants, fn {body, kind} ->
      assert {:ok, %{kind: ^kind}} =
               body |> Jason.encode!() |> response() |> ModelDecision.parse()
    end)

    invalid = [
      %{"kind" => "tool_proposal", "tool" => %{"name" => "workspace.read"}},
      %{"kind" => "complete", "summary" => "legacy"},
      %{"kind" => "abstention", "reason" => "no", "extra" => true}
    ]

    Enum.each(invalid, fn body ->
      assert {:error, %AdapterError{kind: :corrupt}} =
               body |> Jason.encode!() |> response() |> ModelDecision.parse()
    end)

    with_calls = %{
      response(Jason.encode!(elem(hd(variants), 0)))
      | type: :tool_calls,
        tool_calls: [%{}]
    }

    assert {:error, %AdapterError{kind: :corrupt}} = ModelDecision.parse(with_calls)
  end

  test "model directive commits start before its sole dispatch and outcome before continuation" do
    attempt = Phase04Fixture.local!(:attempt, 620)
    invocation = resource(:model_invocation, "managed-model-directive")
    profile_iri = resource(:model_access_profile, "managed-model-profile")
    context_iri = resource(:context_manifest, "managed-model-context")

    body =
      Jason.encode!(%{
        "kind" => "completion_proposal",
        "summary" => "ready",
        "claims" => ["changed"]
      })

    adapter = %{
      owner: self(),
      generate_result: {:ok, response(body)},
      stream_result: {:error, :unused}
    }

    {:ok, gateway} = gateway(adapter, profile_iri)

    assert {:ok, directive} =
             ModelDirective.new(%{
               attempt_iri: attempt,
               fencing_token: 7,
               sequence: 2,
               invocation_iri: invocation,
               deadline: DateTime.add(DateTime.utc_now(), 30, :second),
               payload: %{request_revision: String.duplicate("a", 64)}
             })

    request_provider = fn _envelope ->
      {:ok,
       %{
         invocation_iri: invocation,
         profile_iri: profile_iri,
         context_manifest_iri: context_iri,
         provider: "openai",
         model: "gpt-4.1-mini",
         messages: "compiled context",
         options: [temperature: 0.0],
         deadline: DateTime.add(DateTime.utc_now(), 20, :second)
       }}
    end

    state = %{
      gateway: gateway,
      request_provider: request_provider,
      ledger: {FakeManagedCodingModelLedger, %{owner: self()}}
    }

    assert {:ok, result} = ModelDirectiveExecutor.execute(state, directive.envelope, [])
    assert result.kind == :completion_proposal
    assert result.decision.summary == "ready"
    assert is_binary(result.next_invocation_iri)

    assert_receive {:model_ledger_start, correlation, request}
    assert correlation.invocation_iri == invocation
    assert_receive {:model_authorize, :before_credential_release, _, ^request}
    assert_receive {:secret_fetch, _}
    assert_receive {:model_authorize, :before_dispatch, _, ^request}
    assert_receive {:model_generate, _}

    assert_receive {:model_ledger_outcome, _,
                    %{status: :completed, decision_status: :completion_proposal}}

    refute_receive {:model_generate, _}
  end

  defp context_attributes(attempt \\ Phase04Fixture.local!(:attempt, 600)) do
    snapshot = Phase04Fixture.local!(:activity, 601)

    %{
      compiler: %{
        attempt_iri: attempt,
        manifest_index: 1,
        repository_iri: Phase04Fixture.resource!("managed-context-repository"),
        snapshot_iri: snapshot,
        analysis_profile: "elixir-ast/1.0.0",
        expected_dataset_revision: 44,
        source_graph_revisions: %{@policy_graph => 7},
        authority: :fixture_authority,
        scope_iri: Phase04Fixture.scope!(:factory, "managed-context"),
        sections: [section(snapshot)],
        budget: %{max_items: 20, max_bytes: 65_536, max_tokens: 16_384, max_item_bytes: 4_096}
      },
      pins: %{
        task_iri: Phase04Fixture.local!(:activity, 602),
        snapshot_iri: snapshot,
        lease_iri: resource(:execution_lease, "managed-context-lease"),
        capability_iri: resource(:capability_declaration, "managed-context-capability"),
        source_revision: digest("source"),
        workspace_revision: digest("workspace"),
        policy_revision: digest("policy"),
        prompt_revision: digest("prompt"),
        tool_revision: digest("tool"),
        profile_revision: digest("profile"),
        authority_revision: digest("authority"),
        graph_revisions: %{@policy_graph => 7},
        erasure_generation: 2,
        memory_partition_digest: digest("memory")
      },
      memory: :disabled
    }
  end

  defp section(snapshot) do
    %{
      kind: :task,
      query_name: :resource_description,
      query_version: "1.7.0",
      parameters: %{resource: Phase04Fixture.local!(:activity, 605)},
      item_iri: Phase04Fixture.local!(:activity, 606),
      classification: :internal,
      required?: true,
      graph_revisions: %{@policy_graph => 7},
      repository_iri: Phase04Fixture.resource!("managed-context-repository"),
      snapshot_iri: snapshot,
      analysis_profile: "elixir-ast/1.0.0"
    }
  end

  defp query(:resource_description, "1.7.0", parameters, _authority, _scope, _options) do
    {:ok,
     %{
       query_name: :resource_description,
       query_version: "1.7.0",
       dataset_revision: 44,
       graph_revisions: %{@policy_graph => 7},
       completeness: %{complete?: true},
       freshness: :current,
       truncated?: false,
       data: %{resource: parameters.resource}
     }}
  end

  defp changed_pin(:lease_iri, _value), do: resource(:execution_lease, "changed-lease")

  defp changed_pin(:capability_iri, _value),
    do: resource(:capability_declaration, "changed-capability")

  defp changed_pin(:erasure_generation, value), do: value + 1
  defp changed_pin(_key, value), do: String.reverse(value)

  defp response(text) do
    {:ok, response} =
      Response.new(%{
        type: :final_answer,
        text: text,
        thinking: "",
        tool_calls: [],
        finish_reason: :stop,
        usage: %{input_tokens: 12, output_tokens: 3},
        call_metadata: %{response_id: "managed-response"},
        provenance: %{profile: "fixture"}
      })

    response
  end

  defp gateway(adapter, profile_iri) do
    credential_iri = resource(:knowledge_assertion, "managed-model-credential")

    {:ok, reference} =
      CredentialReference.new(%{iri: credential_iri, provider: "openai", key: "fixture-key"})

    {:ok, profile} =
      BufferedProfile.new(
        %{
          profile_iri: profile_iri,
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

    ModelGateway.new(FakeModelInteraction, adapter,
      profile: profile,
      secret_provider: {FakeSecretProvider, %{owner: self(), result: {:ok, "broker-key"}}},
      authority: {FakeModelAuthority, %{owner: self(), results: %{}}}
    )
  end

  defp digest(seed), do: :crypto.hash(:sha256, seed) |> Base.encode16(case: :lower)

  defp resource(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, seed)
    iri
  end
end
