defmodule JidoCode.Factory.Harness.PhaseH08MCPTest do
  use ExUnit.Case, async: true

  alias JidoCode.Factory.Execution.Request, as: ExecutionRequest
  alias JidoCode.Factory.Extensions.MCP.Call
  alias JidoCode.Factory.Extensions.MCP.Gateway
  alias JidoCode.Factory.Extensions.MCP.Observation
  alias JidoCode.Factory.Extensions.MCP.Specification
  alias JidoCode.Factory.Tool.Capability
  alias JidoCode.Factory.Tool.EffectJournal
  alias JidoCode.Factory.Tool.Proposal
  alias JidoCode.Factory.Tool.ReferenceMonitor
  alias JidoCode.Knowledge.ResourceIdentity
  alias JidoCode.TestSupport.FakeMCPTransport
  alias JidoCode.TestSupport.FakeToolLedger

  @digest "sha256:" <> String.duplicate("a", 64)
  @descriptor "sha256:" <> String.duplicate("d", 64)

  test "accepted specifications pin identities, descriptors, namespaces, and closed schemas" do
    assert {:ok, specification} = Specification.new(specification_attributes())
    assert specification.status == :accepted
    assert specification.server_identity == "reviewed-server"
    assert Enum.map(specification.tools, & &1.namespaced_name) == ["reviewed-server/search"]
    assert Specification.valid?(specification)
    assert Specification.contract_version() == "1.0.0"

    open_schema =
      update_in(
        specification_attributes(),
        [:tools, Access.at(0), :input_schema, :additional_properties],
        fn _value -> true end
      )

    assert {:error, %{operation: :mcp_connection_policy}} =
             specification_attributes()
             |> put_in([:oauth, :token_passthrough], true)
             |> Specification.new()

    assert {:error, %{operation: :mcp_tool_specification}} = Specification.new(open_schema)

    assert {:error, %{operation: :mcp_specification}} =
             specification_attributes()
             |> Map.put(:unreviewed_override, true)
             |> Specification.new()

    assert {:error, %{operation: :mcp_specification}} =
             specification_attributes()
             |> Map.put(:adapter_digest, @digest)
             |> Specification.new()
  end

  test "runtime discovery and OAuth reject rebinding, token passthrough, and audience drift" do
    specification = specification!()
    attributes = call_attributes(specification)
    assert {:ok, call} = Call.new(specification, attributes)
    assert Call.valid?(call, specification)
    assert call.authorization_command =~ ~r/^mcp_[a-f0-9]{60}$/

    private_address = put_in(attributes, [:connection, :resolved_addresses], ["127.0.0.1"])

    assert {:error, %{operation: :mcp_discovery_address}} =
             Call.new(specification, private_address)

    wrong_audience = put_in(attributes, [:connection, :oauth, :audience], "other-service")
    assert {:error, %{operation: :mcp_runtime_oauth}} = Call.new(specification, wrong_audience)

    token_passthrough = put_in(attributes, [:connection, :oauth, :token_passthrough], true)
    assert {:error, %{operation: :mcp_runtime_oauth}} = Call.new(specification, token_passthrough)

    injected_token =
      update_in(attributes, [:connection, :oauth], &Map.put(&1, :access_token, "secret"))

    assert {:error, %{operation: :mcp_runtime_oauth}} = Call.new(specification, injected_token)

    redirect_rebinding =
      put_in(attributes, [:connection, :redirect_chain], ["https://attacker.example/tool"])

    assert {:error, %{operation: :mcp_runtime_connection}} =
             Call.new(specification, redirect_rebinding)
  end

  test "MCP calls run through Phase 3 approval, budgets, fencing, and the effect journal" do
    fixture = fixture()

    assert {:ok, authorization} =
             ReferenceMonitor.authorize(
               fixture.proposal,
               fixture.capability,
               fixture.current
             )

    assert {:ok, _refreshed} = ReferenceMonitor.revalidate(authorization, fixture.current)

    assert {:ok, %{execution_receipt: receipt, observation: %Observation{} = observation}} =
             Gateway.execute(
               fixture.specification,
               fixture.proposal,
               fixture.capability,
               fixture.call_attributes,
               fixture.current,
               fixture.options
             )

    assert receipt.effect_dispatched
    assert receipt.status == :completed
    assert observation.external_reference_iri == resource!(:provider_object, "remote-handle")
    assert observation.verification == :required
    assert observation.decision == :pending
    refute observation.accepted
    refute Observation.accepting_output?(observation)

    assert_received {:tool_ledger_start, authorization, request}
    assert authorization.tool_name == "run_governed_command"
    assert request.arguments == %{command: fixture.call.authorization_command}
    assert_received {:mcp_transport_identity, _identity}
    assert_received {:mcp_transport_invoke, transported_call, []}
    refute Map.has_key?(transported_call.connection.oauth, :access_token)
    assert_received {:tool_ledger_outcome, _start, _result}
  end

  test "descriptor drift and call-digest drift fail before transport dispatch" do
    fixture = fixture()

    changed_descriptor =
      Map.put(fixture.call_attributes, :observed_descriptor_digest, @digest)

    assert {:error, %{operation: :mcp_call}} =
             Gateway.execute(
               fixture.specification,
               fixture.proposal,
               fixture.capability,
               changed_descriptor,
               fixture.current,
               fixture.options
             )

    refute_received {:tool_ledger_start, _authorization, _request}
    refute_received {:mcp_transport_invoke, _call, _options}

    mismatched_proposal = proposal!(fixture.call, "mcp_" <> String.duplicate("f", 60))

    assert {:error, %{operation: :mcp_phase3_binding}} =
             Gateway.execute(
               fixture.specification,
               mismatched_proposal,
               fixture.capability,
               fixture.call_attributes,
               fixture.current,
               fixture.options
             )

    refute_received {:mcp_transport_invoke, _call, _options}
  end

  test "the Phase 3 monitor reauthorizes immediately before every remote call" do
    fixture = fixture()

    revoked = fn ->
      %{fixture.current | fencing_token: fixture.capability.fencing_token + 1}
    end

    options = Keyword.put(fixture.options, :current_provider, revoked)

    assert {:ok, %{execution_receipt: receipt, observation: nil}} =
             Gateway.execute(
               fixture.specification,
               fixture.proposal,
               fixture.capability,
               fixture.call_attributes,
               fixture.current,
               options
             )

    assert receipt.status == :rejected
    refute receipt.effect_dispatched
    refute_received {:mcp_transport_identity, _identity}
    refute_received {:mcp_transport_invoke, _call, _options}
  end

  test "stdio servers require a separately attested no-network sandbox" do
    specification = stdio_specification!()

    attributes = %{
      specification_digest: specification.digest,
      namespaced_tool: "reviewed-local/search",
      observed_descriptor_digest: @descriptor,
      arguments_ref: resource!(:generated_artifact, "stdio-arguments"),
      arguments: %{query: "fenced execution", limit: 5},
      arguments_digest: Specification.digest(%{query: "fenced execution", limit: 5}),
      connection: %{
        sandbox_instance_iri: resource!(:sandbox_instance, "stdio"),
        profile_digest: @digest,
        network: :deny,
        separate_instance: true,
        credential_mode: :brokered_reference
      }
    }

    assert {:ok, call} = Call.new(specification, attributes)
    assert is_nil(call.credential_reference_iri)

    shared = put_in(attributes, [:connection, :separate_instance], false)
    assert {:error, %{operation: :mcp_runtime_sandbox}} = Call.new(specification, shared)

    networked = put_in(attributes, [:connection, :network], {:allow, "internet"})
    assert {:error, %{operation: :mcp_runtime_sandbox}} = Call.new(specification, networked)
  end

  defp fixture do
    specification = specification!()
    call_attributes = call_attributes(specification)
    {:ok, call} = Call.new(specification, call_attributes)
    proposal = proposal!(call)
    capability = capability!(call)
    current = current(capability, proposal)
    execution = execution_request!(capability)
    {:ok, journal} = EffectJournal.start_link()

    result =
      {:ok,
       %{
         status: :completed,
         external_reference_iri: resource!(:provider_object, "remote-handle"),
         result_digest: @digest,
         output_bytes: 128,
         redaction: :applied
       }}

    transport = %{
      owner: self(),
      identity: %{
        identity: specification.adapter_identity,
        digest: specification.adapter_digest
      },
      result: result
    }

    options = [
      execution_request: execution,
      sequence: 1,
      ledger: {FakeToolLedger, %{owner: self()}},
      effect_sink: {EffectJournal, journal},
      current_provider: fn -> current end,
      transport: {FakeMCPTransport, transport},
      observed_at: ~U[2026-08-18 12:00:00Z]
    ]

    %{
      specification: specification,
      call_attributes: call_attributes,
      call: call,
      proposal: proposal,
      capability: capability,
      current: current,
      options: options
    }
  end

  defp specification! do
    {:ok, specification} = Specification.new(specification_attributes())
    specification
  end

  defp specification_attributes do
    input_schema = %{
      additional_properties: false,
      required: [:query],
      properties: %{query: {:string, 256}, limit: {:integer, 1, 10}}
    }

    output_schema = %{
      additional_properties: false,
      required: [:external_reference],
      properties: %{external_reference: :resource_iri, result_digest: :digest}
    }

    adapter_identity = "JidoCode.TestSupport.FakeMCPTransport/1"

    %{
      revision: "reviewed-server-1",
      status: :accepted,
      specification_iri: resource!(:knowledge_assertion, "mcp-specification"),
      evidence_iri: resource!(:evidence_bundle, "mcp-evidence"),
      protocol_version: "2025-06-18",
      server_package: "example-mcp-server@1.2.3",
      server_package_digest: @digest,
      server_identity: "reviewed-server",
      transport: :https,
      adapter_identity: adapter_identity,
      adapter_digest: Specification.digest(adapter_identity),
      descriptor_digest: "sha256:" <> String.duplicate("c", 64),
      discovery: %{
        origin: "https://mcp.example.test",
        discovery_url: "https://mcp.example.test/.well-known/mcp",
        redirect_origins: ["https://mcp.example.test"],
        max_redirects: 2,
        reject_private_addresses: true,
        pin_connection_address: true
      },
      oauth: %{
        issuer: "https://auth.example.test",
        audience: "reviewed-mcp-service",
        scopes: ["mcp:invoke"],
        redirect_uris: ["https://factory.example.test/oauth/callback"],
        pkce_method: :s256,
        token_passthrough: false
      },
      sandbox: :not_applicable,
      tools: [
        %{
          name: "search",
          namespaced_name: "reviewed-server/search",
          descriptor_digest: @descriptor,
          input_schema: input_schema,
          input_schema_digest: Specification.digest(input_schema),
          output_schema: output_schema,
          output_schema_digest: Specification.digest(output_schema),
          max_output_bytes: 8_192,
          approval_required: true,
          phase3_tool: "run_governed_command"
        }
      ]
    }
  end

  defp stdio_specification! do
    attributes = specification_attributes()

    tool =
      attributes.tools
      |> hd()
      |> Map.put(:namespaced_name, "reviewed-local/search")

    attributes = %{
      attributes
      | revision: "reviewed-local-1",
        server_identity: "reviewed-local",
        transport: :stdio,
        discovery: :not_applicable,
        oauth: :not_applicable,
        sandbox: %{
          profile_digest: @digest,
          network: :deny,
          separate_instance: true,
          credential_mode: :brokered_reference
        },
        tools: [tool]
    }

    {:ok, specification} = Specification.new(attributes)
    specification
  end

  defp call_attributes(specification) do
    arguments = %{query: "fenced execution", limit: 5}

    %{
      specification_digest: specification.digest,
      namespaced_tool: "reviewed-server/search",
      observed_descriptor_digest: @descriptor,
      arguments_ref: resource!(:generated_artifact, "mcp-arguments"),
      arguments: arguments,
      arguments_digest: Specification.digest(arguments),
      connection: %{
        url: "https://mcp.example.test/tools/search",
        resolved_addresses: ["93.184.216.34"],
        connection_address: "93.184.216.34",
        redirect_chain: [
          "https://mcp.example.test/.well-known/mcp",
          "https://mcp.example.test/tools/search"
        ],
        oauth: %{
          issuer: "https://auth.example.test",
          audience: "reviewed-mcp-service",
          scopes: ["mcp:invoke"],
          redirect_uri: "https://factory.example.test/oauth/callback",
          pkce_method: :s256,
          token_passthrough: false,
          credential_reference_iri: resource!(:authorization_grant, "mcp-oauth")
        }
      }
    }
  end

  defp proposal!(call, command \\ nil) do
    command = command || call.authorization_command

    {:ok, proposal} =
      Proposal.from_directive(resource!(:tool_invocation, "mcp-call"), %{
        tool_name: "run_governed_command",
        tool_version: "1.0.0",
        classification: :internal,
        input_refs: [call.arguments_ref],
        arguments: %{command: command}
      })

    proposal
  end

  defp capability!(call) do
    now = DateTime.utc_now()

    {:ok, capability} =
      Capability.new(%{
        attempt_iri: resource!(:execution_attempt, "mcp-attempt"),
        lease_iri: resource!(:execution_lease, "mcp-lease"),
        task_iri: resource!(:task_proposal, "mcp-task"),
        repository_iri: resource!(:repository_snapshot, "mcp-repository"),
        actor_iri: resource!(:knowledge_assertion, "mcp-actor"),
        agent_iri: resource!(:knowledge_assertion, "mcp-agent"),
        profile_iri: resource!(:harness_profile, "mcp-profile"),
        model: "openai:test",
        tool_catalog_version: "1.0.0",
        snapshot_iri: resource!(:repository_snapshot, "mcp-snapshot"),
        source_graph_revisions: %{resource!(:graph_revision_reference, "mcp-policy") => 1},
        permitted_tools: ["run_governed_command"],
        path_prefixes: [],
        ref_iris: [call.arguments_ref],
        graph_scope_iris: [resource!(:graph_revision_reference, "mcp-policy")],
        network_destinations: ["https://mcp.example.test"],
        registered_commands: [call.authorization_command],
        data_classes: [:internal],
        resource_ceilings: %{output_bytes: 131_072, timeout_ms: 300_000},
        credential_reference_iris: [call.credential_reference_iri],
        expires_at: DateTime.add(now, 300, :second),
        fencing_token: 81,
        idempotency_namespace: @digest,
        policy_revision: 1,
        revocation_generation: 1,
        authority_classes: [:tool_execution]
      })

    capability
  end

  defp current(capability, proposal) do
    %{
      now: DateTime.utc_now(),
      invocation_iri: proposal.invocation_iri,
      attempt_iri: capability.attempt_iri,
      lease_iri: capability.lease_iri,
      lease_state: :active,
      policy_revision: capability.policy_revision,
      source_graph_revisions: capability.source_graph_revisions,
      snapshot_iri: capability.snapshot_iri,
      fencing_token: capability.fencing_token,
      revocation_generation: capability.revocation_generation,
      approved_tools: ["run_governed_command"],
      approval_refs: []
    }
  end

  defp execution_request!(capability) do
    {:ok, execution} =
      ExecutionRequest.new(%{
        attempt_iri: capability.attempt_iri,
        lease_iri: capability.lease_iri,
        task_iri: capability.task_iri,
        goal_iri: resource!(:goal_proposal, "mcp-goal"),
        plan_iri: resource!(:plan_proposal, "mcp-plan"),
        repository_iri: capability.repository_iri,
        snapshot_iri: capability.snapshot_iri,
        actor_iri: capability.actor_iri,
        agent_iri: capability.agent_iri,
        capability_iri: resource!(:capability_declaration, "mcp-capability"),
        fencing_token: capability.fencing_token,
        context_digest: String.duplicate("b", 64),
        runtime_version: "mcp-test/1",
        constraints: %{}
      })

    execution
  end

  defp resource!(kind, seed) do
    {:ok, iri} = ResourceIdentity.deterministic(kind, "phase-h08-mcp-#{seed}")
    iri
  end
end
